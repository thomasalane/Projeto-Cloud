#!/bin/bash
# Um papel do IAM para cada funcao.  RNF-02, RD-02.
#
# O roteiro usa um papel so, com "Resource": "*". Aqui cada funcao tem
# o seu papel, cada permissao nomeia o recurso exato deste projeto, e
# nenhuma e de exclusao ou atualizacao: e o que o RNF-02 promete. O
# RD-02 (experimento registrado nao se altera nem se apaga) depende
# disto E da condicao do put_item na funcao gravar: dynamodb:PutItem
# substituiria um item de mesma chave (02-arquitetura, secao 9).
#
# Gravacao pode, e so pode:
#   s3:PutObject          guardar o PNG em graficos/ do bucket
#   dynamodb:PutItem      inserir o experimento na tabela
#   logs                  escrever o proprio registro (RNF-04)
# Consulta pode, e so pode:
#   dynamodb:Query        listar a particao de um projeto (RF-03)
#   dynamodb:GetItem      abrir um experimento pela chave (RF-05)
#   logs                  escrever o proprio registro
set -e
cd "$(dirname "$0")"
source ./config.sh

CONFIANCA='{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {"Service": "lambda.amazonaws.com"},
    "Action": "sts:AssumeRole"
  }]
}'

CONTA=$($AWS sts get-caller-identity --query Account --output text)
ARN_TABELA="arn:aws:dynamodb:${REGIAO}:${CONTA}:table/${TABELA}"
ARN_GRAFICOS="arn:aws:s3:::${BUCKET}/graficos/*"

arn_logs() {
  echo "arn:aws:logs:${REGIAO}:${CONTA}:log-group:/aws/lambda/$1:*"
}

# Uso: criar_papel <papel> <nome da politica> <documento da politica>
criar_papel() {
  local papel="$1" politica="$2" documento="$3"
  if $AWS iam get-role --role-name "$papel" >/dev/null 2>&1; then
    echo "papel ja existe: $papel"
  else
    $AWS iam create-role \
      --role-name "$papel" \
      --assume-role-policy-document "$CONFIANCA" >/dev/null
    echo "papel criado: $papel"
  fi
  $AWS iam put-role-policy \
    --role-name "$papel" \
    --policy-name "$politica" \
    --policy-document "$documento"
  echo "politica anexada ao papel $papel"
}

GRAVAR='{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "GuardarGrafico",
      "Effect": "Allow",
      "Action": "s3:PutObject",
      "Resource": "ARN_GRAFICOS"
    },
    {
      "Sid": "InserirExperimento",
      "Effect": "Allow",
      "Action": "dynamodb:PutItem",
      "Resource": "ARN_TABELA"
    },
    {
      "Sid": "EscreverRegistro",
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "ARN_LOGS"
    }
  ]
}'
GRAVAR="${GRAVAR//ARN_GRAFICOS/$ARN_GRAFICOS}"
GRAVAR="${GRAVAR//ARN_TABELA/$ARN_TABELA}"
GRAVAR="${GRAVAR//ARN_LOGS/$(arn_logs "$FUNCAO_GRAVAR")}"

CONSULTAR='{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "LerExperimentos",
      "Effect": "Allow",
      "Action": [
        "dynamodb:Query",
        "dynamodb:GetItem"
      ],
      "Resource": "ARN_TABELA"
    },
    {
      "Sid": "EscreverRegistro",
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "ARN_LOGS"
    }
  ]
}'
CONSULTAR="${CONSULTAR//ARN_TABELA/$ARN_TABELA}"
CONSULTAR="${CONSULTAR//ARN_LOGS/$(arn_logs "$FUNCAO_CONSULTAR")}"

criar_papel "$PAPEL_GRAVAR" "${PREFIXO}-politica-gravar" "$GRAVAR"
criar_papel "$PAPEL_CONSULTAR" "${PREFIXO}-politica-consultar" "$CONSULTAR"
