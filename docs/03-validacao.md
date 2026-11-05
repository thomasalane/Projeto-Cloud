# Relatório de Validação

Projeto: Diário de Experimentos (`diario-de-experimentos`)  
Sprint: 5, validação  
Data: 04/11/2026  
Versão: 1.0

## 1. O que foi validado, e onde

Os testes nascem dos documentos: os seis cenários BDD (`01-requisitos.md`, seção 5) e os quatro requisitos não funcionais (`02-arquitetura.md`, seção 1). Cada teste de `testes/executar.sh` leva o ID do que confere.

| Ambiente | O que ele prova | Situação |
|----------|-----------------|----------|
| Emulador de teste, com a biblioteca `moto` e um gateway local, fora do repositório | A lógica das funções, os scripts de `infra/`, o contrato da API e a página | Executado em 04/11/2026: seções 3 e 4 |
| LocalStack, o ambiente oficial do projeto | Tudo acima no emulador da disciplina, e os tempos reais | **Pendente:** preencher a seção 5 |

A máquina em que este relatório foi escrito não tem Docker, e o LocalStack depende dele. Por isso o emulador de teste fez o papel do LocalStack na primeira validação. **Os números de tempo da seção 4 não valem como medição do RNF-01:** sem contêiner, as Lambdas ali ficam mais rápidas do que no LocalStack.

## 2. Como rodar

Com o LocalStack no ar, no Git Bash:

```bash
./testes/executar.sh            # testa o ambiente que está no ar
./testes/executar.sh --do-zero  # derruba tudo, sobe do zero, testa e faz o deploy de novo
```

O `--do-zero` **apaga os dados** e reproduz a condição do Demoday. Os testes precisam só de `curl`, do AWS CLI e de Python, sem biblioteca externa. O resumo fica na tela e em `testes/ultima-execucao.txt`; o código de saída é 0 se nada falhou.

Cada rodada usa projetos com sufixo único. Como nada se apaga (RD-02), é assim que "projeto vazio" continua verdadeiro a cada rodada e que os testes não se misturam aos projetos da demonstração.

## 3. Rastreabilidade

| Item | O que é conferido | Teste | Emulador |
|------|-------------------|-------|----------|
| US-01, cenário 1 | 201, 1 identificador, exatamente 1 experimento, 0,412 sem arredondar, gráfico com o mesmo tamanho em bytes | `US-01/1` | Passou |
| US-01, cenário 2 | "baixo" recusado com 400 apontando o valor, continua com 1, 0 gráficos novos | `US-01/2` | Passou |
| US-02, cenário 1 | Exatamente 3, na ordem Random Forest, SARIMA, ARIMA, 0 do outro projeto | `US-02/1` | Passou |
| US-02, cenário 2 | 200 com total 0, mensagem e convite no lugar da tabela | `US-02/2` | Passou |
| US-03, cenário 1 | Exatamente 1, hiperparâmetros idênticos, RMSE 0,385, endereço do gráfico | `US-03/1` | Passou |
| US-03, cenário 2 | 404, 0 experimentos, nenhum dado de outro | `US-03/2` | Passou |
| RF-01 | Identificador novo a cada registro, data e hora em ISO 8601 | `RF-01` | Passou |
| RF-02 | Gráfico guardado e aberto pelo endereço devolvido | `US-01/1`, `RNF-03` | Passou |
| RF-03 | Só a partição do projeto, em ordem, com os campos pedidos, limite, consulta sem projeto | `RF-03`, `US-02/1` | Passou |
| RF-04 | Cada campo ausente, valor inválido, gráfico inválido, corpo inválido; nada guardado | `RF-04` | Passou |
| RF-05 | Experimento completo pelo projeto e pelo identificador | `US-03/1` | Passou |
| RD-01 | Aviso no formulário publicado; o log não guarda o conteúdo enviado | `RD-01` | Passou |
| RD-02 | A API não oferece PUT, PATCH nem DELETE; o experimento fica intacto; `put_item` condicional | `RD-02` | Passou |
| RNF-01 | 100 experimentos, 30 requisições, p95 abaixo de 1.000 ms, `query` e não `scan` | `RNF-01` | Lógica passou; tempo pendente (seção 5) |
| RNF-02 | Ações exatas de cada papel, recursos nomeados, um papel por função | `RNF-02` | Passou |
| RNF-03 | Bucket fora do ar: 503 e nenhum experimento; todo experimento tem o seu arquivo | `RNF-03` | Passou |
| RNF-04 | Linha com data, projeto e motivo, em até 10 s depois da resposta | `RNF-04` | Passou |
| Demoday | `destroy.sh` limpa, `deploy.sh` sobe do zero, segundo deploy não perde dados | `DEMO` | Passou |

