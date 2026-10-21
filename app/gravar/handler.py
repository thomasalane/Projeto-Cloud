"""Grava um experimento no Diario de Experimentos.  RF-01, RF-02, RF-04.

Esta e a funcao da Sprint 3, adaptada ao cenario. Em relacao ao codigo
generico do roteiro, mudou o seguinte, e cada mudanca vem de um
documento ja entregue:

1. Os campos. O roteiro usa id_particao, descricao e valor. Aqui sao
   os do RF-01: projeto, modelo, hiperparametros, metrica e valor, e
   o grafico do RF-02.

2. O arquivo no S3. O roteiro guarda no S3 o proprio registro em JSON.
   O RF-02 promete guardar o grafico do resultado: aqui vai o PNG.
   E ele vai ANTES do experimento entrar na tabela (RNF-03): nunca
   existe experimento apontando para grafico que nao subiu.

3. O valor. O roteiro grava texto com duas casas, o que transformaria
   0,412 em 0,41 e quebraria o US-01, cenario 1. Aqui ele e Decimal,
   guardado como foi digitado, com virgula ou com ponto (FURPS U).
   E nao precisa ser positivo: um R2 pode ser negativo.

4. O identificador. Comeca pela data e hora, para a tabela ja ordenar
   do mais recente ao mais antigo (02-arquitetura, secao 6.2).

5. O registro. Toda recusa ou falha imprime data e hora, projeto e
   motivo, e nunca o conteudo enviado (RNF-04, RD-01).
"""
import base64
import binascii
import json
import os
import secrets
from datetime import datetime, timezone
from decimal import Decimal, InvalidOperation
from urllib.parse import quote

import boto3
from boto3.dynamodb.types import DYNAMODB_CONTEXT
from botocore.exceptions import BotoCoreError, ClientError

TABELA = os.environ["TABELA"]
BUCKET = os.environ["BUCKET"]
BASE_GRAFICOS = os.environ["BASE_GRAFICOS"]

dynamodb = boto3.resource("dynamodb")
s3 = boto3.client("s3")
tabela = dynamodb.Table(TABELA)

# RF-04. Os hiperparametros ficam de fora de proposito: o modelo de
# referencia, que repete o ultimo valor, nao tem nenhum
# (01-requisitos, secao 2).
CAMPOS_OBRIGATORIOS = ["projeto", "modelo", "metrica", "valor", "grafico"]

ASSINATURA_PNG = b"\x89PNG\r\n\x1a\n"
LIMITE_GRAFICO_BYTES = 2 * 1024 * 1024


def resposta(codigo, corpo):
    return {
        "statusCode": codigo,
        "headers": {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*",
        },
        "body": json.dumps(corpo, ensure_ascii=False),
    }


def registrar(evento, projeto, detalhe):
    # RNF-04: data e hora, projeto e motivo. Nunca o conteudo (RD-01).
    agora = datetime.now(timezone.utc).isoformat()
    print("{} em={} projeto={} {}".format(
        evento, agora, projeto or "-", detalhe
    ))


def recusar(projeto, motivo, extra=None):
    registrar("recusado", projeto, "motivo={}".format(motivo))
    corpo = {"erro": motivo}
    corpo.update(extra or {})
    return resposta(400, corpo)


def vazio(valor):
    # 0 e um valor de metrica valido; so falta o que nao veio ou veio em branco
    return valor is None or (isinstance(valor, str) and not valor.strip())


def ler_valor(bruto):
    """Devolve o valor como Decimal, ou None se nao for numero."""
    if isinstance(bruto, bool):
        return None
    if isinstance(bruto, (int, Decimal)):
        numero = Decimal(bruto)
    else:
        texto = str(bruto).strip()
        if "," in texto and "." in texto:  # "1.234,5" e ambiguo
            return None
        try:
            numero = Decimal(texto.replace(",", "."))  # FURPS U
        except InvalidOperation:
            return None
    if not numero.is_finite():  # "NaN" e infinito nao se comparam
        return None
    try:
        # o DynamoDB guarda ate 38 digitos: o que nao cabe e recusado
        # aqui, antes de o grafico subir
        DYNAMODB_CONTEXT.create_decimal(numero)
    except ArithmeticError:
        return None
    return numero


