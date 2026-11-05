#!/bin/bash
# Testes automaticos da Sprint 5, derivados dos criterios de aceite
# (01-requisitos, secao 5) e dos RNFs (02-arquitetura, secao 1). Cada
# teste leva o ID do que ele confere.
#
#   ./testes/executar.sh            testa o ambiente que esta no ar
#   ./testes/executar.sh --do-zero  derruba tudo (APAGA os dados), sobe
#                                   com o deploy, testa e roda o deploy
#                                   de novo, conferindo que nada se perde
#
# Todo projeto de teste leva um sufixo unico: como nada se apaga (RD-02),
# e assim que os cenarios "projeto vazio" valem a cada rodada e que os
# testes nao misturam dados com os projetos da demonstracao.
#
# Saida: resumo na tela e em testes/ultima-execucao.txt.
# Codigo de saida: 0 se nada falhou, 1 se algo falhou.

cd "$(dirname "$0")/.."
RAIZ="$PWD"
source infra/config.sh

# No Windows, "python3" pode ser o atalho da loja, que nao executa nada:
# por isso testa rodando, e nao so procurando o nome.
if python3 -c "" >/dev/null 2>&1; then
  PY="python3"
elif python -c "" >/dev/null 2>&1; then
  PY="python"
else
  echo "Os testes precisam de Python (so a biblioteca padrao)." >&2
  exit 1
fi

# PNG valido de 1x1, o mesmo do README
PNG_1X1="iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=="

MODO_ZERO=0
[ "${1:-}" = "--do-zero" ] && MODO_ZERO=1

AGORA=$(date +%H%M%S)
RODADA="t$(date +%Y%m%d)-${AGORA}-$RANDOM"
TMP="testes/.tmp-$$"
mkdir -p "$TMP"
SAIDA="testes/ultima-execucao.txt"

: > "$TMP/saida.txt"
PASSOU=0; FALHOU=0; PULOU=0
BUCKET_ORIGINAL_RESTAURAR=0

dizer() { echo "$*" | tee -a "$TMP/saida.txt"; }
passou() { PASSOU=$((PASSOU+1)); dizer "  PASSOU  [$1] $2"; }
falhou() { FALHOU=$((FALHOU+1)); dizer "  FALHOU  [$1] $2${3:+  -> $3}"; }
pulou()  { PULOU=$((PULOU+1));   dizer "  PULOU   [$1] $2${3:+  -> $3}"; }

# Uso: conferir <id> <descricao> <obtido> <esperado>
conferir() {
  if [ "$3" = "$4" ]; then passou "$1" "$2"
  else falhou "$1" "$2" "obtido '$3', esperado '$4'"; fi
}

# Le um caminho do JSON em $TMP/corpo.json. Lista vira itens separados
# por "|", e o que nao existe vira texto vazio.
campo() {
  "$PY" - "$TMP/corpo.json" "$1" <<'EOF'
import json, sys
try:
    atual = json.load(open(sys.argv[1], encoding="utf-8"))
    for parte in sys.argv[2].split("."):
        atual = atual[int(parte)] if parte.isdigit() else atual.get(parte)
except Exception:
    atual = None
if isinstance(atual, list):
    atual = "|".join(str(i) for i in atual)
sys.stdout.write("" if atual is None else str(atual))
EOF
}

# Uma lista de um campo de cada experimento, separada por "|"
coluna() {
  "$PY" - "$TMP/corpo.json" "$1" <<'EOF'
import json, sys
dados = json.load(open(sys.argv[1], encoding="utf-8"))
sys.stdout.write("|".join(str(e.get(sys.argv[2])) for e in dados.get("experimentos", [])))
EOF
}

# Chamadas: devolvem o status em $COD e o corpo em $TMP/corpo.json
get() { COD=$(curl -s -m 60 -o "$TMP/corpo.json" -w "%{http_code}" "$URL$1"); }

