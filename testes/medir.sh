#!/bin/bash
# Mede o RNF-01 (02-arquitetura, secao 1): a lista de um projeto com 100
# experimentos deve responder em menos de 1.000 ms no percentil 95, em
# 30 requisicoes seguidas.
#
#   ./testes/medir.sh
#
# Usa o projeto "medicao-rnf01". Se ele tiver menos de 100 experimentos,
# grava o que falta antes de medir (na primeira vez, leva cerca de um
# minuto). Como nada se apaga (RD-02), as execucoes seguintes
# reaproveitam os mesmos 100.

cd "$(dirname "$0")/.."
source infra/config.sh

if [ ! -f infra/.url-api ]; then
  echo "Nao ha API no ar (falta infra/.url-api). Rode ./infra/deploy.sh" >&2
  exit 1
fi
URL=$(cat infra/.url-api)
PROJETO="medicao-rnf01"
ALVO="$URL/experimentos?projeto=$PROJETO"
AMOSTRAS=30
TEMPOS="testes/tempos.txt"

# PNG valido de 1x1, o mesmo do README
PNG_1X1="iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=="

total() {
  curl -s -m 60 "$ALVO" | sed -n 's/.*"total": *\([0-9]*\).*/\1/p'
}

# A condicao do requisito: 100 experimentos no projeto consultado
JA_TEM=$(total)
JA_TEM=${JA_TEM:-0}
if [ "$JA_TEM" -lt 100 ]; then
  echo "gravando $((100 - JA_TEM)) experimentos em $PROJETO..."
  for N in $(seq $((JA_TEM + 1)) 100); do
    curl -s -m 60 -o /dev/null -X POST "$URL/experimentos" \
      -H "Content-Type: application/json" \
      -d "{\"projeto\":\"$PROJETO\",\"modelo\":\"modelo $N\",\"metrica\":\"RMSE\",\"valor\":\"0,4\",\"grafico\":\"$PNG_1X1\"}"
  done
fi
echo "experimentos no projeto: $(total)"

# Aquecimento: a primeira execucao inclui a partida da funcao, que nao
# representa o regime normal. Ela e descartada.
curl -s -m 60 -o /dev/null "$ALVO"

for _ in $(seq 1 "$AMOSTRAS"); do
  curl -s -m 60 -o /dev/null -w "%{time_total}\n" "$ALVO"
done | LC_ALL=C sort -n > "$TEMPOS"

QTD=$(wc -l < "$TEMPOS" | tr -d ' ')
INDICE=$(( (QTD * 95 + 99) / 100 ))
P95=$(sed -n "${INDICE}p" "$TEMPOS")

echo "amostras:    $QTD"
echo "minimo (s):  $(head -1 "$TEMPOS")"
echo "mediana (s): $(sed -n "$((QTD / 2))p" "$TEMPOS")"
echo "p95 (s):     $P95"
echo "maximo (s):  $(tail -1 "$TEMPOS")"

P95_MS=$(awk -v s="$P95" 'BEGIN { printf "%d", s * 1000 }')
if [ "$P95_MS" -lt 1000 ]; then
  echo "RNF-01 cumprido: p95 de ${P95_MS} ms, abaixo de 1.000 ms"
else
  echo "RNF-01 nao cumprido: p95 de ${P95_MS} ms, acima de 1.000 ms"
  exit 1
fi
