# Próximos passos para a entrega

Estado em 05/11/2026: as cinco sprints estão no repositório e o projeto roda inteiro no LocalStack. A suíte `./testes/executar.sh --do-zero` passou em 95 de 96 verificações; a única falha é o p95 do RNF-01 na rodada completa, explicada em `docs/03-validacao.md`, seção 3.1. Em um MacBook, a mesma suíte passou em 96 de 96. Falta o que só a equipe pode fazer: os prints, a homologação cruzada e os commits de cada integrante.

Apague este arquivo quando tudo abaixo estiver feito.

## 0. Antes de qualquer comando

No **Git Bash** (no Mac ou Linux, o Terminal), na pasta do projeto:

```bash
lstk start
source infra/config.sh
./infra/deploy.sh          # se o ambiente não estiver no ar
```

- O Docker Desktop precisa estar aberto antes do `lstk start`.
- Se `lstk` não for encontrado, ponha a pasta dele no PATH da sessão. Exemplo no Windows: `export PATH="$PATH:/c/Users/<usuario>/Downloads/lstk_1.0.1_windows_amd64"`.
- O LocalStack valida a licença pela internet (`api.localstack.cloud`). Se ele disser "License activation failed", a rede está bloqueando: troque de rede, por exemplo para o 4G do celular.
- Para a página ter exemplos e os PNGs da demonstração: `pip install -r dados/requisitos.txt` e `python dados/semear.py`. No Mac, ative antes o ambiente virtual: `python3 -m venv .venv` (só na primeira vez) e `source .venv/bin/activate`.
- **No Mac, abra o bash antes das capturas:** rode `bash -l` no Terminal. No zsh, o padrão do Mac, o `time` não imprime a linha `real` que a E4.3 e a E5.3 pedem. O prompt do `bash -l` continua mostrando o computador e o usuário.

## 1. Prints nos documentos de evidência

Os três documentos da professora estão em `docs/evidencias/`: `evidencias-sprint3.docx` (E3.1 a E3.4), `evidencias-sprint4.docx` (E4.1 a E4.4) e `evidencias-sprint5.docx` (E5.1 a E5.5). Cada um diz os comandos de cada captura.

Regras de toda captura, que a professora confere:

1. a janela inteira do terminal, sem recorte, com o prompt mostrando usuário e nome do computador;
2. o primeiro comando é `date`;
3. os recursos aparecem com o prefixo da equipe, `diario`;
4. captura de tela, não foto do celular, e sem editar;
5. um registro gravado com o nome de quem rodou, em um campo de texto.

Embaixo de cada captura, escreva quem rodou, e preencha a tabela de conferência do fim de cada documento.

Ajustes para o nosso projeto:

- **E3.2:** no `eventos/gravar-ok.json`, troque `\"modelo\": \"ARIMA\"` por `\"modelo\": \"ARIMA - <seu nome>\"`. Depois das capturas, volte o arquivo com `git checkout eventos/gravar-ok.json`.
- **E4.1:** use os três `curl` da seção "Como testar pela API" do `README.md`, com o seu nome no campo `modelo` do POST.
- **E4.2:** grave pela página pelo menos um registro com o seu nome no modelo, e deixe a tabela com dois ou mais registros.
- **E5.1 e E5.3:** a suíte leva de 6 a 8 minutos. Pode aparecer **1 FALHOU** no RNF-01. É o resultado real, explicado no relatório: não esconda.
- **E5.2:** `./testes/medir.sh`.

Valores de conferência que já se sabem, e já preenchidos nos documentos: prefixo `diario`; tabela `diario-experimentos`; chave de partição `projeto`; endereço do site `http://diario-site.s3-website.localhost.localstack.cloud:4566/`. Os outros, como identificadores, tempos e p95, saem da execução de quem rodar.

### Sequência pronta para copiar

Os `.docx` são binários: se duas pessoas editarem o mesmo arquivo, o Git não junta as alterações. Rode `git pull` antes de começar e deixe cada documento com uma pessoa por vez.

**Preparo, uma vez em cada terminal, fora dos prints.** No Mac, rode `bash -l` antes. Troque `Seu Nome` pelo seu nome.

```bash
source infra/config.sh
export AWS_PAGER=""
NOME="Seu Nome"
```

Rode `clear` antes de cada captura, para o `date` ser o primeiro comando da tela. Tire o print quando o último comando terminar.

**Sprint 3**, antes da E3.2, coloque o nome no evento, fora do print:

```bash
sed -i.bak "s/ARIMA\\\\/ARIMA - $NOME\\\\/" eventos/gravar-ok.json && rm eventos/gravar-ok.json.bak
```

E3.1:

```bash
date
echo "$PREFIXO"
git --no-pager log -5 --format="%h %an %ad %s" --date=short
```

E3.2, com a tabela ainda vazia ou quase, para o registro caber na tela. Se ela estiver cheia, rode antes `./infra/destroy.sh` e `./infra/deploy.sh`, fora do print:

```bash
date
lstk aws lambda invoke --function-name "$FUNCAO_GRAVAR" --payload fileb://eventos/gravar-ok.json saida.json
cat saida.json
lstk aws dynamodb scan --table-name "$TABELA"
```

E3.3:

```bash
date
./infra/destroy.sh
./infra/deploy.sh
```

Espere o prompt voltar, sem limpar a tela, e só então cole o resto. No Terminal do Mac, a linha colada junto com o `deploy.sh` foi perdida e o comando não rodou:

```bash
lstk aws lambda invoke --function-name "$FUNCAO_GRAVAR" --payload fileb://eventos/gravar-ok.json saida.json
cat saida.json
```

Depois da E3.3, volte o evento, fora do print: `git checkout eventos/gravar-ok.json`.

E3.4:

```bash
date
lstk aws s3 ls
lstk aws dynamodb list-tables
lstk aws lambda list-functions --query "Functions[].FunctionName"
```

**Sprint 4**, E4.1:

```bash
date
URL=$(cat infra/.url-api)
echo "$URL"
curl -s -X POST "$URL/experimentos" -H "Content-Type: application/json" -d '{"projeto":"previsao-inflacao","modelo":"ARIMA - '"$NOME"'","hiperparametros":"order=(1,1,1)","metrica":"RMSE","valor":"0,412","grafico":"iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=="}'
echo
curl -s "$URL/experimentos?projeto=previsao-inflacao"
echo
curl -s -o /dev/null -w "%{http_code}\n" "$URL/experimentos"
```

A resposta do POST traz o identificador da tabela de conferência.

E4.2, no Chrome, antes da E4.3, porque o `destroy` apaga os registros:

1. Abra `http://diario-site.s3-website.localhost.localstack.cloud:4566/`.
2. Em **Registrar rodada**, preencha projeto `previsao-inflacao`, modelo `Random Forest - <seu nome>`, métrica `RMSE` e valor `0,350`. Anexe `dados/graficos/demo/AO-VIVO-random-forest.png`; se o arquivo não existir, gere com `python dados/semear.py --so-graficos`.
3. Clique em **Registrar rodada**, depois em **Ver na lista do projeto**.
4. Confira se a tabela tem pelo menos dois registros e tire o print da janela inteira, com a barra de endereço.

E4.3:

```bash
date
./infra/destroy.sh
time ./infra/deploy.sh
```

E4.4:

```bash
date
lstk aws lambda list-functions --query "Functions[].FunctionName"
lstk aws apigateway get-rest-apis --query "items[].[name,id]"
lstk aws s3 ls
```

**Sprint 5**, E5.2:

```bash
date
./testes/medir.sh
```

E5.1 e E5.3 passam de 100 linhas: maximize a janela e reduza a fonte até caber tudo, ou tire mais de um print em sequência, sem limpar a tela.

E5.1:

```bash
date
./testes/executar.sh
```

E5.3:

```bash
date
./infra/destroy.sh
time ./infra/deploy.sh
```

Espere o prompt voltar, sem limpar a tela, e só então rode `./testes/executar.sh`.

E5.5, por último, depois de `git pull` e dos commits de todos:

```bash
date
git --no-pager shortlog -sn HEAD
```

## 2. Homologação cruzada (E5.4)

Obrigatória na Sprint 5:

- **A outra equipe roda o nosso projeto** seguindo só o `README.md` e responde: conseguiu rodar só com o README? O que faltava? Os testes passaram? Alguma linha da matriz não bateu? Em que ponto travou?
- **A nossa equipe roda o projeto dela** no nosso computador (comandos na E5.4) e responde as mesmas perguntas.

Com as respostas, preencha no `docs/03-validacao.md` as seções **5. Homologação recebida** (com 5.1, o que foi corrigido depois) e **6. Homologação realizada**. Os quadros já estão lá, com `[preencher]` em cada campo; confira o formato com o Template 3, que não está no repositório. Nenhum `[preencher]` pode ficar na entrega.

## 3. Commits de cada integrante (E5.5)

A E5.5 mostra os commits por pessoa (`git --no-pager shortlog -sn HEAD`). Hoje a Melina e o Davi não têm nenhum. Cada um pode fazer o commit do documento de evidências em que colou os próprios prints.

```bash
git add docs/evidencias/evidencias-sprint4.docx
git commit -m "evidencias da sprint 4"
git push origin main
```

## 4. Antes do Demoday (11–12/11)

- Ensaiar o `docs/roteiro-demo.md` a partir do ambiente derrubado: `./infra/destroy.sh`, depois o roteiro.
- Rodar uma vez `./testes/executar.sh --do-zero` no computador da apresentação e confirmar que a rede deixa o LocalStack validar a licença.
- O relatório final é o `docs/03-validacao.md`, entregue no mesmo dia. Antes de entregar, atualize o número de commits na seção 9 com `git rev-list --count HEAD`.
