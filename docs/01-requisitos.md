# Documento de Requisitos

Projeto: Diário de Experimentos (`diario-de-experimentos`)  
Cenário oficial escolhido: Ideia própria da equipe (Diário de Experimentos)  
Data: 07/10/2026  
Versão: 1.0

## 1. O cenário

### 1.1 Cenário escolhido

Ideia própria da equipe. Um caderno online de experimentos de machine learning: cada rodada de treino de um modelo é registrada com o modelo usado, os hiperparâmetros, a métrica obtida e o gráfico do resultado, e depois consultada por projeto para comparar as configurações já testadas.

A ideia responde às quatro perguntas do catálogo: o que se cadastra é um experimento; o arquivo que vem junto é o gráfico do resultado (por exemplo, valores reais contra valores previstos); o campo pelo qual se busca é o projeto; e a pergunta que a tela responde é "quais experimentos existem no projeto X, do mais recente ao mais antigo?". Responde também às três verificações de ideia própria: o recorte é um cadastro e uma consulta; um projeto acumula dezenas de rodadas, então a consulta devolve uma lista; e o gráfico é necessário, porque é ele que mostra se o número da métrica conta a história inteira — um erro médio baixo pode esconder um modelo que só repete o valor anterior.

### 1.2 O problema, em linguagem comum

Quem treina modelos de previsão roda dezenas de variações do mesmo experimento — muda o modelo, ajusta um parâmetro, altera o período de dados — e no fim precisa saber qual configuração deu o melhor resultado. Hoje esse histórico fica espalhado em planilhas soltas, capturas de tela e anotações de caderno, e se perde quando a pessoa retoma o trabalho semanas depois ou quando o colega de dupla precisa saber o que já foi tentado. Sem um registro único, rodadas são repetidas sem querer, o melhor resultado é esquecido e a escolha do modelo final vira lembrança, não evidência.

### 1.3 O recorte

| Dentro do escopo                                                                      | Fora do escopo                                              |
|---------------------------------------------------------------------------------------|-------------------------------------------------------------|
| Registro de um experimento (projeto, modelo, hiperparâmetros e métrica), com o gráfico | Conta de usuário, login e permissão por projeto             |
| Consulta dos experimentos de um projeto, do mais recente ao mais antigo               | Treino ou execução do modelo dentro do sistema              |
| Consulta de um experimento específico, com todos os detalhes, pelo identificador      | Edição ou exclusão de um experimento já registrado          |
| Recusa de registro incompleto ou com métrica inválida, apontando o campo              | Gráfico comparativo e ranking automático entre experimentos |

### 1.4 Por que este recorte

O diário só substitui a planilha se registrar for rápido e se o registro puder ser reencontrado depois. Registrar, listar por projeto e abrir um experimento específico são, juntos, o mínimo que cumpre isso. A recusa do registro incompleto entra no recorte porque um experimento sem métrica, ou com a métrica escrita de qualquer jeito, não se compara com nada — e comparar é a razão de existir do diário.

O treino continua onde já acontece, no ambiente de quem treina: o problema relatado não é rodar o modelo, é perder o resultado. Login ficou de fora porque cada projeto é usado por uma pessoa ou por uma dupla que já se conhece, e exigir conta atrasaria justamente o primeiro registro. Editar e excluir ficaram de fora de propósito (RD-02): um diário de experimentos vale pelo histórico completo, e uma rodada ruim também é informação — corrigir um resultado é registrar uma rodada nova, não reescrever a antiga. O gráfico comparativo e o ranking automático dependem de saber, para cada métrica, se "melhor" é o menor valor (como no RMSE) ou o maior (como na acurácia); com poucas dezenas de rodadas por projeto, a lista ordenada já permite comparar a olho.

Também foram considerados e descartados: guardar o conjunto de dados usado no treino (arquivos grandes e com risco de conter dado pessoal, ver RD-01) e importar registros de ferramentas de rastreamento como o MLflow (quem já usa essas ferramentas não precisa do diário; o público é quem hoje anota em planilha).

## 2. Requisitos funcionais

