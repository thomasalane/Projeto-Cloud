# Diário de Experimentos

Projeto da disciplina **Projeto em Ciência de Dados IV (Ibmec, 2º semestre de 2026)**.

Um caderno online para registrar e consultar experimentos de machine learning: cada rodada de treino é guardada com o modelo, os hiperparâmetros, a métrica e o gráfico do resultado, e depois consultada por projeto, da mais recente para a mais antiga.

O sistema roda inteiro no computador, sobre o **LocalStack** (emulador local da AWS, porta 4566, credenciais `test`). Nenhuma conta AWS real, nenhum custo.

## Estrutura

| Pasta      | Conteúdo                                                                                       | Sprint |
|------------|------------------------------------------------------------------------------------------------|--------|
| `docs/`    | Documentos do projeto (`01-requisitos.md`, `02-arquitetura.md`, `03-validacao.md`) e o roteiro da demonstração | 1, 2, 4 e 5 |
| `infra/`   | Scripts que criam e destroem os recursos (`deploy.sh`, `destroy.sh`, `config.sh`, `openapi.yaml`) | 3 e 4  |
| `app/`     | As funções `gravar` e `consultar`, e a página em `app/site/`                                    | 3 e 4  |
| `eventos/` | Cargas de teste da função de gravação                                                          | 3      |
| `dados/`   | Gerador de experimentos de exemplo para a demonstração (`semear.py`)                           | 4      |
| `testes/`  | Testes automáticos derivados dos critérios de aceite (`executar.sh`)                           | 5      |

## Estado atual

- [x] Sprint 1 — requisitos e histórias: [`docs/01-requisitos.md`](docs/01-requisitos.md)
- [x] Sprint 2 — arquitetura e requisitos não funcionais: [`docs/02-arquitetura.md`](docs/02-arquitetura.md)
- [x] Sprint 3 — armazenamento e função: bucket, tabela, papel e função `gravar`, por script
- [x] Sprint 4 — API, página e publicação: função `consultar`, `openapi.yaml` no API Gateway e página no S3
- [ ] Sprint 5 — validação: testes e relatório prontos em [`docs/03-validacao.md`](docs/03-validacao.md); falta a execução no LocalStack (seção 5 do relatório)

## Como subir o ambiente

Todo recurso nasce de script versionado, e um único comando reconstrói tudo do zero.

**Pré-requisitos:** Docker, LocalStack (`lstk`), AWS CLI v2. No Windows, rode os comandos no **Git Bash**, não no PowerShell.

```bash
lstk start
./infra/deploy.sh
```

O `deploy.sh` cria, nesta ordem: o bucket `diario-graficos`, a tabela `diario-experimentos`, os papéis `diario-papel-gravar` e `diario-papel-consultar`, as funções `diario-gravar` e `diario-consultar`, a API `diario-api` (a partir do `infra/openapi.yaml`) e a página no bucket `diario-site`; no fim, aquece as duas funções, para a primeira pessoa na página não esperar a partida a frio. Leva perto de 2 minutos. Pode rodar quantas vezes quiser: o que já existe é reaproveitado, e nenhum experimento gravado é apagado. Se o `lstk` não estiver no PATH, os scripts usam o AWS CLI direto, apontando para `http://localhost:4566` com as credenciais `test`.

## Como abrir a página

O final do deploy imprime o endereço da API e o da página:

```text
http://diario-site.s3-website.localhost.localstack.cloud:4566/
```

Se esse endereço não abrir (algumas redes não resolvem esse nome), use o alternativo:

```text
http://localhost:4566/diario-site/index.html
```

## Experimentos de exemplo

Para a lista não começar vazia, o `semear.py` treina modelos simples de previsão e registra cada rodada pela API, como a página faria. Ele também prepara, em `dados/graficos/demo/`, os arquivos da demonstração ao vivo.

```bash
pip install -r dados/requisitos.txt    # só na primeira vez
python dados/semear.py
```

O roteiro da demonstração está em [`docs/roteiro-demo.md`](docs/roteiro-demo.md).

## Como testar pela API

```bash
URL=$(cat infra/.url-api)

# grava um experimento: devolve 201 e o identificador
curl -s -X POST "$URL/experimentos" -H "Content-Type: application/json" \
  -d '{"projeto":"previsao-inflacao","modelo":"ARIMA","hiperparametros":"order=(1,1,1)","metrica":"RMSE","valor":"0,412","grafico":"iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=="}'

# lista o projeto, do mais recente ao mais antigo: devolve 200
curl -s "$URL/experimentos?projeto=previsao-inflacao"

# consulta sem o projeto: devolve 400
curl -s -o /dev/null -w "%{http_code}\n" "$URL/experimentos"
```

## Como testar a função direto

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

## Como validar

Os testes automáticos conferem os critérios de aceite e os requisitos não funcionais. Precisam de Python, sem biblioteca externa.

```bash
./testes/executar.sh            # testa o ambiente que está no ar
./testes/executar.sh --do-zero  # derruba tudo (apaga os dados), sobe do zero e testa
```

O resultado e o que cada teste cobre estão em [`docs/03-validacao.md`](docs/03-validacao.md).

## Como derrubar

```bash
./infra/destroy.sh
```