# Monta o JSON em arquivo (o grafico nao caberia na linha de comando).
# Uso: post projeto=x modelo=y ...   Os campos ausentes nao vao; "-campo"
# tira um campo do padrao; arq_grafico=<arquivo> troca o grafico.
post() {
  "$PY" - "$TMP/pedido.json" "$TMP/grafico.png" "$@" <<'EOF'
import base64, json, sys
destino, grafico, *pares = sys.argv[1:]
corpo = {"modelo": "ARIMA", "hiperparametros": "order=(1,1,1)", "metrica": "RMSE", "valor": "0,412"}
arquivo = grafico
for par in pares:
    if par.startswith("-"):
        corpo.pop(par[1:], None); arquivo = None if par == "-grafico" else arquivo
    elif par.startswith("arq_grafico="):
        arquivo = par.split("=", 1)[1]
    else:
        chave, valor = par.split("=", 1); corpo[chave] = valor
if arquivo and "grafico" not in corpo:
    corpo["grafico"] = base64.b64encode(open(arquivo, "rb").read()).decode()
json.dump(corpo, open(destino, "w", encoding="utf-8"), ensure_ascii=False)
EOF
  COD=$(curl -s -m 60 -o "$TMP/corpo.json" -w "%{http_code}" -X POST "$URL/experimentos" \
    -H "Content-Type: application/json" --data-binary "@$TMP/pedido.json")
}

total() { get "/experimentos?projeto=$1"; campo total; }
graficos_no_bucket() {
  $AWS s3 ls "s3://$BUCKET/graficos/$1/" --recursive 2>/dev/null | grep -c '\.png'
}

restaurar_bucket() {
  # RNF-03 troca o bucket da funcao por um inexistente: isto sempre volta
  if [ "$BUCKET_ORIGINAL_RESTAURAR" = "1" ]; then
    $AWS lambda update-function-configuration --function-name "$FUNCAO_GRAVAR" \
      --environment "$(variaveis_gravar "$BUCKET")" >/dev/null 2>&1
    $AWS lambda wait function-updated --function-name "$FUNCAO_GRAVAR" >/dev/null 2>&1
    BUCKET_ORIGINAL_RESTAURAR=0
  fi
}
limpar() { restaurar_bucket; rm -rf "$TMP"; }
trap limpar EXIT

variaveis_gravar() {
  printf '{"Variables":{"TABELA":"%s","BUCKET":"%s","BASE_GRAFICOS":"%s"}}' \
    "$TABELA" "$1" "$BASE_GRAFICOS"
}

# ---------------------------------------------------------------- do zero
if [ "$MODO_ZERO" = "1" ]; then
  dizer "== Demoday: do ambiente derrubado ao sistema no ar"
  ./infra/destroy.sh >/dev/null 2>&1
  conferir "DEMO" "destroy.sh deixa 0 funcoes do projeto" \
    "$($AWS lambda list-functions --query "length(Functions[?starts_with(FunctionName, '${PREFIXO}-')])" --output text)" "0"
  conferir "DEMO" "destroy.sh deixa 0 tabelas do projeto" \
    "$($AWS dynamodb list-tables --query "length(TableNames[?starts_with(@, '${PREFIXO}-')])" --output text)" "0"
  T0=$(date +%s)
  if ./infra/deploy.sh > "$TMP/deploy.txt" 2>&1; then
    passou "DEMO" "deploy.sh sobe tudo do zero em $(( $(date +%s) - T0 )) s"
  else
    falhou "DEMO" "deploy.sh falhou" "$(tail -3 "$TMP/deploy.txt" | tr '\n' ' ')"
    dizer "Sem deploy nao ha o que testar."; cp "$TMP/saida.txt" "$SAIDA"; exit 1
  fi
fi

if [ ! -f infra/.url-api ]; then
  dizer "Nao ha API no ar (falta infra/.url-api). Rode ./infra/deploy.sh ou use --do-zero."
  exit 1
fi
URL=$(cat infra/.url-api)
get "/experimentos?projeto=verificacao"
if [ "$COD" != "200" ]; then
  dizer "A API em $URL nao respondeu (status $COD). O emulador esta no ar?"
  exit 1
fi

