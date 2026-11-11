# Documento de Validação

Projeto: Diário de Experimentos (`diario-de-experimentos`)  
Cenário oficial escolhido: Ideia própria da equipe (Diário de Experimentos)  
Data: 05/11/2026  
Versão: 1.0

Os números deste documento vêm de execuções reais no LocalStack (edição `bigdata-pro`, versão 2026.10.0), em um notebook Windows 11 pelo Git Bash, em 05/11/2026. As saídas completas estão em `docs/evidencias/`: `executar-do-zero-2026-11-05.txt`, a suíte inteira a partir do ambiente derrubado, e `medir-2026-11-05.txt`, as medições do RNF-01. A mesma suíte foi repetida no mesmo dia em um MacBook (Apple A18 Pro, 8 GB, macOS 27.0.1, LocalStack `pro` 2026.10.6), com as saídas em `executar-do-zero-mac-2026-11-05.txt` e `medir-mac-2026-11-05.txt`; as diferenças estão nas seções 1 e 3.1. As capturas de tela de cada sprint estão nos documentos de evidência da mesma pasta (E3.1 a E5.5; a E5.4, da homologação cruzada, não se aplica, porque a professora a dispensou).

## 1. Reconstrução do ambiente

| Item | Resposta |
|------|----------|
| Tempo do `deploy.sh` a partir do ambiente vazio | 110 s e 119 s, em duas reconstruções do zero no notebook Windows, e 19 s e 18,8 s no MacBook (`[DEMO] deploy.sh sobe tudo do zero` e E5.3) |
| Foi necessário algum comando fora do script | Não. Antes do deploy, só se sobe o emulador (`lstk start`), que não cria nenhum recurso do projeto |
| Se sim, qual e por quê | Não se aplica: nenhum recurso foi criado fora de `infra/` |

O ciclo foi o do Demoday: `destroy.sh` deixou 0 funções e 0 tabelas do projeto, o `deploy.sh` subiu bucket, tabela, papéis, funções, API e página com um comando, e um segundo `deploy.sh`, logo depois, terminou sem erro e sem perder nenhum experimento gravado. O `deploy.sh` termina aquecendo as duas funções, para a primeira pessoa na página não esperar a partida a frio.

## 2. Critérios de aceite executados

O `testes/executar.sh` traduz os seis critérios da Sprint 1 (`01-requisitos.md`, seção 5). Cada verificação leva o ID do que confere, e cada critério precisa de mais de uma, porque a frase afirma mais de uma coisa. Cada rodada usa projetos com sufixo único: como nada se apaga (RD-02), é assim que "projeto vazio" continua verdadeiro a cada execução.

| #  | Cenário BDD, em uma linha | Como foi executado | Resultado |
|----|---------------------------|--------------------|-----------|
| C1 | US-01, cenário 1: registrar um ARIMA com RMSE 0,412 e gráfico devolve 1 identificador, o projeto passa a ter 1 experimento, 0,412 sem arredondar e o gráfico baixado tem o mesmo tamanho | `executar.sh`, 7 verificações `[US-01/1]` | passou |
| C2 | US-01, cenário 2: "baixo" no valor é recusado, o projeto continua com 1 e 0 gráficos novos são guardados | `executar.sh`, 6 verificações `[US-01/2]` | passou |
| C3 | US-02, cenário 1: a lista traz exatamente 3, na ordem Random Forest, SARIMA, ARIMA, e 0 do outro projeto | `executar.sh`, 4 verificações `[US-02/1]` | passou |
| C4 | US-02, cenário 2: projeto sem experimentos responde com 0 e, no lugar da tabela, a mensagem e o convite | `executar.sh`, 4 verificações `[US-02/2]`, duas na API e duas na página publicada | passou |
| C5 | US-03, cenário 1: abrir pelo identificador exibe 1 experimento, com hiperparâmetros idênticos, RMSE 0,385 e o endereço do gráfico | `executar.sh`, 4 verificações `[US-03/1]` | passou |
| C6 | US-03, cenário 2: identificador que não pertence ao projeto responde não encontrado, com 0 experimentos e nenhum dado dos existentes | `executar.sh`, 5 verificações `[US-03/2]` | passou |

