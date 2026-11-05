# Próximos passos para a entrega

Estado em 05/11/2026: as cinco sprints estão no repositório e o projeto roda inteiro no LocalStack. A suíte `./testes/executar.sh --do-zero` passou em 95 de 96 verificações; a única falha é o p95 do RNF-01 na rodada completa, explicada em `docs/03-validacao.md`, seção 3.1. Falta o que só a equipe pode fazer: os prints, a homologação cruzada e os commits de cada integrante.

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
- Para a página ter exemplos e os PNGs da demonstração: `pip install -r dados/requisitos.txt` e `python dados/semear.py`.

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

Valores de conferência que já se sabem: prefixo `diario`; tabela `diario-experimentos`; chave de partição `projeto`; endereço do site `http://diario-site.s3-website.localhost.localstack.cloud:4566/`. Os outros, como identificadores, tempos e p95, saem da execução de quem rodar.

## 2. Homologação cruzada (E5.4)

Obrigatória na Sprint 5:

- **A outra equipe roda o nosso projeto** seguindo só o `README.md` e responde: conseguiu rodar só com o README? O que faltava? Os testes passaram? Alguma linha da matriz não bateu? Em que ponto travou?
- **A nossa equipe roda o projeto dela** no nosso computador (comandos na E5.4) e responde as mesmas perguntas.

Com as respostas, acrescente ao `docs/03-validacao.md` as seções **5. Homologação recebida** (com 5.1, o que foi corrigido depois) e **6. Homologação realizada**, no formato do Template 3. A numeração do documento já deixa esse espaço entre a seção 4 e a 7.

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
- O relatório final é o `docs/03-validacao.md`, entregue no mesmo dia.