| ID    | Requisito                                                                                                                                                                         | Serviço AWS citado | Prioridade |
|-------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|--------------------|------------|
| RF-01 | O sistema deve registrar um experimento com projeto, nome do modelo, hiperparâmetros, nome da métrica e valor da métrica, gerando um identificador único e a data e hora a cada registro. | —                  | essencial  |
| RF-02 | O sistema deve armazenar no Amazon S3 o gráfico do resultado anexado ao experimento, confirmando o registro somente depois que o arquivo estiver guardado.                        | Amazon S3          | essencial  |
| RF-03 | O sistema deve listar os experimentos de um projeto consultando o Amazon DynamoDB, do registro mais recente para o mais antigo, exibindo data, modelo, métrica, valor e identificador de cada um. | Amazon DynamoDB    | essencial  |
| RF-04 | O sistema deve recusar o registro de um experimento sem projeto, sem modelo, sem métrica, sem gráfico ou com valor de métrica não numérico, informando qual campo faltou ou está inválido. | —                  | essencial  |
| RF-05 | O sistema deve exibir um experimento específico, com todos os hiperparâmetros, a métrica e o gráfico, quando o usuário informar o projeto e o identificador do experimento.       | —                  | importante |

Os hiperparâmetros ficam fora da lista de campos obrigatórios do RF-04 de propósito: um modelo de referência, como o ingênuo que repete o último valor observado, não tem hiperparâmetro nenhum — e é justamente ele que serve de régua para avaliar os outros.

### 2.1 Verificação da estrutura

| ID    | Verbo     | Objeto                                              | Condição                                                             |
|-------|-----------|-----------------------------------------------------|----------------------------------------------------------------------|
| RF-01 | registrar | um experimento                                      | gerando identificador único e data e hora a cada registro            |
| RF-02 | armazenar | o gráfico do resultado, no Amazon S3                | confirmando o registro somente depois que o arquivo estiver guardado |
| RF-03 | listar    | os experimentos de um projeto                       | do mais recente para o mais antigo, com data, modelo, métrica, valor e identificador |
| RF-04 | recusar   | o registro incompleto ou com métrica não numérica   | informando qual campo faltou ou está inválido                        |
| RF-05 | exibir    | um experimento específico, completo                 | quando o usuário informar o projeto e o identificador                |

## 3. Requisitos de domínio

| ID    | Restrição                                                                                                  | Origem                                                                                                                       | O que ela impede ou obriga                                                                                                                                                                     |
|-------|------------------------------------------------------------------------------------------------------------|------------------------------------------------------------------------------------------------------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| RD-01 | O gráfico e os campos de texto do experimento não podem conter dado pessoal das pessoas presentes no conjunto de dados. | LGPD (Lei 13.709/2018), art. 5º, I (definição de dado pessoal) e art. 6º, III (princípio da necessidade)                     | Impede anexar gráfico ou escrever hiperparâmetro que exiba nome, CPF, contato ou outra informação que identifique uma pessoa; obriga o aviso no formulário de que o registro leva apenas resultados agregados, nunca linhas do conjunto de dados. |
| RD-02 | Um experimento registrado não pode ser alterado nem apagado; a correção se faz com um novo registro.      | Regra de negócio do cenário, inspirada nos Princípios de Boas Práticas de Laboratório da OCDE: correção não apaga o registro original | Impede editar ou excluir experimento (fora do escopo, seção 1.3); obriga que um erro de digitação seja corrigido registrando a rodada de novo, com novo identificador.                          |

Limite de tamanho e formato do arquivo do gráfico foram considerados e não entram aqui: não vêm de lei nem de regra do cenário, e sim de decisão técnica, que pertence à Sprint 2.

## 4. Histórias de usuário

### US-01

    Como estudante que treina vários modelos de previsão para o
    mesmo trabalho
    Eu quero registrar cada rodada com o modelo, os hiperparâmetros,
    a métrica e o gráfico do resultado
    Para que nenhuma rodada se perca e eu não repita, sem perceber,
    uma configuração que já testei

### US-02

    Como integrante de uma dupla que divide os treinos de um mesmo
    projeto
    Eu quero ver todos os experimentos do projeto, do mais recente
    ao mais antigo
    Para que eu e meu colega escolhamos o modelo do relatório
    comparando as rodadas dos dois, sem passar planilhas de um para
    o outro por mensagem