Para simular o bucket fora do ar sem apagar nada, o teste do RNF-03 aponta a função para um bucket inexistente e restaura a configuração em seguida, mesmo se o script for interrompido. O próprio `--do-zero` confere, no final, que ela voltou.

## 4. Resultados no emulador de teste

| Execução | Passaram | Falharam | Pulados |
|----------|----------|----------|---------|
| `executar.sh --do-zero` | 96 | 0 | 0 |
| `executar.sh`, em seguida, sem derrubar nada | 90 | 0 | 0 |
| Página no Microsoft Edge, nos dois endereços | 60 | 0 | 0 |

A diferença entre 96 e 90 são os 6 testes da etapa `DEMO`, que só existem com o `--do-zero`.

**A página.** Um script fora do repositório percorreu o roteiro da demonstração no navegador, nos dois endereços: lista, projeto vazio e convite, as recusas, o registro certo, a rodada nova no topo, o detalhe com o gráfico carregado, o identificador trocado, o mapa "Por trás da tela" e a largura de celular (390 px). O endereço de site estático tem origem diferente da API e, portanto, exercitou o CORS de verdade: nenhum erro no console.

**Os testes pegam defeito?** Para conferir que os testes não passam à toa, nove defeitos foram colocados de propósito em uma cópia descartável. Os nove foram apanhados.

| Defeito colocado | Teste que falhou |
|------------------|------------------|
| Lista em ordem crescente | `US-02/1`, `RF-03` |
| Valor arredondado para 2 casas | `US-01/1`, `US-03/1`, `RD-02` |
| Modelo deixa de ser obrigatório | `RF-04` |
| Falha no bucket responde 201 | `RNF-03` |
| `dynamodb:DeleteItem` no papel da consulta | `RNF-02` |
| Função para de registrar no log | `RNF-04` |
| Aviso do RD-01 removido da página | `RD-01` |
| Identificador inexistente responde 200 | `US-03/2` |
| Busca deixa de normalizar o projeto | `02-arq s9` |

## 5. Execução no LocalStack

**Pendente.** Rodar `./testes/executar.sh --do-zero` e preencher com o que estiver em `testes/ultima-execucao.txt`.

| Item | Resultado |
|------|-----------|
| Data e versão do LocalStack | |
| Passaram, falharam, pulados | |
| Tempo do deploy do zero (Demoday) | |
| RNF-01: p95, mediana e máximo | |
| RNF-04: tempo até a linha aparecer | |

Se o endereço de site estático aparecer como pulado, a rede não resolveu o nome; é o caso que o endereço alternativo cobre.

## 6. Defeitos encontrados e corrigidos

| Defeito | Efeito | Correção |
|---------|--------|----------|
| `semear.py` pedia ao Banco Central os últimos 120 valores, e a rota recusa | Todo gráfico saía como "série ilustrativa (sem internet)", mesmo com internet | Pede por período; a série real voltou (119 e 120 meses) |
| O roteiro fazia o deploy antes da apresentação | Contrariava o Demoday, que parte do ambiente derrubado | O deploy agora é a primeira parte da apresentação |
| O RNF-02 e o roteiro diziam que nem um defeito no código reescreveria o histórico | Falso: `PutItem` substitui um item de mesma chave | Texto corrigido; o limite está declarado em `02-arquitetura.md`, seção 9 |
| Corpo em base64 que não é UTF-8 | Exceção não tratada, em vez de 400 | Recusado com 400 |
| Projeto com barra, como `../fora` | Registro aceito, com endereço de gráfico que não abriria | Recusado com 400 |
| Valor `1_000` | Aceito como 1000 | Recusado com 400 |
| Mensagem do campo projeto na página | Dizia "Preencha este campo." mesmo preenchido | Mostra o motivo da recusa |
| Exemplo do identificador | Sem os microssegundos que o código gera | Documento e página corrigidos |

## 7. Limites conhecidos

- **IAM.** O emulador guarda a política, mas por padrão não a aplica. O RNF-02 é conferido pelo conteúdo da política, como o próprio requisito diz.
- **Sobrescrita.** O IAM não distingue inserir de substituir. A proteção é a condição do `put_item`, no código (`02-arquitetura.md`, seção 9).
- **Zeros à direita.** O DynamoDB guarda `0,4120` como `0.412`: o mesmo número, sem o último zero.
- **Rodadas de teste.** Sem `--do-zero`, os projetos de teste ficam na tabela, porque nada se apaga. Eles têm prefixo `t<data>-` e somem no `destroy.sh`.
- **Página.** O percurso no navegador não está em `testes/executar.sh`, para o projeto não depender de bibliotecas de automação. O `executar.sh` confere a página publicada e os seus textos; o percurso é o próprio roteiro da demonstração.
