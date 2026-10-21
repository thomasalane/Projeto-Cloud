#!/bin/bash
# Remove tudo, na ordem inversa da criacao.
# Sem "set -e" e com "|| true" em cada linha: remover o que ja nao
# existe nao e erro, e um ambiente pela metade tambem precisa limpar.
cd "$(dirname "$0")"
source ./config.sh

$AWS lambda delete-function \
  --function-name "$FUNCAO_GRAVAR" >/dev/null 2>&1 || true
$AWS logs delete-log-group \
  --log-group-name "/aws/lambda/${FUNCAO_GRAVAR}" 2>/dev/null || true
$AWS iam delete-role-policy --role-name "$PAPEL_GRAVAR" \
  --policy-name "${PREFIXO}-politica-gravar" 2>/dev/null || true
$AWS iam delete-role \
  --role-name "$PAPEL_GRAVAR" 2>/dev/null || true
$AWS dynamodb delete-table \
  --table-name "$TABELA" >/dev/null 2>&1 || true
$AWS s3 rb "s3://$BUCKET" --force >/dev/null 2>&1 || true

rm -f ../app/gravar/funcao.zip

echo "recursos removidos"