# Grafico de teste: PNG de 1x1, em arquivo, para comparar o tamanho
"$PY" -c "import base64,sys;open(sys.argv[1],'wb').write(base64.b64decode('$PNG_1X1'))" "$TMP/grafico.png"
TAMANHO_PNG=$(wc -c < "$TMP/grafico.png" | tr -d ' ')

P_INFLACAO="$RODADA-previsao-inflacao"
P_DUPLA="$RODADA-dupla"
P_CAMBIO="$RODADA-previsao-cambio"
P_DESEMPREGO="$RODADA-previsao-desemprego"
P_CAMPOS="$RODADA-campos"
P_RECUSA="$RODADA-recusa"
P_CARGA="$RODADA-carga"
P_FALHA="$RODADA-falha"

# ------------------------------------------------- US-01
dizer ""; dizer "== US-01: registrar uma rodada"
post "projeto=$P_INFLACAO"
conferir "US-01/1" "registro devolve 201" "$COD" "201"
ID1=$(campo id_experimento); URL_GRAFICO=$(campo grafico)
[ -n "$ID1" ] && passou "US-01/1" "devolve 1 identificador" || falhou "US-01/1" "devolve 1 identificador" "veio vazio"
conferir "US-01/1" "o valor volta sem arredondar" "$(campo valor)" "0.412"
conferir "US-01/1" "o projeto tem exatamente 1 experimento" "$(total "$P_INFLACAO")" "1"
conferir "US-01/1" "a lista traz 0.412 exato" "$(coluna valor)" "0.412"
COD_IMG=$(curl -s -m 30 -o "$TMP/baixado.png" -w "%{http_code}" "$URL_GRAFICO")
conferir "US-01/1" "o grafico abre pelo endereco devolvido, sem credencial" "$COD_IMG" "200"
conferir "US-01/1" "o grafico baixado tem o mesmo tamanho em bytes" \
  "$(wc -c < "$TMP/baixado.png" | tr -d ' ')" "$TAMANHO_PNG"

post "projeto=$P_INFLACAO" "valor=baixo"
conferir "US-01/2" "'baixo' e recusado com 400" "$COD" "400"
conferir "US-01/2" "a resposta aponta o campo valor" "$(campo campos)" "valor"
conferir "US-01/2" "a mensagem diz que precisa ser numerico" "$(campo erro)" "o valor da métrica precisa ser numérico"
conferir "US-01/2" "o projeto continua com exatamente 1" "$(total "$P_INFLACAO")" "1"
conferir "US-01/2" "0 graficos novos no bucket" "$(graficos_no_bucket "$P_INFLACAO")" "1"

# ------------------------------------------------- RF-01, RF-02, RF-04
dizer ""; dizer "== RF-01 e RF-04: identificador, data e recusas"
post "projeto=$P_CAMPOS"; A=$(campo id_experimento); DATA=$(campo criado_em)
post "projeto=$P_CAMPOS"; B=$(campo id_experimento)
[ -n "$A" ] && [ "$A" != "$B" ] && passou "RF-01" "cada registro gera um identificador novo" || falhou "RF-01" "cada registro gera um identificador novo" "'$A' e '$B'"
case "$DATA" in
  20[0-9][0-9]-[0-9][0-9]-[0-9][0-9]T*) passou "RF-01" "a data e hora e gerada em ISO 8601" ;;
  *) falhou "RF-01" "a data e hora e gerada em ISO 8601" "'$DATA'" ;;
esac
ANTES=$(total "$P_CAMPOS"); G_ANTES=$(graficos_no_bucket "$P_CAMPOS")
for C in projeto modelo metrica valor grafico; do
  if [ "$C" = "projeto" ]; then post "-$C"; else post "projeto=$P_CAMPOS" "-$C"; fi
  conferir "RF-04" "sem $C: 400 apontando o campo" "$COD $(campo campos)" "400 $C"
done
post "projeto=$P_CAMPOS" "modelo=   "
conferir "RF-04" "modelo so com espacos conta como ausente" "$COD $(campo campos)" "400 modelo"
for V in NaN Infinity "1.234,5" "1_000"; do
  post "projeto=$P_CAMPOS" "valor=$V"
  conferir "RF-04" "valor '$V' e recusado" "$COD" "400"
