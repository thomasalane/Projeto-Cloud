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

6. A trilha (Sprint 4). Toda resposta leva a lista do que a funcao fez
   em cada servico, com o tempo de cada passo. E ela que a pagina usa
   no painel "Por tras da tela" (02-arquitetura, secao 9).
"""
import base64
import binascii
import json
import os
import secrets
import time
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


def passo(trilha, servico, acao, inicio=None, ok=True):
    # ok=None marca o servico que nao foi tocado
    ms = round((time.perf_counter() - inicio) * 1000, 1) if inicio else None
    trilha.append({"servico": servico, "acao": acao, "ms": ms, "ok": ok})


def registrar(evento, projeto, detalhe):
    # RNF-04: data e hora, projeto e motivo. Nunca o conteudo (RD-01).
    agora = datetime.now(timezone.utc).isoformat()
    print("{} em={} projeto={} {}".format(
        evento, agora, projeto or "-", detalhe
    ))


def recusar(trilha, inicio, projeto, motivo, campos, extra=None):
    passo(trilha, "lambda-gravar", "validação recusou: " + motivo, inicio, False)
    passo(trilha, "s3", "não foi tocado: nada é gravado antes de validar", ok=None)
    passo(trilha, "dynamodb", "não foi tocado", ok=None)
    registrar("recusado", projeto, "motivo={}".format(motivo))
    passo(trilha, "cloudwatch", "recusa registrada, com projeto e motivo")
    corpo = {"erro": motivo, "campos": campos, "trilha": trilha}
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
    trilha = []
    inicio = time.perf_counter()

    corpo = event.get("body") or "{}"
    if event.get("isBase64Encoded"):
        corpo = base64.b64decode(corpo).decode("utf-8")
    try:
        # parse_float=Decimal: 0.412 vindo como numero nao passa por float
        dados = json.loads(corpo, parse_float=Decimal)
    except json.JSONDecodeError:
        dados = None
    if not isinstance(dados, dict):
        return recusar(trilha, inicio, None, "corpo não é JSON válido", ["corpo"])

    # 02-arquitetura, secao 9: o projeto e a particao, entao
    # "Previsao-Inflacao" e "previsao-inflacao" precisam ser o mesmo
    projeto = None
    if not vazio(dados.get("projeto")):
        projeto = str(dados["projeto"]).strip().lower()

    # RF-04: recusa e diz qual campo faltou
    faltando = [c for c in CAMPOS_OBRIGATORIOS if vazio(dados.get(c))]
    if faltando:
        return recusar(trilha, inicio, projeto,
                       "campos obrigatórios ausentes", faltando)

    # RF-04 e US-01, cenario 2: "baixo" nao e numero
    valor = ler_valor(dados["valor"])
    if valor is None:
        return recusar(trilha, inicio, projeto,
                       "o valor da métrica precisa ser numérico", ["valor"])

    try:
        imagem = base64.b64decode(dados["grafico"], validate=True)
    except (binascii.Error, ValueError, TypeError):
        return recusar(trilha, inicio, projeto,
                       "o gráfico não é base64 válido", ["grafico"])
    if not imagem.startswith(ASSINATURA_PNG):
        return recusar(trilha, inicio, projeto,
                       "o gráfico precisa ser PNG", ["grafico"])
    if len(imagem) > LIMITE_GRAFICO_BYTES:
        return recusar(trilha, inicio, projeto, "o gráfico passa de 2 MB",
                       ["grafico"], {"limite_bytes": LIMITE_GRAFICO_BYTES})

    passo(trilha, "lambda-gravar",
          "validação passou: campos, valor numérico, PNG de até 2 MB", inicio)

    # RF-01: identificador unico e data e hora a cada registro
    agora = datetime.now(timezone.utc)
    id_experimento = "{}-{}".format(
        agora.strftime("%Y%m%d-%H%M%S-%f"), secrets.token_hex(3)
    )
    chave = "graficos/{}/{}.png".format(projeto, id_experimento)

    # RF-02 e RNF-03: o grafico primeiro. Se nao subir, o experimento
    # nao chega a existir.
    inicio = time.perf_counter()
    try:
        s3.put_object(
            Bucket=BUCKET,
            Key=chave,
            Body=imagem,
            ContentType="image/png",
        )
    except (BotoCoreError, ClientError) as erro:
        passo(trilha, "s3", "put_object falhou ({})".format(type(erro).__name__),
              inicio, False)
        passo(trilha, "dynamodb", "não foi tocado: sem gráfico, sem experimento",
              ok=None)
        registrar("falha", projeto,
                  "motivo=grafico nao guardado ({})".format(type(erro).__name__))
        passo(trilha, "cloudwatch", "falha registrada")
        return resposta(503, {
            "erro": "não foi possível guardar o gráfico; tente de novo",
            "trilha": trilha,
        })
    passo(trilha, "s3", "1º put_object {} ({} KB)".format(
        chave, max(1, len(imagem) // 1024)), inicio)

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
    inicio = time.perf_counter()
    try:
        tabela.put_item(
            Item=item,
            ConditionExpression="attribute_not_exists(id_experimento)",
        )
    except (BotoCoreError, ClientError) as erro:
        passo(trilha, "dynamodb", "put_item falhou ({})".format(type(erro).__name__),
              inicio, False)
        registrar("falha", projeto,
                  "motivo=experimento nao gravado ({})".format(type(erro).__name__))
        passo(trilha, "cloudwatch", "falha registrada")
        return resposta(503, {
            "erro": "não foi possível registrar o experimento; tente de novo",
            "trilha": trilha,
        })
    passo(trilha, "dynamodb",
          "2º put_item condicional: só grava se o identificador não existir", inicio)

    registrar("gravado", projeto, "id={}".format(id_experimento))
    passo(trilha, "cloudwatch", "registro gravado")

    return resposta(201, {
        "id_experimento": id_experimento,
        "projeto": projeto,
        "criado_em": item["criado_em"],
        "valor": format(valor, "f"),
        "grafico": "{}/{}".format(BASE_GRAFICOS, quote(chave)),
        "trilha": trilha,
    })
