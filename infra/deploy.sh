#!/bin/bash
# Cria tudo do zero, na ordem: o que e usado antes de quem usa.
# Pode rodar quantas vezes quiser: cada script confere se o recurso
# ja existe antes de criar.
set -e
cd "$(dirname "$0")"

./01-bucket.sh
./02-tabela.sh
./03-papel.sh
./04-funcao-gravar.sh

echo
echo "provisionamento concluido"
