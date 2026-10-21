#!/bin/bash
# Funcao de gravacao.  RF-01, RF-02, RF-04, RNF-03, RNF-04.
# Empacota app/gravar e publica (ou atualiza) a funcao no Lambda.
set -e
cd "$(dirname "$0")"
source ./config.sh

CONTA=$($AWS sts get-caller-identity --query Account --output text)
ARN_PAPEL="arn:aws:iam::${CONTA}:role/${PAPEL_GRAVAR}"

PASTA="../app/gravar"
empacotar "$PASTA" "$PASTA/funcao.zip"
PACOTE="fileb://${PASTA}/funcao.zip"

# Em JSON, e nao na forma curta "Variables={...}": o endereco dos
# graficos tem "://", que a forma curta nao le bem.
VARIAVEIS=$(printf '{"Variables":{"TABELA":"%s","BUCKET":"%s","BASE_GRAFICOS":"%s"}}' \
  "$TABELA" "$BUCKET" "$BASE_GRAFICOS")

if $AWS lambda get-function \
     --function-name "$FUNCAO_GRAVAR" >/dev/null 2>&1; then
  $AWS lambda update-function-code \
    --function-name "$FUNCAO_GRAVAR" \
    --zip-file "$PACOTE" >/dev/null
  $AWS lambda wait function-updated \
    --function-name "$FUNCAO_GRAVAR"
  $AWS lambda update-function-configuration \
    --function-name "$FUNCAO_GRAVAR" \
    --role "$ARN_PAPEL" \
    --environment "$VARIAVEIS" >/dev/null
  echo "funcao atualizada: $FUNCAO_GRAVAR"
else
  $AWS lambda create-function \
    --function-name "$FUNCAO_GRAVAR" \
    --runtime python3.12 \
    --handler handler.lambda_handler \
    --role "$ARN_PAPEL" \
    --zip-file "$PACOTE" \
    --timeout 15 \
    --environment "$VARIAVEIS" >/dev/null
  echo "funcao criada: $FUNCAO_GRAVAR"
fi

$AWS lambda wait function-updated \
  --function-name "$FUNCAO_GRAVAR"
echo "funcao pronta"