### 2.1 Saída do script

Os blocos dos seis critérios e a linha final; a saída inteira, com as 96 verificações, está em `docs/evidencias/executar-do-zero-2026-11-05.txt`.

```text
== US-01: registrar uma rodada
  OK      [US-01/1] registro devolve 201
  OK      [US-01/1] devolve 1 identificador
  OK      [US-01/1] o valor volta sem arredondar
  OK      [US-01/1] o projeto tem exatamente 1 experimento
  OK      [US-01/1] a lista traz 0.412 exato
  OK      [US-01/1] o grafico abre pelo endereco devolvido, sem credencial
  OK      [US-01/1] o grafico baixado tem o mesmo tamanho em bytes
  OK      [US-01/2] 'baixo' e recusado com 400
  OK      [US-01/2] a resposta aponta o campo valor
  OK      [US-01/2] a mensagem diz que precisa ser numerico
  OK      [US-01/2] o projeto continua com exatamente 1
  OK      [US-01/2] 0 graficos novos no bucket

== US-02: lista do projeto
  OK      [US-02/1] a lista traz exatamente 3
  OK      [US-02/1] na ordem Random Forest, SARIMA, ARIMA
  OK      [US-02/1] o outro projeto tem os seus 2
  OK      [US-02/1] 0 experimentos do outro projeto na lista
  OK      [US-02/2] projeto sem experimentos: 200 com total 0
  OK      [US-02/2] a lista vem vazia

== US-03: abrir um experimento
  OK      [US-03/1] exibe exatamente 1 experimento
  OK      [US-03/1] hiperparametros identicos aos digitados
  OK      [US-03/1] RMSE 0.385
  OK      [US-03/1] o endereco do grafico abre
  OK      [US-03/2] identificador inexistente: 404
  OK      [US-03/2] exibe 0 experimentos
  OK      [US-03/2] nao mostra dados de nenhum existente
  OK      [US-03/2] a mensagem diz nao encontrado no projeto
  OK      [US-03/2] identificador de outro projeto: 404

== Pagina publicada (US-01, US-02, US-03, RD-01)
  OK      [US-02/2] a pagina traz a mensagem de projeto vazio
  OK      [US-02/2] a pagina traz o convite para registrar o primeiro

============================================
Rodada t20261105-101527-13228 em 05/11/2026 10:23:49
Ambiente: bigdata-pro 2026.10.0
passaram: 95   falharam: 1   pulados: 0
============================================
```

A única falha da rodada é a medição do RNF-01, explicada na seção 3. Na rodada do MacBook, as 96 verificações passaram: `passaram: 96   falharam: 0   pulados: 0`. Sem `--do-zero`, como nas capturas E5.1 e E5.3, a suíte não roda as 6 verificações `[DEMO]` do ciclo de reconstrução: são 90, e as 90 passaram.

### 2.2 Cenários não verificáveis por script

Uma parte do C4 diz que a mensagem aparece **no lugar da tabela**. O script confere que a API responde 200 com total 0 e que a página publicada contém a mensagem e o convite, mas não renderiza a tela. Ver a mensagem no lugar da tabela é demonstração: está no roteiro da apresentação (`docs/roteiro-demo.md`, passo 3) e na captura da página (E4.2).

O RD-01 diz que o gráfico não pode conter dado pessoal. Nenhum script sabe o que uma imagem mostra. O que é verificável foi verificado — o aviso está no formulário publicado (`[RD-01]`) e o log não guarda o conteúdo enviado (`[RD-01]`) —, e o resto é responsabilidade de quem anexa, declarada aqui como verificação humana.

## 3. Requisitos não funcionais medidos

