# Design — `tdd-pipeline`: plugin genérico de pipeline de desenvolvimento

**Data:** 2026-08-03
**Status:** aprovado, pronto para plano de implementação

## Problema

Existe um pipeline de desenvolvimento maduro, guiado por agents, que funciona de
ponta a ponta: da criação da task ao PR aberto, com TDD obrigatório, revisão de
spec antes da implementação e revisão de código depois. Ele vive dentro de um
único projeto e está cravado nele: stack, comandos de teste e lint, caminhos
absolutos, tracker de issues, prefixo de ID.

O objetivo é extrair a mecânica desse pipeline para um plugin reutilizável,
instalável em qualquer projeto, sem nenhum vestígio do projeto de origem.

## Decisões

| Decisão | Escolha |
|---|---|
| Distribuição | Plugin Claude Code, em repositório-marketplace `dfrnks/claude-plugins` |
| Configuração do projeto | `.claude/pipeline.yaml` (determinístico) + arquivo de convenções do projeto (prosa) |
| Tracker de issues | Plugável: `none` (default) \| `linear` \| `github` |
| Regras de stack | Nunca no plugin; sempre no arquivo de convenções do projeto |
| Escopo v1 | Pipeline completo + `/init`. Fora: `/adr`, `/fix-bug`, `/review-pr` |
| Projeto de origem | Permanece intacto; nenhuma migração na v1 |
| Trailer de commit | Vazio por default |

### Restrição transversal

Nenhum arquivo do plugin — prompt, README, exemplo, frontmatter, mensagem de
erro — pode conter nome de projeto real, caminho absoluto, nome de pessoa ou
identificador de organização. Exemplos usam `my-app` e IDs `TASK-1`. Um `grep`
final valida isto antes de qualquer push.

## Arquitetura

### Layout do repositório

```
dfrnks/claude-plugins/
├── .claude-plugin/marketplace.json
├── docs/specs/
└── plugins/tdd-pipeline/
    ├── .claude-plugin/plugin.json
    ├── agents/
    │   ├── task-isolate-start.md    orquestrador (roda dentro do worktree)
    │   ├── task-test.md             fase red
    │   ├── task-execute.md          fase green
    │   ├── task-code-review.md      adjudicação impl × spec
    │   └── task-end.md              lint, commit, push, PR, status
    ├── commands/
    │   ├── init.md                  bootstrap do projeto consumidor
    │   ├── task-start.md            resolve/cria item, cria worktree, delega planejamento
    │   ├── plan.md                  exploração + design colaborativo da spec
    │   ├── task-review.md           revisão da spec antes da implementação
    │   ├── review-plan.md           crítica de plano, independente de tracker
    │   ├── task-isolate-start.md    dispara o orquestrador com isolation: worktree
    │   └── task-{test,execute,code-review,end}.md   wrappers finos
    ├── references/
    │   ├── pipeline-config.md       schema e semântica do pipeline.yaml
    │   ├── spec-template.md         estrutura da task spec + Definition of Done
    │   ├── handoff-log.md           protocolo do Agent Handoff Log e escalonamento
    │   ├── tracker-none.md
    │   ├── tracker-linear.md
    │   └── tracker-github.md
    └── README.md
```

Instalação no projeto consumidor:

```
/plugin marketplace add dfrnks/claude-plugins
/plugin install tdd-pipeline
```

Comandos e agents ficam namespaced (`/tdd-pipeline:task-start`,
`subagent_type: "tdd-pipeline:task-test"`). Isso evita colisão com qualquer
`.claude/` já existente no projeto, permitindo instalação lado a lado.

Os arquivos de `references/` são carregados por caminho via
`${CLAUDE_PLUGIN_ROOT}`. Cada contrato (schema de config, template de spec,
protocolo de handoff) existe em exatamente um lugar, em vez de duplicado nos
cinco prompts.

### Contrato de configuração

`.claude/pipeline.yaml`, no projeto consumidor. É o único arquivo obrigatório.

```yaml
version: 1
project: my-app

tracker:
  type: none                  # none | linear | github
  prefix: TASK                # prefixo de ID; vira nome de branch
  # team:   <string>          # apenas linear
  # states: { start: "In Progress", review: "In Review" }

commands:
  test: "pytest {target}"     # {target} = módulo/arquivo específico
  test_all: "pytest"
  lint: "ruff check . --fix && ruff format ."
  # typecheck: "mypy ."       # opcional

paths:
  tests: [tests]
  specs: .claude/tasks
  worktrees: .claude/worktrees
  conventions: CLAUDE.md
  # review_checklist: .claude/review-checklist.md   # opcional

git:
  base_branch: main
  commit_trailer: ""
  # worktree_setup: scripts/setup-worktree.sh       # opcional

pr:
  enabled: true
```

**Fail-fast é obrigatório.** Todo agent lê este arquivo no passo 0. Se ele não
existir, ou se faltar uma chave que o agent vai usar, o agent para imediatamente
e nomeia a chave ausente. Nenhum agent infere comando de teste ou de lint a
partir de `package.json`, `pyproject.toml` ou `Makefile`: o pipeline roda
desatendido, e adivinhar errado nesse ponto custa uma branch inteira de trabalho
inválido.

`worktree_setup` cobre o caso de dependências ignoradas pelo versionamento
(`.venv`, `node_modules`, `.env`) que não existem num worktree recém-criado. Se
declarado, o orquestrador executa o script antes de rodar qualquer fase; se
ausente, segue direto.

### Camada de tracker