### US-03

    Como aluno que retoma um projeto semanas depois do último treino
    Eu quero abrir um experimento específico com todos os
    hiperparâmetros e o gráfico
    Para que eu consiga reproduzir a melhor configuração sem precisar
    adivinhar como cheguei nela

## 5. Critérios de aceite em BDD

### US-01, cenário 1

    Dado que o projeto previsao-inflacao ainda não tem nenhum
    experimento, e preencho modelo "ARIMA", hiperparâmetros
    "order=(1,1,1)", métrica "RMSE" com valor 0,412 e anexo 1 gráfico
    Quando confirmo o registro
    Então o sistema devolve 1 identificador, o projeto passa a ter
    exatamente 1 experimento, com o valor 0,412 sem arredondamento,
    e o gráfico baixado pelo endereço devolvido tem o mesmo tamanho,
    em bytes, do arquivo enviado

### US-01, cenário 2

    Dado que o projeto previsao-inflacao tem 1 experimento, e
    preencho todos os campos e anexo o gráfico, mas digito "baixo"
    no valor da métrica
    Quando confirmo o registro
    Então o sistema recusa o registro, informa que o valor da
    métrica precisa ser numérico, o projeto continua com exatamente
    1 experimento e 0 gráficos novos são guardados

### US-02, cenário 1

    Dado que a dupla registrou no projeto previsao-inflacao, nesta
    ordem, os modelos ARIMA, SARIMA e Random Forest, e no projeto
    previsao-cambio outros 2 experimentos
    Quando consulto o projeto previsao-inflacao
    Então a lista traz exatamente 3 experimentos, na ordem Random
    Forest, SARIMA e ARIMA, e 0 experimentos do previsao-cambio

### US-02, cenário 2

    Dado que o projeto previsao-desemprego não tem nenhum
    experimento registrado
    Quando consulto o projeto previsao-desemprego
    Então a resposta traz 0 experimentos e, no lugar da tabela, uma
    mensagem dizendo que o projeto ainda não tem experimentos e
    convidando a registrar o primeiro

### US-03, cenário 1

    Dado que registrei no projeto previsao-inflacao um SARIMA com
    hiperparâmetros "order=(1,1,1), seasonal_order=(0,1,1,12)",
    RMSE 0,385 e 1 gráfico
    Quando informo o projeto e o identificador devolvido nesse
    registro
    Então o sistema exibe exatamente 1 experimento, com os
    hiperparâmetros idênticos aos digitados, RMSE 0,385 e o
    endereço do gráfico enviado

### US-03, cenário 2

    Dado que o projeto previsao-inflacao tem 3 experimentos
    Quando informo o projeto e um identificador que não pertence a
    nenhum dos 3
    Então o sistema informa que o experimento não foi encontrado
    naquele projeto, exibe 0 experimentos e não mostra dados de
    nenhum dos 3 existentes

### 5.1 O cenário de exceção

Três dos seis tratam exceção. O de US-01, cenário 2, trata valor inválido: a métrica digitada como texto ("baixo"), e confere também que a recusa não deixa nada guardado pela metade. O de US-02, cenário 2, trata lista vazia: um projeto sem nenhum experimento. O de US-03, cenário 2, trata identificador inexistente no projeto informado.

Os seis foram escritos para virar teste na Sprint 5: cada "Então" tem uma contagem ou um valor exato que um script consegue conferir sozinho.

## 6. Avaliação INVEST

| História | I   | N   | V   | E   | S   | T   | O que seria ajustado                                                                                      |
|----------|-----|-----|-----|-----|-----|-----|-----------------------------------------------------------------------------------------------------------|
| US-01    | sim | sim | sim | sim | sim | sim | É a maior das três (registro, gráfico e validação); se não couber na sprint, a validação do RF-04 vira história própria |
| US-02    | não | sim | sim | sim | sim | sim | A lista só tem conteúdo depois que a US-01 existe; mantida separada e posta depois dela no backlog        |
| US-03    | não | sim | sim | sim | sim | sim | O identificador consultado é o que a US-01 devolve; mantida separada e posta depois dela no backlog       |

