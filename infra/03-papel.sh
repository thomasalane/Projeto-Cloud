#!/bin/bash
# Papel da funcao de gravacao.  RNF-02, RD-02.
#
# O roteiro usa "Resource": "*". Aqui cada permissao nomeia o recurso
# exato deste projeto, e nenhuma permite apagar ou alterar: e o que o
# RNF-02 promete, e o que garante o RD-02 (experimento registrado nao
# se altera nem se apaga) mesmo que o codigo tenha um defeito.
#
# A funcao de gravacao pode, e so pode:
#   s3:PutObject          guardar o PNG em graficos/ do bucket
#   dynamodb:PutItem      inserir o experimento na tabela
#   logs:*LogGroup/Stream escrever o proprio registro (RNF-04)
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

if $AWS iam get-role --role-name "$PAPEL_GRAVAR" >/dev/null 2>&1; then
  echo "papel ja existe: $PAPEL_GRAVAR"
else
  $AWS iam create-role \
    --role-name "$PAPEL_GRAVAR" \
    --assume-role-policy-document "$CONFIANCA" >/dev/null
  echo "papel criado: $PAPEL_GRAVAR"
fi

CONTA=$($AWS sts get-caller-identity --query Account --output text)
ARN_TABELA="arn:aws:dynamodb:${REGIAO}:${CONTA}:table/${TABELA}"
ARN_GRAFICOS="arn:aws:s3:::${BUCKET}/graficos/*"
ARN_LOGS="arn:aws:logs:${REGIAO}:${CONTA}:log-group:/aws/lambda/${FUNCAO_GRAVAR}:*"

PERMISSOES='{
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
PERMISSOES="${PERMISSOES//ARN_GRAFICOS/$ARN_GRAFICOS}"
PERMISSOES="${PERMISSOES//ARN_TABELA/$ARN_TABELA}"
PERMISSOES="${PERMISSOES//ARN_LOGS/$ARN_LOGS}"

$AWS iam put-role-policy \
  --role-name "$PAPEL_GRAVAR" \
  --policy-name "${PREFIXO}-politica-gravar" \
  --policy-document "$PERMISSOES"

echo "politica anexada ao papel $PAPEL_GRAVAR"