`tracker.type` seleciona qual `references/tracker-*.md` o agent carrega. O
tracker entra em exatamente dois pontos do pipeline: resolver ou criar o item em
`/task-start`, e atualizar o status em `task-end`. Todo o resto — branch,
worktree, spec, handoff log, PR — é idêntico nos três modos.

- **`none`** (default): o ID vem do argumento do comando. Spec local, nenhuma
  chamada externa. É o caminho documentado no README.
- **`linear`**: MCP do Linear. Resolve ou cria issue, move para `states.start` e
  depois `states.review`.
- **`github`**: `gh issue` / `gh pr`. Labels no lugar de estados nomeados.

## Genericização dos agents

Cada prompt herdado é cortado em duas partes: mecânica, que permanece e passa a
ser parametrizada pela config; e regra de stack, que sai do plugin e passa a ser
leitura de `paths.conventions`.

| Agent | Permanece | Sai |
|---|---|---|
| `task-isolate-start` | guarda de isolamento, rename da branch para o ID, sync com a base, gate de review-plan, orquestração das quatro fases | caminho absoluto do repositório, script de setup fixo |
| `task-test` | estudo obrigatório dos padrões de teste existentes, plano de teste por dimensão, verificação da fase red, handoff log, commit | framework de teste, padrões de mock, caminhos, convenções de endpoint |
| `task-execute` | leitura do handoff log, contrato de proteção dos testes, self-review crítico, loop de verificação por item de DoD, lint gate obrigatório, commit, report ≤300 caracteres | bloco de regras de arquitetura, comandos de lint e teste, procedimento de migration |
| `task-code-review` | conformidade com a spec, integridade dos testes, qualidade de teste, segurança e isolamento, verificação do manifest contra o checklist, veredito em três níveis | regras de camada específicas, comandos, caminhos |
| `task-end` | detecção de áreas alteradas, lint, persistência de descobertas nas convenções, commit e push, PR, status no tracker, dica de limpeza do worktree | ferramentas de lint fixas, estrutura de pacotes, caminho de worktree fixo |

### Guarda de isolamento portátil

A guarda que impede o orquestrador de rodar no repositório principal hoje
compara com um caminho absoluto. A versão portátil compara
`git rev-parse --show-toplevel` com o diretório-pai de
`git rev-parse --git-common-dir`: se forem iguais, o processo está no
repositório principal e não num worktree. Funciona em qualquer repositório, sem
configuração.

### Risco principal e mitigação

Trocar regra inline por ponteiro para o arquivo de convenções reduz
determinismo: regra inline é lida sempre, ponteiro depende de o agent achar e
aplicar a seção certa.

Mitigação em duas pontas: `task-execute` passa a citar no handoff log as linhas
de convenção que aplicou, e `task-code-review` confere essas citações contra o
arquivo. Se o agent não encontrou regra para a área que tocou, isso vira aviso
explícito no veredito em vez de passar em silêncio.

## Inversão: mecânica de pipeline sai do arquivo de convenções

No projeto de origem, o arquivo de convenções acumulou protocolo de pipeline
misturado com fatos do projeto: estrutura obrigatória da task spec, estrutura de
subtask, formato do Agent Handoff Log, regra de não improvisar passos de
workflow.

Nada disso é fato de projeto — é protocolo do pipeline. Tudo migra para
`references/spec-template.md` e `references/handoff-log.md` dentro do plugin.

Consequência prática: um projeto novo adota o pipeline com um `pipeline.yaml` e
**nenhuma** seção obrigatória no arquivo de convenções. O arquivo de convenções
volta a conter só o que é do projeto — arquitetura, padrões, armadilhas.

## `/tdd-pipeline:init`

Bootstrap do projeto consumidor:

1. Detecta a stack (gerenciador de pacotes, runner de teste, linter) e **propõe**
   um `pipeline.yaml` para confirmação — nunca escreve sem aprovação.
2. Cria `paths.specs` e `.claude/agent-memory/`.
3. Verifica se `paths.conventions` existe; se não, oferece um esqueleto mínimo.
4. Semeia um `review-checklist.md` genérico, se o usuário quiser.

Detecção automática é aceitável aqui, e só aqui, porque há um humano confirmando
o resultado antes de qualquer escrita.

## Memória de agent

Os agents mantêm `memory: project` e escrevem em
`.claude/agent-memory/<agent>/`. Essa mecânica já é genérica e permanece. O
bloco extenso de instruções de memória colado dentro de um dos prompts herdados
é removido: o harness já injeta esse conteúdo, e a cópia manual apenas duplica e
apodrece.

## Validação

Repositório descartável, Python puro, `tracker: none`, uma task pequena e real
de ponta a ponta:

```
/tdd-pipeline:init
/tdd-pipeline:task-start "adicionar validação de CPF"
/tdd-pipeline:task-review TASK-1
/tdd-pipeline:task-isolate-start TASK-1
```

Critérios de aceite:

1. O pipeline chega a `SHIPPED` com PR aberto, sem intervenção manual.
2. Cada fase deixou sua entrada no Agent Handoff Log.
3. `task-code-review` de fato bloqueia quando um teste é enfraquecido —
   verificado injetando deliberadamente uma alteração de assertion.
4. `grep -riE` no repositório do plugin não retorna nome de projeto real,
   caminho absoluto, nome de pessoa nem identificador de organização.

Nenhum projeto existente é tocado durante a validação.

## Fora de escopo

- `/adr`, `/fix-bug`, `/review-pr` — independentes do pipeline; entram como um
  segundo plugin no mesmo marketplace, depois.
- Packs de convenção prontos por stack.
- Migração de qualquer projeto existente para consumir o plugin.