### 6.1 Justificativa das reprovações

US-02 reprova no **I**, de Independent: a lista de um projeto só tem conteúdo depois que existe registro, e o próprio critério US-02, cenário 1, parte de 3 experimentos já registrados. Para ser independente, ela teria de trazer o registro junto — e aí deixaria de ser outra história.

US-03 reprova no **I** de forma ainda mais direta: o identificador que ela consulta é o que a US-01 devolve. Uma versão independente exigiria que o identificador viesse de fora do sistema, o que não faz sentido no cenário.

Fundir as três em uma só ("quero registrar, listar e abrir experimentos") resolveria o I, mas reprovaria no **S**, de Small: seria o sistema inteiro, grande demais para uma sprint e difícil de estimar. Mantivemos as três separadas, com a dependência declarada e a US-01 primeiro no backlog. Depois dela, US-02 e US-03 não dependem uma da outra e podem ser feitas em qualquer ordem: a dependência ordena o trabalho, mas não o trava.

A US-01 passa no S, mas é a maior das três. Se na Sprint 3 ela não couber, o ajuste previsto é separar a validação (RF-04) em uma história própria, que continuaria pequena e testável pelo cenário 2.

## 7. Qualidade pelo FURPS

| Categoria      | Preocupação principal no meu cenário                                                                                                                                                                         |
|----------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Functionality  | A métrica precisa voltar exatamente como foi registrada: um RMSE de 0,412 não pode reaparecer como 0,41 nem como 0,41199999, porque uma diferença na terceira casa decimal é o que decide entre dois modelos. |
| Usability      | O valor da métrica precisa ser aceito com vírgula ou com ponto (0,412 e 0.412 são o mesmo número), porque quem treina copia o valor do código, com ponto, e quem escreve o relatório digita com vírgula.     |
| Reliability    | Nenhum experimento pode ficar registrado apontando para um gráfico que não foi guardado: se o envio do gráfico falhar, o registro inteiro não acontece e a pessoa é avisada para tentar de novo.            |
| Performance    | A lista do projeto é aberta a cada nova rodada, para comparar: com até 100 experimentos no projeto, ela deve aparecer em menos de 1 segundo, e o tempo não pode crescer conforme outros projetos acumulam experimentos. |
| Supportability | Quando um registro falhar, quem mantém o sistema precisa descobrir o motivo sem ter visto o erro acontecer: toda recusa ou falha deve deixar um rastro com data, projeto e motivo, consultável depois.       |

## 8. Decisões e alternativas descartadas

| Decisão                | Alternativa considerada                                                                     | Por que não foi escolhida                                                                                                                                                                                                                                                       |
|------------------------|---------------------------------------------------------------------------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| O recorte do cenário   | Executar o treino dentro do sistema, registrando a métrica automaticamente ao fim de cada rodada | Eliminaria a digitação, mas exigiria rodar o código de cada usuário, com bibliotecas e tempos de execução imprevisíveis. O problema relatado não é treinar, é perder o resultado: o treino já funciona onde está, o que falta é onde guardar o que ele produz.                |
| Quais cinco requisitos | Substituir o RF-05 (abrir um experimento pelo identificador) por ordenar a lista do projeto pelo melhor valor da métrica | "Melhor" muda com a métrica — no RMSE é o menor, na acurácia é o maior —, e ordenar exigiria declarar essa direção para cada métrica de cada projeto. Abrir o experimento completo atende a necessidade mais frequente, que é reproduzir a configuração vencedora; com poucas dezenas de rodadas, achar a melhor na lista se faz a olho. |
| Qual caso de exceção   | Tratar só o campo obrigatório ausente, como o registro sem gráfico                         | Campo vazio salta aos olhos de quem preenche; métrica escrita errada, como "baixo", passa despercebida e estraga em silêncio toda comparação do projeto. Por isso o US-01, cenário 2, trata valor não numérico. Lista vazia e identificador inexistente também entram, porque são o primeiro uso de todo projeto novo e o erro mais comum de quem copia o identificador à mão. |
