# Roteiro da demonstração

Cerca de 11 minutos, dentro dos 12 do Demoday, que pede a demonstração **a partir do ambiente derrubado**: o deploy roda na frente da banca. A ideia central para repetir: **cada clique na página percorre a nuvem, e o painel da direita mostra o caminho.**

## Antes de apresentar (30 minutos antes)

Tudo no **Git Bash**, na pasta do projeto. Aqui nada da aplicação fica no ar: o que se prepara é o terreno.

1. Abra o Docker Desktop e espere ele ficar pronto.
2. Suba o LocalStack: `lstk start`
3. Na primeira vez em cada computador, instale as bibliotecas do gerador de exemplos: `pip install -r dados/requisitos.txt`. No Mac, antes, crie e ative o ambiente virtual (`python3 -m venv .venv` e `source .venv/bin/activate`); a ativação vale para cada terminal novo.
4. Ensaie uma vez, para descobrir problema enquanto dá tempo: `./testes/executar.sh --do-zero`
5. Derrube tudo: `./infra/destroy.sh`
6. Prepare os arquivos da rodada ao vivo, sem registrar nada: `python dados/semear.py --so-graficos`. Abra `dados/graficos/demo/LEIA-ME-demo.txt`: ele tem os valores que você vai digitar.
7. Deixe o terminal aberto na pasta do projeto, já com `source infra/config.sh` rodado, para o passo 8.

Confira o rodapé dos gráficos gerados. Se disser "Fonte: Banco Central", são dados reais; se disser "série ilustrativa (Banco Central indisponível)", o script não conseguiu falar com o Banco Central, e a série foi gerada. Fale de acordo com o que estiver escrito.

---

## 1. Subir tudo do zero (2 min 30 s) · ambiente derrubado

**Faça:** rode `./infra/deploy.sh`. Quando terminar, rode `python dados/semear.py` e abra a página no endereço que o deploy imprimiu no final.

**Diga, enquanto roda:** "O ambiente está derrubado: não existe bucket, tabela nem função. Todo recurso nasce deste script versionado, nessa ordem: bucket, tabela, papéis, funções, API e página. Nada foi criado clicando em painel. Quando ele terminar, um segundo script faz o papel de quem treina: roda modelos simples fora do sistema e registra cada rodada pela nossa API."

Se a página mostrar "API conectada no LocalStack" no canto, está tudo certo.

## 2. Apresentar a tela (30 s)

**Faça:** mostre a página sem clicar em nada.

**Diga:** "Este é o Diário de Experimentos. Quem treina um modelo registra aqui cada rodada: o modelo, os hiperparâmetros, a métrica e o gráfico. À direita está o mapa da nossa arquitetura na AWS. A cada ação, ele acende o caminho que a requisição fez."

## 3. Ver a lista do projeto (1 min) · RF-03, US-02

**Faça:** clique em **Experimentos do projeto** e depois no atalho **previsao-inflacao**.

**O que acende:** Navegador → API Gateway → Lambda consultar → DynamoDB → CloudWatch.

**Diga:** "A página chama a API Gateway, que é a porta de entrada. Ela encaminha para a Lambda de consulta, que faz um *query* no DynamoDB só na partição desse projeto. O próprio banco já devolve do mais recente para o mais antigo, porque o identificador começa pela data e hora. Não existe *scan* da tabela inteira, e por isso a lista continua rápida mesmo com outros projetos crescendo (RNF-01)."

**Mostre:** o tempo em milissegundos no painel.

## 4. Registrar com erro (1 min) · RF-04

**Faça:** vá em **Registrar rodada** e preencha com os dados do `LEIA-ME-demo.txt`, **mas digite `baixo` no valor**. Anexe o arquivo `AO-VIVO-...png` e clique em **Registrar rodada**.

**O que acende:** a Lambda gravar fica vermelha. **S3 e DynamoDB ficam tracejados**, ou seja, não foram tocados. O CloudWatch acende.

**Diga:** "A validação fica na Lambda, não na página, porque qualquer um poderia pular a página e chamar a API direto. Ela recusou antes de gravar qualquer coisa: nenhum gráfico foi para o S3, nenhum item foi para o DynamoDB. E a recusa ficou anotada no CloudWatch, com projeto e motivo, para quem mantém o sistema investigar depois (RNF-04)."

