#!/bin/bash
# Remove tudo, na ordem inversa da criacao.
# Sem "set -e" e com "|| true" em cada linha: remover o que ja nao
# existe nao e erro, e um ambiente pela metade tambem precisa limpar.
cd "$(dirname "$0")"
source ./config.sh

# A API: pelo identificador guardado no deploy e, se ele se perdeu
# (emulador reiniciado, por exemplo), pelo nome.
IDS=$( { cat .id-api 2>/dev/null; $AWS apigateway get-rest-apis \
  --query "items[?name=='${API_NOME}'].id" --output text 2>/dev/null; } \
  | tr '\t' '\n' | grep -v '^None$' | sort -u)
for ID in $IDS; do
  $AWS apigateway delete-rest-api --rest-api-id "$ID" >/dev/null 2>&1 || true
done

for FUNCAO in "$FUNCAO_CONSULTAR" "$FUNCAO_GRAVAR"; do
  $AWS lambda delete-function \
    --function-name "$FUNCAO" >/dev/null 2>&1 || true
  $AWS logs delete-log-group \
    --log-group-name "/aws/lambda/${FUNCAO}" >/dev/null 2>&1 || true
done

$AWS iam delete-role-policy --role-name "$PAPEL_CONSULTAR" \
  --policy-name "${PREFIXO}-politica-consultar" >/dev/null 2>&1 || true
$AWS iam delete-role \
  --role-name "$PAPEL_CONSULTAR" >/dev/null 2>&1 || true
$AWS iam delete-role-policy --role-name "$PAPEL_GRAVAR" \
  --policy-name "${PREFIXO}-politica-gravar" >/dev/null 2>&1 || true
$AWS iam delete-role \
  --role-name "$PAPEL_GRAVAR" >/dev/null 2>&1 || true

$AWS dynamodb delete-table \
  --table-name "$TABELA" >/dev/null 2>&1 || true
$AWS s3 rb "s3://$BUCKET" --force >/dev/null 2>&1 || true
$AWS s3 rb "s3://$BUCKET_SITE" --force >/dev/null 2>&1 || true

rm -f .id-api .url-api openapi-pronto.yaml
rm -f ../app/gravar/funcao.zip ../app/consultar/funcao.zip
rm -f ../app/site/config.js

echo "recursos removidos"