| ID     | Valor declarado na Sprint 2 | Método | Valor obtido | Resultado |
|--------|-----------------------------|--------|--------------|-----------|
| RNF-01 | p95 < 1.000 ms, com 100 experimentos no projeto e 30 requisições seguidas | medição (`testes/medir.sh`) | p95 de 335 ms e 286 ms nas medições sozinhas, e 289 ms em uma sondagem de 60 chamadas; 2.854 ms e 1.839 ms nas medições feitas dentro da suíte completa, todos no notebook Windows. No MacBook: 146 ms, 46 ms, 47 ms e 49 ms (E5.2) sozinhas, e 61 ms, 61 ms (E5.1) e 37 ms (E5.3) dentro da suíte | cumprido em parte |
| RNF-02 | 0 permissões de exclusão ou atualização, 0 de escrita na consulta, só recursos do projeto | inspeção das políticas (`iam get-role-policy`, `[RNF-02]`) | gravação: `s3:PutObject`, `dynamodb:PutItem` e registro; consulta: `dynamodb:Query`, `dynamodb:GetItem` e registro; 0 `Delete*` ou `Update*`; todo recurso nomeado; um papel por função | cumprido |
| RNF-03 | 0 experimentos sem gráfico, inclusive com o bucket fora do ar | demonstração (`[RNF-03]`) | com o bucket fora do ar, 503 e 0 experimentos registrados; com o bucket de volta, 201; 0 experimentos sem gráfico nos projetos de teste | cumprido |
| RNF-04 | toda recusa no CloudWatch Logs em até 10 s, com data e hora, projeto e motivo | medição (`[RNF-04]`) | a linha apareceu em 3 s, nas duas rodadas, com data e hora, projeto e motivo, e sem o conteúdo enviado | cumprido |

### 3.1 Saída da medição

A primeira execução de `./testes/medir.sh`, que grava os 100 experimentos antes de medir:

```text
experimentos no projeto: 100
amostras:    30
minimo (s):  0.253717
mediana (s): 0.273478
p95 (s):     0.335462
maximo (s):  0.353607
RNF-01 cumprido: p95 de 335 ms, abaixo de 1.000 ms
```

E a medição feita dentro da suíte completa, logo depois de ela gravar centenas de registros de teste:

```text
amostras:    30
minimo (s):  0.258483
mediana (s): 0.272597
p95 (s):     1.839740
maximo (s):  10.287771
RNF-01 nao cumprido: p95 de 1839 ms, acima de 1.000 ms
```

A mediana é a mesma nas duas, perto de 270 ms. O que muda é a cauda: de vez em quando uma chamada leva de 2 a 10 s, e com 30 amostras bastam duas dessas para o p95 passar de 1.000 ms. Para saber onde está a demora, uma sondagem de 60 chamadas comparou o tempo total de cada uma com o tempo do DynamoDB dentro da função, que vem no campo `trilha` da resposta. Nas chamadas lentas, de 2.611 ms e 1.956 ms, o DynamoDB levou 18,2 ms e 17,9 ms — o mesmo que nas rápidas, cuja mediana foi 18,8 ms. A demora não está na consulta, nem na chave de partição: está no caminho entre o API Gateway e a função dentro do emulador. Nenhuma das chamadas lentas foi partida a frio.

Por isso o resultado é "cumprido em parte". O desenho que sustenta o número — `query` em uma partição só, sem `scan` (`[RNF-01] a lista e um query na particao, sem scan`) — está confirmado, e o tempo da consulta é estável em torno de 18 ms. O número de ponta a ponta no emulador oscila, e em duas de cinco medições no notebook Windows passou do prometido.

No MacBook, nenhuma das sete medições passou de 1.000 ms: o maior p95 foi 146 ms, e a mediana ficou entre 24 ms e 45 ms. A comparação mostra que o resultado depende do ambiente, mas não separa a causa, porque mudaram ao mesmo tempo o computador, o sistema operacional e a versão do emulador. Por isso, o resultado continua "cumprido em parte": o número só vale para o ambiente em que foi medido, e a AWS real não foi medida.

### 3.2 Requisitos verificados por análise

A segunda metade do RNF-01 — o tempo não cresce conforme outros projetos acumulam experimentos — foi verificada por análise. Ela depende de a consulta ler só a partição do projeto, e isso está confirmado: a trilha de cada resposta registra um `query` na partição, e a lista do projeto medido traz os seus 100 experimentos mesmo com centenas de outros registros de teste na tabela. Medir o efeito de verdade exigiria uma tabela com volume de produção, que o emulador num notebook não representa.

O RNF-02 foi verificado por inspeção, e não por teste de bloqueio: o emulador guarda as políticas, mas por padrão não as aplica. O que se confere é o que está escrito em cada política, que é o que o próprio requisito pede.

