#!/bin/bash
# Bucket dos graficos.  RF-02.
# O PNG de cada experimento fica em graficos/<projeto>/<id>.png.
set -e
cd "$(dirname "$0")"
source ./config.sh

if $AWS s3api head-bucket --bucket "$BUCKET" >/dev/null 2>&1; then
  echo "bucket ja existe: $BUCKET"
else
  $AWS s3api create-bucket \
    --bucket "$BUCKET" \
    --region "$REGIAO" >/dev/null
  echo "bucket criado: $BUCKET"
fi

# Leitura publica so dos arquivos de grafico, e so leitura: sem
# listagem, sem escrita. E o que deixa o endereco devolvido pela
# funcao abrir no navegador (02-arquitetura, secao 9). O RD-01
# garante que o grafico nao tem dado pessoal.
POLITICA='{
  "Version": "2012-10-17",
  "Statement": [{
    "Sid": "LeituraPublicaDosGraficos",
    "Effect": "Allow",
    "Principal": "*",
    "Action": "s3:GetObject",
    "Resource": "arn:aws:s3:::NOME_BUCKET/graficos/*"
  }]
}'
POLITICA="${POLITICA//NOME_BUCKET/$BUCKET}"

$AWS s3api put-bucket-policy \
  --bucket "$BUCKET" \
  --policy "$POLITICA"
echo "leitura publica dos graficos aplicada"
