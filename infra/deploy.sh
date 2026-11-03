#!/bin/bash
# Cria tudo do zero, na ordem: o que e usado antes de quem usa.
# Pode rodar quantas vezes quiser: cada script confere se o recurso
# ja existe antes de criar, e nenhum dado gravado e apagado.
set -e
cd "$(dirname "$0")"

./01-bucket.sh
./02-tabela.sh
./03-papel.sh
./04-funcao-gravar.sh
./05-funcao-consultar.sh
./06-api.sh
./07-site.sh
./08-aquecer.sh

source ./config.sh
echo
echo "aplicacao no ar"
echo "  api:     $(cat .url-api)"
echo "  pagina:  http://${BUCKET_SITE}.s3-website.localhost.localstack.cloud:4566/"
echo "  se a pagina nao abrir (rede sem esse DNS): ${ENDPOINT}/${BUCKET_SITE}/index.html"