## 4. Matriz de rastreabilidade

| ID     | O que foi prometido | Como foi verificado | Evidência | Resultado |
|--------|---------------------|---------------------|-----------|-----------|
| RF-01  | Registrar o experimento, com identificador único e data e hora | teste automático | `[RF-01]`, `[US-01/1]` em `executar-do-zero-2026-11-05.txt`; E3.2 | cumprido |
| RF-02  | Gráfico no S3, confirmando o registro só depois de guardado | teste automático e demonstração | `[US-01/1]` gráfico baixado com o mesmo tamanho; `[RNF-03]`; E3.2 | cumprido |
| RF-03  | Lista do projeto, do mais recente ao mais antigo, com data, modelo, métrica, valor e identificador | teste automático | `[US-02/1]`, `[RF-03]`; E4.1 | cumprido |
| RF-04  | Recusar registro incompleto ou com métrica não numérica, dizendo o campo | teste automático | `[RF-04]`, 19 verificações; `[US-01/2]` | cumprido |
| RF-05  | Exibir um experimento completo pelo projeto e pelo identificador | teste automático | `[US-03/1]`, `[US-03/2]` | cumprido |
| RNF-01 | Lista em menos de 1.000 ms no p95, com 100 experimentos | medição | seção 3.1; `medir-2026-11-05.txt`; `medir-mac-2026-11-05.txt`; E5.2 | cumprido em parte |
| RNF-02 | Zero exclusão ou atualização, zero escrita na consulta, só recursos do projeto | inspeção | `[RNF-02]`; seção 3.2 | cumprido |
| RNF-03 | Nenhum experimento sem gráfico, inclusive com o bucket fora do ar | demonstração | `[RNF-03]` | cumprido |
| RNF-04 | Toda recusa no CloudWatch Logs em até 10 s | medição | `[RNF-04]` a linha apareceu em 3 s | cumprido |
| US-01  | Registrar cada rodada com modelo, hiperparâmetros, métrica e gráfico | teste automático e demonstração na página | C1, C2; E3.2, E4.2 | cumprido |
| US-02  | Ver todos os experimentos do projeto, do mais recente ao mais antigo | teste automático e demonstração na página | C3, C4; E4.2 | cumprido |
| US-03  | Abrir um experimento com todos os hiperparâmetros e o gráfico | teste automático e demonstração na página | C5, C6; E4.2 | cumprido |
| RD-01  | Gráfico e textos sem dado pessoal, com o aviso no formulário | teste automático e verificação humana | `[RD-01]` aviso publicado e log sem conteúdo; seção 2.2 | cumprido em parte |
| RD-02  | Experimento registrado não se altera nem se apaga | teste automático e inspeção | `[RD-02]` a API não oferece PUT, PATCH nem DELETE, e o `put_item` é condicional | cumprido |

### 4.1 Resumo

| Resultado         | Quantidade |
|-------------------|------------|
| Cumprido          | 12         |
| Cumprido em parte | 2          |
| Não cumprido      | 0          |

Os dois "em parte" estão explicados: o RNF-01, na seção 3.1, e o RD-01, na seção 2.2.

## 5. Homologação recebida

Dispensada pela professora da disciplina: não houve troca de repositórios com outra equipe, e por isso nenhuma resposta de outra equipe é apresentada aqui.

O que mais se aproxima, sem substituí-la, é a reconstrução em máquinas diferentes: o projeto foi reconstruído do zero em dois computadores diferentes da equipe, um notebook Windows e um MacBook, seguindo o `README.md`. No MacBook, as 96 verificações passaram; no notebook, 95 de 96, com a diferença explicada na seção 3.1. A configuração do Mac exigiu um ajuste no `infra/config.sh` (o zsh, shell padrão do Mac, não dividia o comando do AWS CLI em palavras), que foi corrigido e registrado no próprio arquivo.

### 5.1 O que foi corrigido depois

Não se aplica: sem homologação recebida, não houve apontamento de outra equipe a corrigir.

## 6. Homologação realizada

Dispensada pela professora, como a homologação recebida (seção 5). A captura E5.4 não se aplica.

## 7. O que não foi cumprido

