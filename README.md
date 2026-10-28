# Web Crawler - Eleições 2026 (Maranhão)
> Atividade Prática: **Manifesto Ágil e Extreme Programming (XP)**  
> **Instituição:** UNIFACIMP Wyden  
> **Curso:** Sistemas de Informação / Análise e Desenvolvimento de Sistemas  
> **Disciplina:** Engenharia de Software  
> **Docente:** Prof. Thalles dos Santos Canela (`thalles_tsc@hotmail.com`)

---

## 👥 Integrantes da Dupla & Pair Programming

| Integrante | GitHub | Papel Inicial |
| :--- | :--- | :--- |
| **Guilherme Teles Pacheco** | [@GuilhermeTeles3245](https://github.com/GuilhermeTeles3245) | Driver |
| **Lucas Paixão Cardoso Luis** | [@LucasPaixaoCL](https://github.com/LucasPaixaoCL) | Navigator |

> Durante os ciclos de desenvolvimento, os papéis de **Driver** (responsável pela digitação, sintaxe e implementação) e **Navigator** (revisão contínua, arquitetura, questionamentos e orientação dos casos de teste) foram alternados a cada incremento.

---

## 🎯 Objetivo do Projeto
Evoluir o crawler em Shell Script (`buscador.sh` / `tse-top-candidates.sh`) para consulta e exibição de dados de apuração das eleições oficiais do Tribunal Superior Eleitoral (TSE), aplicando práticas de **Extreme Programming (XP)** e princípios do **Manifesto Ágil**:
- *Software em funcionamento* mais que documentação abrangente;
- *Feedback curto e frequente* com validação rápida;
- *Design simples (KISS)* e refatoração contínua;
- *Integração contínua* com commits pequenos e semânticos.

---

## 🔍 Etapa 4 — Diagnóstico do Script Original

Após leitura criteriosa e execução exploratória do código base fornecido, a dupla identificou os seguintes pontos frágeis e limitações:

1. **Acoplamento a Município Único Fixo:**
   - O script possuía `MUNICIPIO="${TSE_RESULTS_MUNICIPALITY:-07242}"` fixado em Davinópolis-MA.
   - Não havia mecanismo para consultar outras cidades do Maranhão de forma amigável e nem para processar todas as 217 cidades do estado.
2. **Ausência de Suporte ao 2º Turno:**
   - O código consultava exclusivamente códigos de 1º turno (`FEDERAL_ELECTION=6257` e `STATE_ELECTION=6259`).
   - Não consultava e nem exibia separadamente os resultados do 2º turno (`FEDERAL_ELECTION=6258` e `STATE_ELECTION=6260`) quando disponíveis.
3. **Falta de Identificação de Candidatos Eleitos:**
   - A tabela processava apenas `nome`, `numero` e `votos`.
   - As propriedades retornadas pelo TSE (`.e` para indicação se eleito `"s"/"n"` e `.st` com a situação `"Eleito"`, `"2º turno"`, `"Não eleito"`, etc.) eram descartadas.
4. **Fragilidade no Tratamento de Erros HTTP:**
   - O script abortava bruscamente com a função `die` diante de qualquer falha no `curl`. No 2º turno, cargos sem disputa (ex: deputados e senadores) retornam HTTP 404 por definição; o script original quebrava sem apresentar os demais cargos.
5. **Usabilidade e Linha de Comando Rígida:**
   - Os parâmetros só podiam ser alterados via variáveis de ambiente, sem suporte a opções/flags via linha de comando (`-m`, `-t`, `-c`, `-l`, `-h`).
   - Não havia busca de municípios por nome (ex: `Imperatriz`, `São Luís`), exigindo conhecimento prévio do código numérico de 5 dígitos do TSE.

---

## 📋 Planejamento das Melhorias em Ciclos de XP

| Ciclo | Melhoria Planejada | Driver | Navigator |
| :---: | :--- | :---: | :---: |
| **1** | Diagnóstico inicial da base de código e documentação no `README.md` | Guilherme Teles | Lucas Paixão |
| **2** | Indicação explícita e visual de candidatos eleitos e status de 2º turno na tabela | Lucas Paixão | Guilherme Teles |
| **3** | Suporte a consulta e apresentação separada de 1º e 2º turnos com tratamento de 404 | Guilherme Teles | Lucas Paixão |
| **4** | Suporte a todos os 217 municípios do Maranhão, busca por nome e códigos | Lucas Paixão | Guilherme Teles |
| **5** | Interface de linha de comando (CLI flags), validações e mensagens de erro amigáveis | Guilherme Teles | Lucas Paixão |
| **6** | Validação final integrada, merge na `main` e registro de evidências | Lucas Paixão | Guilherme Teles |

---

## 🛠️ Pré-requisitos
- Sistema Operacional Linux, macOS ou Windows (via Git Bash / WSL)
- `bash` (v4+)
- `curl`
- `jq` (processamento de JSON)
