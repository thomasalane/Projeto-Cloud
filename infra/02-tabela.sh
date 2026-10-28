#!/bin/bash
# Tabela dos experimentos.  RF-01, RF-03, RNF-01.
#   particao  projeto          o que a pessoa digita na busca
#   ordenacao id_experimento   comeca pela data e hora, entao a
#                              consulta ja sai do mais recente ao
#                              mais antigo (02-arquitetura, secao 6.2)
set -e
cd "$(dirname "$0")"
source ./config.sh

if $AWS dynamodb describe-table \
     --table-name "$TABELA" >/dev/null 2>&1; then
  echo "tabela ja existe: $TABELA"
  exit 0
fi

$AWS dynamodb create-table \
  --table-name "$TABELA" \
  --attribute-definitions \
      AttributeName=projeto,AttributeType=S \
      AttributeName=id_experimento,AttributeType=S \
  --key-schema \
      AttributeName=projeto,KeyType=HASH \
      AttributeName=id_experimento,KeyType=RANGE \
  --billing-mode PAY_PER_REQUEST >/dev/null

$AWS dynamodb wait table-exists --table-name "$TABELA"
echo "tabela criada: $TABELA"