done
printf 'nao sou png' > "$TMP/falso.png"
post "projeto=$P_CAMPOS" "arq_grafico=$TMP/falso.png"
conferir "RF-04" "gráfico que nao e PNG e recusado" "$COD $(campo campos)" "400 grafico"
"$PY" -c "
import base64,sys
open(sys.argv[1],'wb').write(base64.b64decode('$PNG_1X1')+b'0'*(2*1024*1024))" "$TMP/grande.png"
post "projeto=$P_CAMPOS" "arq_grafico=$TMP/grande.png"
conferir "RF-04" "grafico acima de 2 MB e recusado" "$COD $(campo campos)" "400 grafico"
post "projeto=$P_CAMPOS" "grafico=@@@"
conferir "RF-04" "base64 invalido e recusado" "$COD $(campo campos)" "400 grafico"
post "projeto=../fora"
conferir "RF-04" "projeto com barra e recusado" "$COD $(campo campos)" "400 projeto"
COD=$(curl -s -m 60 -o "$TMP/corpo.json" -w "%{http_code}" -X POST "$URL/experimentos" \
  -H "Content-Type: application/json" -d '{nao e json')
conferir "RF-04" "corpo que nao e JSON e recusado" "$COD" "400"
conferir "RF-04" "nenhuma recusa gravou experimento" "$(total "$P_CAMPOS")" "$ANTES"
conferir "RF-04" "nenhuma recusa guardou grafico" "$(graficos_no_bucket "$P_CAMPOS")" "$G_ANTES"

for PAR in "0.412:0.412" "0,412:0.412" "-0,25:-0.25" "0:0"; do
  post "projeto=$P_CAMPOS" "valor=${PAR%%:*}"
  conferir "FURPS-U" "valor '${PAR%%:*}' vira ${PAR##*:}" "$COD $(campo valor)" "201 ${PAR##*:}"
done
post "projeto=$P_CAMPOS" "-hiperparametros"
conferir "RF-04" "hiperparametros sao opcionais" "$COD" "201"

# ------------------------------------------------- US-02
dizer ""; dizer "== US-02: lista do projeto"
for M in ARIMA SARIMA "Random Forest"; do post "projeto=$P_DUPLA" "modelo=$M"; done
post "projeto=$P_CAMBIO"; post "projeto=$P_CAMBIO"
get "/experimentos?projeto=$P_DUPLA"
conferir "US-02/1" "a lista traz exatamente 3" "$(campo total)" "3"
conferir "US-02/1" "na ordem Random Forest, SARIMA, ARIMA" "$(coluna modelo)" "Random Forest|SARIMA|ARIMA"
conferir "RF-03" "cada linha traz data, modelo, metrica, valor e identificador" \
  "$("$PY" -c "
import json,sys
e=json.load(open(sys.argv[1],encoding='utf-8'))['experimentos'][0]
print(sorted(e))" "$TMP/corpo.json")" "['criado_em', 'id_experimento', 'metrica', 'modelo', 'valor']"
IDS_DUPLA=$(coluna id_experimento)
get "/experimentos?projeto=$P_CAMBIO"
conferir "US-02/1" "o outro projeto tem os seus 2" "$(campo total)" "2"
MISTURADOS=0
for I in $(coluna id_experimento | tr '|' ' '); do
  case "$IDS_DUPLA" in *"$I"*) MISTURADOS=$((MISTURADOS+1)) ;; esac
done
conferir "US-02/1" "0 experimentos do outro projeto na lista" "$MISTURADOS" "0"
get "/experimentos?projeto=$P_DESEMPREGO"
conferir "US-02/2" "projeto sem experimentos: 200 com total 0" "$COD $(campo total)" "200 0"
conferir "US-02/2" "a lista vem vazia" "$(coluna modelo)" ""
get "/experimentos?projeto=$(echo "$P_DUPLA" | tr 'a-z' 'A-Z')"
conferir "02-arq s9" "maiusculas na busca chegam ao mesmo projeto" "$(campo total)" "3"
get "/experimentos"
conferir "RF-03" "consulta sem projeto: 400" "$COD $(campo campos)" "400 projeto"
get "/experimentos?projeto=$P_DUPLA&limite=abc"
conferir "RF-03" "limite que nao e numero: 400" "$COD" "400"
get "/experimentos?projeto=$P_DUPLA&limite=2"
conferir "RF-03" "limite=2 devolve os 2 mais recentes" "$(coluna modelo)" "Random Forest|SARIMA"