def lambda_handler(event, context):
    try:
        # parse_float=Decimal: 0.412 vindo como numero nao passa por float
        dados = json.loads(event.get("body") or "{}", parse_float=Decimal)
    except json.JSONDecodeError:
        return recusar(None, "corpo não é JSON válido")
    if not isinstance(dados, dict):
        return recusar(None, "corpo não é JSON válido")

    # 02-arquitetura, secao 9: o projeto e a particao, entao
    # "Previsao-Inflacao" e "previsao-inflacao" precisam ser o mesmo
    projeto = None
    if not vazio(dados.get("projeto")):
        projeto = str(dados["projeto"]).strip().lower()

    # RF-04: recusa e diz qual campo faltou
    faltando = [c for c in CAMPOS_OBRIGATORIOS if vazio(dados.get(c))]
    if faltando:
        return recusar(projeto, "campos obrigatórios ausentes",
                       {"campos": faltando})

    # RF-04 e US-01, cenario 2: "baixo" nao e numero
    valor = ler_valor(dados["valor"])
    if valor is None:
        return recusar(projeto, "o valor da métrica precisa ser numérico",
                       {"campo": "valor"})

    try:
        imagem = base64.b64decode(dados["grafico"], validate=True)
    except (binascii.Error, ValueError, TypeError):
        return recusar(projeto, "o gráfico não é base64 válido",
                       {"campo": "grafico"})
    if not imagem.startswith(ASSINATURA_PNG):
        return recusar(projeto, "o gráfico precisa ser PNG",
                       {"campo": "grafico"})
    if len(imagem) > LIMITE_GRAFICO_BYTES:
        return recusar(projeto, "o gráfico passa de 2 MB",
                       {"campo": "grafico", "limite_bytes": LIMITE_GRAFICO_BYTES})

    # RF-01: identificador unico e data e hora a cada registro
    agora = datetime.now(timezone.utc)
    id_experimento = "{}-{}".format(
        agora.strftime("%Y%m%d-%H%M%S-%f"), secrets.token_hex(3)
    )
    chave = "graficos/{}/{}.png".format(projeto, id_experimento)

    # RF-02 e RNF-03: o grafico primeiro. Se nao subir, o experimento
    # nao chega a existir.
    try:
        s3.put_object(
            Bucket=BUCKET,
            Key=chave,
            Body=imagem,
            ContentType="image/png",
        )
    except (BotoCoreError, ClientError) as erro:
        registrar("falha", projeto,
                  "motivo=grafico nao guardado ({})".format(type(erro).__name__))
        return resposta(503, {
            "erro": "não foi possível guardar o gráfico; tente de novo"
        })

    item = {
        "projeto": projeto,
        "id_experimento": id_experimento,
        "criado_em": agora.isoformat(),
        "modelo": str(dados["modelo"]).strip(),
        "metrica": str(dados["metrica"]).strip(),
        "valor": valor,
        "grafico": chave,
    }
    # US-03, cenario 1: hiperparametros identicos aos digitados
    if not vazio(dados.get("hiperparametros")):
        item["hiperparametros"] = str(dados["hiperparametros"])

    # RD-02: so grava se a chave ainda nao existir; nada e sobrescrito.
    # Se a tabela falhar aqui, o grafico ja guardado fica sem
    # experimento, e nao aparece em lugar nenhum (02-arquitetura,
    # secao 9): apaga-lo exigiria a permissao que o RNF-02 proibe.
    try:
        tabela.put_item(
            Item=item,
            ConditionExpression="attribute_not_exists(id_experimento)",
        )
    except (BotoCoreError, ClientError) as erro:
        registrar("falha", projeto,
                  "motivo=experimento nao gravado ({})".format(type(erro).__name__))
        return resposta(503, {
            "erro": "não foi possível registrar o experimento; tente de novo"
        })

    registrar("gravado", projeto, "id={}".format(id_experimento))

    return resposta(201, {
        "id_experimento": id_experimento,
        "projeto": projeto,
        "criado_em": item["criado_em"],
        "grafico": "{}/{}".format(BASE_GRAFICOS, quote(chave)),
    })
