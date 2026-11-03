#!/bin/bash
# A pagina: camada de apresentacao, servida pelo bucket diario-site.
# US-01, US-02, US-03, RD-01 (o aviso esta no formulario).
set -e
cd "$(dirname "$0")"
source ./config.sh

URL_API=$(cat .url-api)

if $AWS s3api head-bucket --bucket "$BUCKET_SITE" >/dev/null 2>&1; then
  echo "bucket do site ja existe: $BUCKET_SITE"
else
  $AWS s3api create-bucket \
    --bucket "$BUCKET_SITE" \
    --region "$REGIAO" >/dev/null
  echo "bucket do site criado: $BUCKET_SITE"
fi

$AWS s3 website "s3://${BUCKET_SITE}" --index-document index.html

# Leitura publica do bucket inteiro: e como um site funciona. Por isso
# ele e separado do bucket de graficos (02-arquitetura, secao 9).
POLITICA='{
  "Version": "2012-10-17",
  "Statement": [{
    "Sid": "LeituraPublicaDoSite",
    "Effect": "Allow",
    "Principal": "*",
    "Action": "s3:GetObject",
    "Resource": "arn:aws:s3:::NOME_BUCKET/*"
  }]
}'
POLITICA="${POLITICA//NOME_BUCKET/$BUCKET_SITE}"
$AWS s3api put-bucket-policy --bucket "$BUCKET_SITE" --policy "$POLITICA"

# O config.js e gerado aqui, e nao escrito a mao: o endereco da API
# muda a cada reconstrucao. Ele leva so o endereco publico, nenhuma
# credencial (02-arquitetura, secao 2.1).
cat > ../app/site/config.js <<EOF
// Gerado por infra/07-site.sh. Nao leva credencial: so o endereco da API.
window.DIARIO_CONFIG = { apiUrl: "${URL_API}" };
EOF

$AWS s3 cp ../app/site/ "s3://${BUCKET_SITE}/" --recursive >/dev/null
echo "pagina publicada em http://${BUCKET_SITE}.s3-website.localhost.localstack.cloud:4566/"