# ------------------------------------------------- US-03
dizer ""; dizer "== US-03: abrir um experimento"
HP="order=(1,1,1), seasonal_order=(0,1,1,12)"
post "projeto=$P_INFLACAO" "modelo=SARIMA" "hiperparametros=$HP" "valor=0,385"
ID_SARIMA=$(campo id_experimento)
get "/experimentos/$ID_SARIMA?projeto=$P_INFLACAO"
conferir "US-03/1" "exibe exatamente 1 experimento" "$COD $(campo total)" "200 1"
conferir "US-03/1" "hiperparametros identicos aos digitados" "$(campo experimento.hiperparametros)" "$HP"
conferir "US-03/1" "RMSE 0.385" "$(campo experimento.metrica) $(campo experimento.valor)" "RMSE 0.385"
G=$(campo experimento.grafico)
conferir "US-03/1" "o endereco do grafico abre" "$(curl -s -m 30 -o /dev/null -w "%{http_code}" "$G")" "200"
get "/experimentos/nao-existe?projeto=$P_INFLACAO"
conferir "US-03/2" "identificador inexistente: 404" "$COD" "404"
conferir "US-03/2" "exibe 0 experimentos" "$(campo total)" "0"
conferir "US-03/2" "nao mostra dados de nenhum existente" "$(campo experimento)" ""
conferir "US-03/2" "a mensagem diz nao encontrado no projeto" "$(campo erro)" "experimento não encontrado no projeto $P_INFLACAO"
get "/experimentos/$ID_SARIMA?projeto=$P_DUPLA"
conferir "US-03/2" "identificador de outro projeto: 404" "$COD" "404"

# ------------------------------------------------- RD-02
dizer ""; dizer "== RD-02: registrado nao se altera nem se apaga"
for M in PUT PATCH DELETE; do
  C=$(curl -s -m 30 -o /dev/null -w "%{http_code}" -X "$M" "$URL/experimentos/$ID_SARIMA?projeto=$P_INFLACAO")
  case "$C" in
    2*) falhou "RD-02" "a API nao oferece $M" "respondeu $C" ;;
    *) passou "RD-02" "a API nao oferece $M (respondeu $C)" ;;
  esac
done
get "/experimentos/$ID_SARIMA?projeto=$P_INFLACAO"
conferir "RD-02" "o experimento continua intacto" "$COD $(campo experimento.valor)" "200 0.385"
grep -q 'ConditionExpression="attribute_not_exists(id_experimento)"' app/gravar/handler.py \
  && passou "RD-02" "o put_item so grava se o identificador nao existir" \
  || falhou "RD-02" "o put_item so grava se o identificador nao existir"

# ------------------------------------------------- RF-05 e funcao direta
dizer ""; dizer "== Funcao gravar direto (README)"
$AWS lambda invoke --function-name "$FUNCAO_GRAVAR" \
  --payload fileb://eventos/gravar-valor-baixo.json "$TMP/corpo.json" >/dev/null 2>&1
conferir "US-01/2" "o evento de teste eventos/gravar-valor-baixo.json e recusado" "$(campo statusCode)" "400"
printf '{"body":"//4=","isBase64Encoded":true}' > "$TMP/evento.json"
$AWS lambda invoke --function-name "$FUNCAO_GRAVAR" \
  --payload "fileb://$TMP/evento.json" "$TMP/corpo.json" >/dev/null 2>&1
conferir "RF-04" "corpo em base64 que nao e UTF-8 da 400, nao 500" "$(campo statusCode)" "400"