## 5. Registrar certo (1 min) · RF-01, RF-02, RNF-03

**Faça:** troque `baixo` pelo valor do LEIA-ME, com vírgula, e registre de novo.

**O que acende:** Lambda gravar → **1º S3** → **2º DynamoDB** → CloudWatch.

**Diga:** "Agora passou. A ordem importa: primeiro o gráfico vai para o S3 e só depois o experimento vai para o DynamoDB. Assim nunca existe um experimento sem gráfico (RNF-03). Repare também que digitei com vírgula: a função aceita vírgula ou ponto e guarda o número exato, sem arredondar."

**Mostre:** o identificador gerado na caixa verde.

## 6. Conferir na lista (30 s)

**Faça:** clique em **Ver na lista do projeto**.

**Diga:** "A rodada nova aparece no topo, destacada. Não precisei ordenar nada no código: foi a chave de ordenação do DynamoDB."

Se perguntarem por que o `0,350` digitado aparece como `0,35`: o DynamoDB guarda o valor como número, e zero à direita não muda o número. Nada foi arredondado.

## 7. Abrir o experimento (1 min) · RF-05, US-03

**Faça:** clique no identificador da linha destacada.

**O que acende:** Lambda consultar → DynamoDB (*get_item*). No final, o **S3 acende sozinho**: é o navegador buscando a imagem.

**Diga:** "Isso é o que a pessoa usa semanas depois para reproduzir a melhor configuração: os hiperparâmetros exatamente como foram digitados e o gráfico. A imagem é a única coisa que o navegador busca direto no S3, só para leitura e sem credencial. Todo o resto passa pela API."

**Extra (15 s):** troque uma letra do identificador e clique em **Abrir experimento**. Aparece o 404 "experimento não encontrado" (US-03, cenário 2).

## 8. Mostrar a nuvem pelo terminal (1 min 30 s)

**Faça e diga, um comando de cada vez:**

```bash
$AWS lambda list-functions --query "Functions[].[FunctionName, Role]" --output table
```
"Estas são as duas funções, cada uma com o seu próprio papel no IAM."

```bash
$AWS logs tail /aws/lambda/diario-gravar --since 15m --format short
```
"Aqui está a recusa do 'baixo' que fiz agora há pouco, no CloudWatch, com o projeto e o motivo."

```bash
$AWS iam get-role-policy --role-name diario-papel-consultar --policy-name diario-politica-consultar --query PolicyDocument
```
"O papel da consulta só pode ler a tabela. Nenhuma das duas funções tem ação de apagar ou de atualizar, então um defeito no código não consegue apagar nem editar um experimento (RNF-02). Sobrescrever é outra camada: o IAM não distingue inserir de substituir, e por isso a gravação é condicional, só grava se o identificador ainda não existir (RD-02)."

Se perguntarem: o emulador guarda e mostra a política, mas por padrão não a aplica. O teste automático confere o conteúdo dela, que é o que o RNF-02 pede.

---

## Sobre o modelo de machine learning (se perguntarem)

Fale pouco e de forma honesta:

"O treino não acontece no sistema; isso ficou fora do escopo de propósito. Para a demonstração, um script em Python treinou modelos simples de previsão, como média móvel e regressão, e registrou o resultado de cada rodada pela nossa API, do mesmo jeito que a página faz. A métrica é o RMSE, que mede o erro médio da previsão: quanto menor, melhor. O foco do projeto é a arquitetura na nuvem que guarda e organiza esses resultados."

Também está na própria página, em **De onde vêm esses números**, embaixo do formulário.

## Se algo der errado na hora

**A página não abre.** Use o endereço alternativo que o deploy imprime: `http://localhost:4566/diario-site/index.html`.

**Aparece "API fora do ar".** Rode `./infra/deploy.sh` e, se a lista ficou vazia, `python dados/semear.py`. Leva uns 2 minutos. Rodar o `semear.py` duas vezes registra as rodadas duas vezes, porque nada é sobrescrito.

**Uma ação demorou muito.** Foi a primeira execução da Lambda. A segunda é rápida. Aproveite e diga: "isso é a partida a frio da Lambda, que é real na AWS também".
