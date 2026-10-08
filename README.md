# Diário de Experimentos

Projeto da disciplina **Projeto em Ciência de Dados IV (IBM8942, Ibmec, 2º semestre de 2026)**.

Um caderno online para registrar e consultar experimentos de machine learning: cada rodada de treino é guardada com o modelo, os hiperparâmetros, a métrica e o gráfico do resultado, e depois consultada por projeto, da mais recente para a mais antiga.

O sistema roda inteiro no computador, sobre o **LocalStack** (emulador local da AWS, porta 4566, credenciais `test`). Nenhuma conta AWS real, nenhum custo.

## Estrutura

| Pasta     | Conteúdo                                                        | Sprint |
|-----------|-----------------------------------------------------------------|--------|
| `docs/`   | Documentos do projeto (`01-requisitos.md`, `02-arquitetura.md`) | 1 e 2  |
| `infra/`  | Scripts que criam e destroem os recursos (`deploy.sh`, `destroy.sh`, `config.sh`, `openapi.yaml`) | 3 e 4  |
| `app/`    | Código das funções e da página                                  | 3 e 4  |
| `testes/` | Testes automáticos derivados dos critérios de aceite (`executar.sh`) | 5      |

## Estado atual

- [x] Sprint 1 — requisitos e histórias: [`docs/01-requisitos.md`](docs/01-requisitos.md)
- [ ] Sprint 2 — arquitetura
- [ ] Sprint 3 — armazenamento e função
- [ ] Sprint 4 — API, página e publicação
- [ ] Sprint 5 — validação

## Como subir o ambiente

A completar na Sprint 3. A regra do projeto: todo recurso nasce de script versionado, e um único comando (`./infra/deploy.sh`) reconstrói tudo do zero.
