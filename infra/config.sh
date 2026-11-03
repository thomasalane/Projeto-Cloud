#!/bin/bash
# Nomes e enderecos do projeto, em um lugar so.
# Os outros scripts so leem daqui: nenhum nome de recurso e escrito
# a mao em outro arquivo. Para levar o projeto a AWS real, muda este
# arquivo (ENDPOINT, credenciais) e nada mais.

PREFIXO="diario"
REGIAO="us-east-1"
ENDPOINT="http://localhost:4566"

# docs/02-arquitetura.md, secoes 2 e 6
BUCKET="${PREFIXO}-graficos"
TABELA="${PREFIXO}-experimentos"
PAPEL_GRAVAR="${PREFIXO}-papel-gravar"
FUNCAO_GRAVAR="${PREFIXO}-gravar"

# Sprint 4: a consulta, a porta de entrada e a pagina
PAPEL_CONSULTAR="${PREFIXO}-papel-consultar"
FUNCAO_CONSULTAR="${PREFIXO}-consultar"
API_NOME="${PREFIXO}-api"
ESTAGIO="dev"
BUCKET_SITE="${PREFIXO}-site"

# Endereco publico dos graficos (02-arquitetura, secao 9: grafico lido
# por endereco publico). A funcao devolve "BASE_GRAFICOS/caminho".
BASE_GRAFICOS="${ENDPOINT}/${BUCKET}"

# Forma de enviar comandos ao emulador (roteiro da Sprint 0):
# forma 1, o lstk, se estiver no PATH; senao, forma 2, o AWS CLI
# apontando para o emulador com as credenciais "test".
if command -v lstk >/dev/null 2>&1; then
  AWS="lstk aws"
else
  export AWS_ACCESS_KEY_ID="test"
  export AWS_SECRET_ACCESS_KEY="test"
  export AWS_DEFAULT_REGION="$REGIAO"
  AWS="aws --endpoint-url=$ENDPOINT"
fi

# No Git Bash do Windows, um argumento que comeca com "/" (como
# /aws/lambda/...) seria convertido em caminho do Windows antes de
# chegar ao AWS CLI. Isto desliga essa conversao.
export MSYS_NO_PATHCONV=1

# O AWS CLI no Windows imprime acento trocado ("m�trica") se nao for
# avisado de que o terminal e UTF-8.
export PYTHONUTF8=1

# Empacota uma pasta em um .zip, com o que a maquina tiver.
# Uso: empacotar <pasta> <arquivo.zip>
empacotar() {
  local pasta="$1"
  local destino="$2"
  local base="${TMPDIR:-/tmp}/pacote-$$"
  rm -rf "$base" "$base.zip"
  mkdir -p "$base"
  cp -r "$pasta"/. "$base"/
  rm -rf "$base/__pycache__" "$base"/*.zip
  if command -v zip >/dev/null 2>&1; then
    ( cd "$base" && zip -qr "$base.zip" . )
  elif command -v powershell.exe >/dev/null 2>&1; then
    powershell.exe -NoProfile -Command "Compress-Archive \
      -Path '$(cygpath -w "$base")\*' \
      -DestinationPath '$(cygpath -w "$base.zip")' -Force"
  elif command -v python3 >/dev/null 2>&1; then
    python3 -c "import shutil,sys
shutil.make_archive(sys.argv[1], 'zip', sys.argv[2])" "$base" "$base"
  else
    echo "sem zip, powershell ou python para empacotar" >&2
    return 1
  fi
  rm -f "$destino"
  mv "$base.zip" "$destino"
  rm -rf "$base"
}
