# Diário de Experimentos

Projeto da disciplina **Projeto em Ciência de Dados IV (Ibmec, 2º semestre de 2026)**.

Um caderno online para registrar e consultar experimentos de machine learning: cada rodada de treino é guardada com o modelo, os hiperparâmetros, a métrica e o gráfico do resultado, e depois consultada por projeto, da mais recente para a mais antiga.

O sistema roda inteiro no computador, sobre o **LocalStack** (emulador local da AWS, porta 4566, credenciais `test`). Nenhuma conta AWS real, nenhum custo.

## Estrutura

| Pasta     | Conteúdo                                                        | Sprint |
|-----------|-----------------------------------------------------------------|--------|
| `docs/`   | Documentos do projeto (`01-requisitos.md`, `02-arquitetura.md`) | 1 e 2  |
| `infra/`  | Scripts que criam e destroem os recursos (`deploy.sh`, `destroy.sh`, `config.sh`, `openapi.yaml`) | 3 e 4  |
| `app/`    | Código das funções e da página                                  | 3 e 4  |
| `eventos/` | Cargas de teste da função de gravação                          | 3      |
| `testes/` | Testes automáticos derivados dos critérios de aceite (`executar.sh`) | 5      |

## Estado atual

- [x] Sprint 1 — requisitos e histórias: [`docs/01-requisitos.md`](docs/01-requisitos.md)
- [x] Sprint 2 — arquitetura e requisitos não funcionais: [`docs/02-arquitetura.md`](docs/02-arquitetura.md)
- [x] Sprint 3 — armazenamento e função: bucket, tabela, papel e função `gravar`, por script
- [ ] Sprint 4 — API, página e publicação
- [ ] Sprint 5 — validação

## Como subir o ambiente

Todo recurso nasce de script versionado, e um único comando reconstrói tudo do zero.

**Pré-requisitos:** Docker, LocalStack (`lstk`), AWS CLI v2. No Windows, rode os comandos no **Git Bash**, não no PowerShell.

```bash
lstk start
./infra/deploy.sh
```

O `deploy.sh` cria, nesta ordem: o bucket `diario-graficos`, a tabela `diario-experimentos`, o papel `diario-papel-gravar` e a função `diario-gravar`. Pode rodar quantas vezes quiser: o que já existe é reaproveitado. Se o `lstk` não estiver no PATH, os scripts usam o AWS CLI direto, apontando para `http://localhost:4566` com as credenciais `test`.

## Como testar a gravação

```bash
source infra/config.sh

# US-01, cenário 1: grava um ARIMA com RMSE 0,412 e devolve 201
$AWS lambda invoke --function-name diario-gravar \
  --payload fileb://eventos/gravar-ok.json saida.json
cat saida.json

# US-01, cenário 2: valor "baixo" é recusado com 400, e nada é gravado
$AWS lambda invoke --function-name diario-gravar \
  --payload fileb://eventos/gravar-valor-baixo.json saida-erro.json
cat saida-erro.json

# o que ficou na tabela, no bucket e no registro
$AWS dynamodb scan --table-name diario-experimentos
$AWS s3 ls s3://diario-graficos --recursive
$AWS logs tail /aws/lambda/diario-gravar --format short
```

## Como derrubar

```bash
./infra/destroy.sh
```