Nenhum item do backlog ficou sem implementação: os doze da Sprint 2 estão no ar e testados. Ficaram de fora, como a Sprint 2 já tinha declarado, a paginação da lista além dos 100 experimentos mais recentes e a ligação entre uma correção e o experimento corrigido.

| Item | Por que ficou de fora | O que seria necessário para cumprir |
|------|-----------------------|-------------------------------------|
| RNF-01 em todas as medições | No emulador, no notebook Windows, algumas chamadas levam de 2 a 10 s entre o API Gateway e a função, embora a consulta leve 18 ms; em duas de cinco medições, o p95 passou de 1.000 ms. No MacBook, nenhuma das sete passou | Medir na AWS real, que é o ambiente para o qual o número foi escrito; no emulador, repetir a medição e registrar a distribuição, e não um número só |
| RD-01 por máquina | O sistema não tem como saber o que um gráfico mostra | Revisão humana do gráfico antes do registro, ou um classificador de imagem — os dois fora do recorte |
| Paginação além de 100 experimentos | Declarada fora na Sprint 2: um projeto acumula dezenas de rodadas | Um parâmetro de continuação na API e na página |
| Ligação entre correção e experimento corrigido | Declarada fora na Sprint 2 (Event Sourcing, seção 4.1) | Um campo opcional na gravação e o filtro na consulta |

## 8. Fechamento

### 8.1 O que funcionou melhor do que o esperado

A chave de ordenação começando pela data e hora. Foi uma linha de decisão na Sprint 2 e não precisou de nenhuma linha de código de ordenação depois: o próprio banco devolve a lista do mais recente ao mais antigo, o teto de 100 itens pega os 100 mais recentes, e o critério US-02, cenário 1, passa sem que a função ordene nada.

### 8.2 O que deu mais trabalho do que o esperado

Fazer o mesmo sistema rodar igual em máquinas diferentes. O bash do Windows convertia caminhos que começam com `/`, trocava os acentos na saída e quebrava os scripts com fim de linha CRLF; a primeira chamada de uma função recém-criada estourava o tempo-limite e devolvia erro com o experimento já gravado; e o emulador dependeu da rede para validar a licença no dia da validação. Cada um virou uma linha no `config.sh` ou no `deploy.sh`, e nenhum deles estava em requisito nenhum.

Os testes também deram trabalho do jeito certo: foram eles que acharam três defeitos que a Sprint 3 deixou passar — o valor `1_000` aceito como número, o corpo em base64 inválido derrubando a função com erro 500 e o projeto com barra gerando um endereço de gráfico que não abria.

### 8.3 O que você faria diferente se recomeçasse

Fecharia o formato da API no `openapi.yaml` antes de dividir o trabalho. Na Sprint 4, duas versões do sistema foram feitas em paralelo, com nomes de campo diferentes (`grafico` em uma, `grafico_base64` na outra) e respostas em formatos diferentes, e a página de uma não conversava com a API da outra. Com o contrato escrito primeiro, cada um teria construído a sua parte contra o mesmo arquivo, e a junção teria sido trocar um endereço, e não reescrever a página e a função de consulta.

## 9. Repositório

| Item | Resposta |
|------|----------|
| URL do repositório | https://github.com/thomasalane/Projeto-Cloud |
| Número de commits | 19: os 17 da captura E5.5, o que junta as capturas a este relatório e o que registra a dispensa da homologação cruzada |
| Há pelo menos um commit por sprint | Sim: estrutura e requisitos (Sprint 1), arquitetura (Sprint 2), armazenamento e função (Sprint 3), API e página (Sprint 4) e validação (Sprint 5) |
| Endereço do site depois do deploy | `http://diario-site.s3-website.localhost.localstack.cloud:4566/`, ou `http://localhost:4566/diario-site/index.html` quando a rede não resolve esse nome |

Commits por integrante, pela saída de `git --no-pager shortlog -sn HEAD` em 11/11/2026, na captura E5.5:

| Integrante | Commits |
|------------|---------|
| Thomas Alane | 12 (11 pelo terminal, 1 pelo site do GitHub, como `thomasalane`) |
| Eduardo Palhares Reale Pereira | 4 |
| Melina Pissolato | 1 |
| Davi Araujo | 0 |