# ------------------------------------------------- RNF-04
dizer ""; dizer "== RNF-04: recusa visivel no log em ate 10 s"
INICIO_MS="$(date +%s)000"
post "projeto=$P_RECUSA" "valor=baixo" "hiperparametros=NAO-DEVE-IR-PRO-LOG"
conferir "RNF-04" "a recusa de teste voltou 400" "$COD" "400"
T0=$(date +%s); ACHOU=""
while [ $(( $(date +%s) - T0 )) -le 10 ]; do
  ACHOU=$($AWS logs filter-log-events --log-group-name "/aws/lambda/$FUNCAO_GRAVAR" \
    --start-time "$INICIO_MS" --query "events[].message" --output text 2>/dev/null \
    | tr '\t' '\n' | grep "projeto=$P_RECUSA" | head -1)
  [ -n "$ACHOU" ] && break
  sleep 1
done
if [ -n "$ACHOU" ]; then
  passou "RNF-04" "a linha apareceu em $(( $(date +%s) - T0 )) s"
  case "$ACHOU" in
    recusado\ em=*projeto=*motivo=*) passou "RNF-04" "a linha tem data e hora, projeto e motivo" ;;
    *) falhou "RNF-04" "a linha tem data e hora, projeto e motivo" "$ACHOU" ;;
  esac
  case "$ACHOU" in
    *NAO-DEVE-IR-PRO-LOG*) falhou "RD-01" "o log nao guarda o conteudo enviado" ;;
    *) passou "RD-01" "o log nao guarda o conteudo enviado" ;;
  esac
else
  falhou "RNF-04" "a linha apareceu em ate 10 s" "nao apareceu"
fi

# ------------------------------------------------- RNF-02
dizer ""; dizer "== RNF-02: permissoes"
acoes() {
  $AWS iam get-role-policy --role-name "$1" --policy-name "$2" --query PolicyDocument --output json > "$TMP/politica.json" 2>/dev/null
  "$PY" - "$TMP/politica.json" "$3" <<'EOF'
import json, sys
doc = json.load(open(sys.argv[1], encoding="utf-8"))
if isinstance(doc, str):
    doc = json.loads(doc)
blocos = doc["Statement"]
if sys.argv[2] == "acoes":
    todas = []
    for b in blocos:
        todas += b["Action"] if isinstance(b["Action"], list) else [b["Action"]]
    print(" ".join(sorted(todas)))
else:
    print(" ".join(str(b["Resource"]) for b in blocos))
EOF
}
POL_G="${PREFIXO}-politica-gravar"; POL_C="${PREFIXO}-politica-consultar"
conferir "RNF-02" "gravar pode so: guardar grafico, inserir e registrar" \
  "$(acoes "$PAPEL_GRAVAR" "$POL_G" acoes)" \
  "dynamodb:PutItem logs:CreateLogGroup logs:CreateLogStream logs:PutLogEvents s3:PutObject"
conferir "RNF-02" "consultar pode so: ler a tabela e registrar" \
  "$(acoes "$PAPEL_CONSULTAR" "$POL_C" acoes)" \
  "dynamodb:GetItem dynamodb:Query logs:CreateLogGroup logs:CreateLogStream logs:PutLogEvents"
for PAR in "$PAPEL_GRAVAR:$POL_G" "$PAPEL_CONSULTAR:$POL_C"; do
  R=$(acoes "${PAR%%:*}" "${PAR##*:}" recursos)
  case " $R " in
    *" * "*) falhou "RNF-02" "${PAR%%:*} nomeia os recursos, sem '*' solto" "$R" ;;
    *) passou "RNF-02" "${PAR%%:*} nomeia os recursos, sem '*' solto" ;;
  esac
done
PAPEIS=$($AWS lambda list-functions --query "Functions[?starts_with(FunctionName, '${PREFIXO}-')].Role" --output text | tr '\t' '\n' | sort -u | wc -l | tr -d ' ')
conferir "RNF-02" "cada funcao tem o seu papel" "$PAPEIS" "2"
dizer "  AVISO   [RNF-02] confere a politica anexada, como o requisito pede; o emulador nao a aplica por padrao"

