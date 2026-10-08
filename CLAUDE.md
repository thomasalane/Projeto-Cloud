# CLAUDE.md — Projeto em Ciência de Dados IV (IBM8942, Ibmec) — Diário de Experimentos

## Regras que valem o semestre inteiro
1. **Todo recurso da nuvem nasce de um script versionado** (infra/deploy.sh, infra/destroy.sh). Nunca criar recurso "clicando" no painel.
2. **O ambiente é o LocalStack** (emulador local da AWS, porta 4566, credenciais "test"). Comandos via `lstk aws ...` ou `aws --endpoint-url`. Nada de conta AWS real, nada de custo.
3. **Nenhuma credencial é versionada.** `.gitignore` existe ANTES do primeiro commit.
4. **A documentação manda no código.** O que não está nos docs/ não se constrói. Cada decisão de código deve ser explicável ("por quê") na banca, e rastreável a um requisito (RF-xx) ou critério (US-xx cenário y).
5. **Sprints 1 e 2 não têm código.** Sprint 1 = requisitos (o que o sistema faz, sem decidir tecnologia). Sprint 2 = arquitetura (com o quê).
6. Scripts são **bash** (`#!/bin/bash`), rodam no Git Bash no Windows ou no Terminal Mac/Linux.
7. Git configurado só no repositório (sem `--global`). Commits pequenos, mensagens em português no formato `tipo: descrição`.
8. Responda e escreva documentos em **português do Brasil**.

## Estrutura do repositório
docs/ (01-requisitos.md, 02-arquitetura.md, ...), infra/ (config.sh, deploy.sh, destroy.sh, openapi.yaml), app/ (lambdas/, web/), testes/ (executar.sh), material/ (material da disciplina, somente leitura)

## Calendário (datas fixas)
S0 até 01/10 · S1 07–08/10 · S2 14–15/10 · S3 21–22/10 · S4 28–29/10 · S5 04–05/11 · Demoday 11–12/11 (12 min + 5 de perguntas, demo ao vivo a partir do ambiente derrubado: roda o deploy, sobe o site, grava e consulta).
