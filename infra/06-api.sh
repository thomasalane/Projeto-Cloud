#!/bin/bash
# Porta de entrada: importa o openapi.yaml no API Gateway.
#   POST /experimentos         -> funcao gravar     (RF-01, RF-02, RF-04)
#   GET  /experimentos         -> funcao consultar  (RF-03)
#   GET  /experimentos/{id}    -> funcao consultar  (RF-05)
# Tres passos: importar (cria as rotas), autorizar (a Lambda aceita
# chamada do API Gateway) e publicar (o estagio passa a responder).
set -e
cd "$(dirname "$0")"
source ./config.sh

CONTA=$($AWS sts get-caller-identity --query Account --output text)

ARN_GRAVAR=$($AWS lambda get-function \
  --function-name "$FUNCAO_GRAVAR" \
  --query "Configuration.FunctionArn" --output text)
ARN_CONSULTAR=$($AWS lambda get-function \
  --function-name "$FUNCAO_CONSULTAR" \
  --query "Configuration.FunctionArn" --output text)

BASE="arn:aws:apigateway:${REGIAO}:lambda:path/2015-03-31/functions"
URI_GRAVAR="${BASE}/${ARN_GRAVAR}/invocations"
URI_CONSULTAR="${BASE}/${ARN_CONSULTAR}/invocations"

# O identificador da funcao muda a cada reconstrucao: por isso o
# openapi.yaml tem marcadores, e nao os enderecos escritos direto.
sed -e "s|API_NOME|${API_NOME}|g" \
    -e "s|URI_GRAVAR|${URI_GRAVAR}|g" \
    -e "s|URI_CONSULTAR|${URI_CONSULTAR}|g" \
    openapi.yaml > openapi-pronto.yaml

ID_API=$($AWS apigateway get-rest-apis \
  --query "items[?name=='${API_NOME}'].id | [0]" \
  --output text)

if [ -z "$ID_API" ] || [ "$ID_API" = "None" ]; then
  ID_API=$($AWS apigateway import-rest-api \
    --body fileb://openapi-pronto.yaml \
    --query "id" --output text)
  echo "api criada: $ID_API"
else
  $AWS apigateway put-rest-api \
    --rest-api-id "$ID_API" \
    --mode overwrite \
    --body fileb://openapi-pronto.yaml >/dev/null
  echo "api atualizada: $ID_API"
fi

ORIGEM="arn:aws:execute-api:${REGIAO}:${CONTA}:${ID_API}/*/*"
for FUNCAO in "$FUNCAO_GRAVAR" "$FUNCAO_CONSULTAR"; do
  $AWS lambda add-permission \
    --function-name "$FUNCAO" \
    --statement-id "apigw-${ID_API}" \
    --action lambda:InvokeFunction \
    --principal apigateway.amazonaws.com \
    --source-arn "$ORIGEM" >/dev/null 2>&1 || true
done

# Alterar a API nao altera o que esta no ar: so o deployment publica.
$AWS apigateway create-deployment \
  --rest-api-id "$ID_API" \
  --stage-name "$ESTAGIO" >/dev/null

# Endereco no formato que funciona mesmo sem internet. O alternativo,
# http://<id>.execute-api.localhost.localstack.cloud:4566/dev, depende
# de um DNS publico que nem toda rede resolve.
URL="${ENDPOINT}/_aws/execute-api/${ID_API}/${ESTAGIO}"

echo "$ID_API" > .id-api
echo "$URL" > .url-api
echo "api publicada em: $URL"