# ------------------------------------------------- RNF-03
dizer ""; dizer "== RNF-03: nenhum experimento sem grafico"
BUCKET_ORIGINAL_RESTAURAR=1
$AWS lambda update-function-configuration --function-name "$FUNCAO_GRAVAR" \
  --environment "$(variaveis_gravar "${BUCKET}-fora-do-ar")" >/dev/null 2>&1
$AWS lambda wait function-updated --function-name "$FUNCAO_GRAVAR" >/dev/null 2>&1
post "projeto=$P_FALHA"
conferir "RNF-03" "com o bucket fora do ar, a gravacao responde 503" "$COD" "503"
restaurar_bucket
conferir "RNF-03" "e nenhum experimento fica registrado" "$(total "$P_FALHA")" "0"
post "projeto=$P_FALHA"
conferir "RNF-03" "com o bucket de volta, a gravacao funciona" "$COD" "201"

# Todo item dos projetos de teste tem o seu arquivo no bucket
SEM_GRAFICO=0
for PROJ in "$P_INFLACAO" "$P_DUPLA" "$P_CAMBIO" "$P_CAMPOS" "$P_FALHA"; do
  $AWS s3 ls "s3://$BUCKET/graficos/$PROJ/" --recursive 2>/dev/null > "$TMP/bucket.txt"
  get "/experimentos?projeto=$PROJ"
  for I in $(coluna id_experimento | tr '|' ' '); do
    grep -q "$I.png" "$TMP/bucket.txt" || SEM_GRAFICO=$((SEM_GRAFICO+1))
  done
done
conferir "RNF-03" "0 experimentos sem grafico no bucket" "$SEM_GRAFICO" "0"

# ------------------------------------------------- RNF-01
dizer ""; dizer "== RNF-01: lista com 100 experimentos, 30 requisicoes (grava 100 rodadas: pode levar alguns minutos)"
for N in $(seq 1 100); do
  post "projeto=$P_CARGA" "modelo=m$N" "hiperparametros=rodada $N"
  [ "$COD" = "201" ] || falhou "RNF-01" "semear a rodada $N" "status $COD"
done
get "/experimentos?projeto=$P_CARGA"
conferir "RNF-01" "o projeto de carga tem 100 experimentos" "$(campo total)" "100"
case "$(campo trilha.1.acao)" in
  query*) passou "RNF-01" "a lista e um query na particao, sem scan" ;;
  *) falhou "RNF-01" "a lista e um query na particao, sem scan" "$(campo trilha.1.acao)" ;;
esac
: > "$TMP/tempos.txt"
for N in $(seq 1 30); do
  curl -s -m 60 -o /dev/null -w "%{time_total}\n" "$URL/experimentos?projeto=$P_CARGA" >> "$TMP/tempos.txt"
done
RESUMO=$("$PY" - "$TMP/tempos.txt" <<'EOF'
import math, sys
t = sorted(float(l.replace(",", ".")) * 1000 for l in open(sys.argv[1]) if l.strip())
p95 = t[math.ceil(len(t) * .95) - 1]
print(f"{p95:.0f} {t[len(t)//2]:.0f} {t[-1]:.0f} {len(t)}")
EOF
)
read -r P95 MEDIANA MAXIMO QTD <<< "$RESUMO"
conferir "RNF-01" "foram 30 medicoes" "$QTD" "30"
if [ "$P95" -lt 1000 ]; then
  passou "RNF-01" "p95 de ${P95} ms, abaixo de 1.000 ms (mediana ${MEDIANA} ms, maximo ${MAXIMO} ms)"
else
  falhou "RNF-01" "p95 abaixo de 1.000 ms" "p95 ${P95} ms, mediana ${MEDIANA} ms, maximo ${MAXIMO} ms"
fi

