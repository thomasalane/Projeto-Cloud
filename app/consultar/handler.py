"""Consulta os experimentos.  RF-03, RF-05, RNF-01.

Duas rotas, uma funcao (02-arquitetura, secao 8: o RF-05 nao pede uma
terceira funcao):

  GET /experimentos?projeto=X          lista do projeto (RF-03)
  GET /experimentos/{id}?projeto=X     um experimento (RF-05)

Em relacao ao codigo generico do roteiro:

1. A lista sai do proprio banco do mais recente ao mais antigo
   (ScanIndexForward=False), porque o identificador comeca pela data e
   hora. Nao ha scan nem ordenacao depois (RNF-01).

2. O detalhe e um get_item pela chave completa, projeto + identificador.
   Identificador que nao existe naquele projeto e 404 (US-03, cenario 2);
   projeto sem experimentos e 200 com total 0 (US-02, cenario 2).

3. O valor volta como texto exato: 0.412 volta "0.412", nunca 0.41199999
   (US-01, cenario 1).

4. A trilha, como na funcao gravar, alimenta o painel da pagina.

Esta funcao so le: o papel dela nao tem permissao de escrita (RNF-02).
"""
import json
import os
import time
from datetime import datetime, timezone
from decimal import Decimal
from urllib.parse import quote

import boto3
from boto3.dynamodb.conditions import Key
from botocore.exceptions import BotoCoreError, ClientError

TABELA = os.environ["TABELA"]
BASE_GRAFICOS = os.environ["BASE_GRAFICOS"]

dynamodb = boto3.resource("dynamodb")
tabela = dynamodb.Table(TABELA)

# 02-arquitetura, secao 9: a lista traz no maximo os 100 mais recentes
LIMITE_MAXIMO = 100

CAMPOS_DA_LISTA = ["id_experimento", "criado_em", "modelo", "metrica", "valor"]


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
    ms = round((time.perf_counter() - inicio) * 1000, 1) if inicio else None
    trilha.append({"servico": servico, "acao": acao, "ms": ms, "ok": ok})


def registrar(evento, projeto, detalhe):
    agora = datetime.now(timezone.utc).isoformat()
    print("{} em={} projeto={} {}".format(
        evento, agora, projeto or "-", detalhe
    ))


def texto_exato(item):
    # Decimal vira texto sem passar por float
    return {k: format(v, "f") if isinstance(v, Decimal) else v
            for k, v in item.items()}


def falha(trilha, inicio, projeto, erro):
    passo(trilha, "dynamodb", "consulta falhou ({})".format(type(erro).__name__),
          inicio, False)
    registrar("falha", projeto,
              "motivo=consulta nao respondida ({})".format(type(erro).__name__))
    passo(trilha, "cloudwatch", "falha registrada")
    return resposta(503, {
        "erro": "a consulta não respondeu; tente de novo", "trilha": trilha
    })


def lambda_handler(event, context):
    trilha = []
    parametros = event.get("queryStringParameters") or {}
    caminho = event.get("pathParameters") or {}

    # o projeto e gravado em minusculas: a busca tambem precisa ser
    projeto = (parametros.get("projeto") or "").strip().lower()
    if not projeto:
        passo(trilha, "lambda-consultar", "recusou: faltou o projeto", ok=False)
        return resposta(400, {
            "erro": "informe o projeto", "campos": ["projeto"], "trilha": trilha
        })

    id_experimento = (caminho.get("id") or "").strip()
    if id_experimento:
        return detalhe(trilha, projeto, id_experimento)
    return lista(trilha, projeto, parametros.get("limite"))


def lista(trilha, projeto, limite_pedido):
    # RF-03
    try:
        limite = int(limite_pedido or LIMITE_MAXIMO)
    except ValueError:
        passo(trilha, "lambda-consultar", "recusou: limite não é número", ok=False)
        return resposta(400, {
            "erro": "o limite precisa ser um número", "campos": ["limite"],
            "trilha": trilha,
        })
    # o limite vem de fora: sem o teto, alguem pediria milhoes de itens
    limite = max(1, min(limite, LIMITE_MAXIMO))
    passo(trilha, "lambda-consultar", "rota da lista (RF-03), até {} itens".format(limite))

    inicio = time.perf_counter()
    try:
        resultado = tabela.query(
            KeyConditionExpression=Key("projeto").eq(projeto),
            ScanIndexForward=False,
            Limit=limite,
        )
    except (BotoCoreError, ClientError) as erro:
        return falha(trilha, inicio, projeto, erro)

    itens = resultado.get("Items", [])
    passo(trilha, "dynamodb", "query só na partição '{}', ordem decrescente: {} itens".format(
        projeto, len(itens)), inicio)
    registrar("lista", projeto, "total={}".format(len(itens)))
    passo(trilha, "cloudwatch", "consulta registrada")

    # US-02, cenario 2: lista vazia e resposta, nao erro
    experimentos = [{c: texto_exato(i).get(c) for c in CAMPOS_DA_LISTA} for i in itens]
    return resposta(200, {
        "projeto": projeto,
        "total": len(experimentos),
        "experimentos": experimentos,
        "trilha": trilha,
    })


def detalhe(trilha, projeto, id_experimento):
    # RF-05
    passo(trilha, "lambda-consultar", "rota do detalhe (RF-05)")
    inicio = time.perf_counter()
    try:
        resultado = tabela.get_item(
            Key={"projeto": projeto, "id_experimento": id_experimento}
        )
    except (BotoCoreError, ClientError) as erro:
        return falha(trilha, inicio, projeto, erro)

    item = resultado.get("Item")
    passo(trilha, "dynamodb", "get_item pela chave completa: {}".format(
        "encontrou 1 item" if item else "não encontrou"), inicio, bool(item))
    registrar("detalhe", projeto, "id={} encontrado={}".format(
        id_experimento, "sim" if item else "nao"))
    passo(trilha, "cloudwatch", "consulta registrada")

    # US-03, cenario 2: nao mostra nada de outros experimentos
    if not item:
        return resposta(404, {
            "erro": "experimento não encontrado no projeto {}".format(projeto),
            "total": 0,
            "trilha": trilha,
        })

    experimento = texto_exato(item)
    experimento["grafico"] = "{}/{}".format(BASE_GRAFICOS, quote(item["grafico"]))
    return resposta(200, {"total": 1, "experimento": experimento, "trilha": trilha})
