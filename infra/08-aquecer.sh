#!/bin/bash
# Aquece as duas funcoes, pela propria API.
# A primeira execucao de uma Lambda recem-criada e a mais lenta (partida
# a frio): sem isto, quem paga essa espera e a primeira pessoa na pagina.
# Nenhum dado e gravado: a consulta le um projeto vazio, e a gravacao
# recebe um pedido vazio, que ela recusa com 400.
set -e
cd "$(dirname "$0")"
source ./config.sh

URL_API=$(cat .url-api)

aquecer() {
  local nome="$1"; shift
  local codigo
  codigo=$(curl -s -o /dev/null -m 60 -w "%{http_code}" "$@" || true)
  echo "$nome aquecida (respondeu $codigo)"
}

aquecer "consulta" "${URL_API}/experimentos?projeto=aquecimento"
aquecer "gravacao" -X POST "${URL_API}/experimentos" \
  -H "Content-Type: application/json" -d '{}'