# ------------------------------------------------- pagina
dizer ""; dizer "== Pagina publicada (US-01, US-02, US-03, RD-01)"
ALT="${ENDPOINT}/${BUCKET_SITE}/index.html"
COD=$(curl -s -m 30 -o "$TMP/pagina.html" -w "%{http_code}" "$ALT")
conferir "US-02" "a pagina responde no endereco alternativo" "$COD" "200"
tem() { grep -q "$2" "$TMP/pagina.html" && passou "$1" "$3" || falhou "$1" "$3"; }
tem "RD-01" "Só resultados agregados" "o formulario traz o aviso de resultados agregados"
tem "US-02/2" "ainda não tem experimentos" "a pagina traz a mensagem de projeto vazio"
tem "US-02/2" "Registrar o primeiro" "a pagina traz o convite para registrar o primeiro"
COD=$(curl -s -m 30 -o "$TMP/config.js" -w "%{http_code}" "${ENDPOINT}/${BUCKET_SITE}/config.js")
conferir "02-arq 2.1" "o config.js esta publicado" "$COD" "200"
grep -q "$URL" "$TMP/config.js" && passou "02-arq 2.1" "o config.js aponta para a API no ar" \
  || falhou "02-arq 2.1" "o config.js aponta para a API no ar" "$(cat "$TMP/config.js")"
grep -qiE 'secret|access.?key|password|senha' "$TMP/config.js" \
  && falhou "02-arq 2.1" "o config.js nao tem credencial" \
  || passou "02-arq 2.1" "o config.js nao tem credencial"
SITE="http://${BUCKET_SITE}.s3-website.localhost.localstack.cloud:4566/"
COD=$(curl -s -m 15 -o /dev/null -w "%{http_code}" "$SITE")
case "$COD" in
  200) passou "US-02" "a pagina responde no endereco de site estatico" ;;
  000) pulou "US-02" "endereco de site estatico" "esta rede nao resolve o nome; use o alternativo" ;;
  *) falhou "US-02" "a pagina responde no endereco de site estatico" "status $COD" ;;
esac
curl -s -m 30 -D "$TMP/cab.txt" -o /dev/null -X OPTIONS "$URL/experimentos" \
  -H "Origin: http://exemplo" -H "Access-Control-Request-Method: POST" \
  -H "Access-Control-Request-Headers: content-type"
grep -qi '^access-control-allow-origin:' "$TMP/cab.txt" \
  && passou "02-arq s9" "a verificacao previa (OPTIONS) devolve os cabecalhos de CORS" \
  || falhou "02-arq s9" "a verificacao previa (OPTIONS) devolve os cabecalhos de CORS"
grep -qi '^access-control-allow-headers:.*content-type' "$TMP/cab.txt" \
  && passou "02-arq s9" "o OPTIONS libera o cabecalho Content-Type" \
  || falhou "02-arq s9" "o OPTIONS libera o cabecalho Content-Type"

# ------------------------------------------------- deploy de novo
if [ "$MODO_ZERO" = "1" ]; then
  dizer ""; dizer "== Rodar o deploy de novo nao perde nada"
  ANTES=$(total "$P_DUPLA")
  if ./infra/deploy.sh > "$TMP/deploy2.txt" 2>&1; then
    passou "DEMO" "o segundo deploy termina sem erro"
  else
    falhou "DEMO" "o segundo deploy termina sem erro" "$(tail -3 "$TMP/deploy2.txt" | tr '\n' ' ')"
  fi
  URL=$(cat infra/.url-api)
  conferir "DEMO" "os experimentos continuam la" "$(total "$P_DUPLA")" "$ANTES"
  conferir "DEMO" "o RNF-03 nao deixou o bucket trocado na funcao" \
    "$($AWS lambda get-function-configuration --function-name "$FUNCAO_GRAVAR" --query "Environment.Variables.BUCKET" --output text)" "$BUCKET"
fi

# ------------------------------------------------- resumo
dizer ""
dizer "============================================"
dizer "Rodada $RODADA em $(date '+%d/%m/%Y %H:%M:%S')"
dizer "Ambiente: $(curl -s -m 5 "${ENDPOINT}/_localstack/health" | "$PY" -c "
import json,sys
try:
    d=json.load(sys.stdin); print(d.get('edition','?'),d.get('version','?'))
except Exception:
    print('desconhecido')")"
dizer "Passaram: $PASSOU | Falharam: $FALHOU | Pulados: $PULOU"
dizer "============================================"
cp "$TMP/saida.txt" "$SAIDA"
[ "$FALHOU" = "0" ]
