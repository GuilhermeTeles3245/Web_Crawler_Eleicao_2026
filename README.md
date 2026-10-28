# Web Crawler - Eleições Oficiais TSE 2026 (Maranhão)
> **Atividade Prática:** Manifesto Ágil e Extreme Programming (XP)  
> **Instituição:** UNIFACIMP Wyden  
> **Cursos:** Sistemas de Informação & Análise e Desenvolvimento de Sistemas  
> **Disciplina:** Engenharia de Software  
> **Docente:** Prof. Me. Thalles dos Santos Canela (`thalles_tsc@hotmail.com`)  
> **Repositório Base:** [aXR6/Web_Crawler_Eleicao_2026](https://github.com/aXR6/Web_Crawler_Eleicao_2026)  
> **Fork da Dupla:** [GuilhermeTeles3245/Web_Crawler_Eleicao_2026](https://github.com/GuilhermeTeles3245/Web_Crawler_Eleicao_2026)

---

## 👥 Dupla de Pair Programming

| Integrante | GitHub | Papéis Atribuídos |
| :--- | :--- | :--- |
| **Guilherme Teles Pacheco** | [@GuilhermeTeles3245](https://github.com/GuilhermeTeles3245) | Driver (Ciclos 1, 3 e 5) / Navigator (Ciclos 2, 4 e 6) |
| **Lucas Paixão Cardoso Luis** | [@LucasPaixaoCL](https://github.com/LucasPaixaoCL) | Navigator (Ciclos 1, 3 e 5) / Driver (Ciclos 2, 4 e 6) |

---

## 📖 Dinâmica de Extreme Programming (XP) Aplicada

A evolução do projeto seguiu rigorosamente os valores e práticas do **Extreme Programming (XP)** e princípios do **Manifesto Ágil**:

1. **Pair Programming (Programação em Par):**
   - **Driver:** Focado na implementação, sintaxe Bash, manipulação do `jq` e formatação visual.
   - **Navigator:** Focado na revisão contínua do código em tempo real, validação da arquitetura, antecipação de casos de borda (ex: codepage no Windows, delimitadores de TSV, códigos HTTP 404 em segundo turno).
   - **Alternância de Papéis:** A cada ciclo de melhoria (iteração curta), os papéis foram invertidos, garantindo propriedade coletiva do código (*Collective Ownership*).
2. **Pequenas Mudanças & Simplicidade (Small Releases & Simple Design):**
   - Cada melhoria foi implementada isoladamente, validada imediatamente e versionada em commits pequenos e descritivos.
3. **Feedback Curto e Refatoração (Continuous Feedback & Refactoring):**
   - O script foi executado contra os endpoints reais do TSE após cada alteração. Falhas descobertas (como o colapso de tabs vazias no TSV e problemas de `\r` no Windows) foram corrigidas antes de avançar.
4. **Integração Frequente (Continuous Integration):**
   - Trabalho realizado na branch `melhoria-xp` com commits atômicos contendo a coautoria dos dois desenvolvedores, finalizando com o merge na `main`.

---

## 🔍 Etapa 4 — Diagnóstico do Script Original

Na leitura inicial do script base (`buscador.sh`), foram diagnosticadas as seguintes fragilidades:

| # | Problema Identificado | Impacto no Usuário / Sistema |
| :-: | :--- | :--- |
| **1** | Município fixo no código (`MUNICIPIO="${TSE_RESULTS_MUNICIPALITY:-07242}"` - Davinópolis) | Impedia a consulta das demais 216 cidades do Maranhão sem alterar o código ou conhecer o código TSE. |
| **2** | Ausência de suporte ao 2º Turno (`6257` e `6259` fixos) | O crawler ignorava os dados da eleição de 2º turno (`6258` e `6260`) para Presidente e Governador. |
| **3** | Omissão dos dados de eleição (`.e` e `.st` descartados) | A tabela não informava se o candidato foi **[ELEITO]**, se foi para o **2º TURNO**, ou se não foi eleito. |
| **4** | Encerramento abrupto com `die` diante de 404 HTTP | No 2º turno, cargos sem disputa (Deputados e Senadores) retornam 404. O script abortava sem mostrar os demais cargos. |
| **5** | Inexistência de interface CLI amigável | Usuário precisava definir variáveis de ambiente para customizar a execução. Sem flags de linha de comando ou `--help`. |

---

## 🚀 Melhorias e Correções Implementadas

### 1. Suporte a Todos os 217 Municípios do Maranhão
- Adicionada base local `municipios_ma.tsv` mapeando todos os 217 municípios do Maranhão (códigos TSE e nomes oficiais).
- Implementada a função `resolver_municipio` que aceita:
  - **Nome aproximado / insensível a maiúsculas e acentos:** ex: `./buscador.sh -m "Imperatriz"`, `./buscador.sh -m "sao luis"`, `./buscador.sh -m "acailandia"`.
  - **Código numérico TSE (5 dígitos):** ex: `./buscador.sh -m 08036`, `./buscador.sh -m 07242`, `./buscador.sh -m 09210`.
  - **Total consolidado estadual:** ex: `./buscador.sh -m estado` ou `./buscador.sh -m ma`.
  - **Todos os municípios:** ex: `./buscador.sh -m todos` ou `./buscador.sh --todos-municipios` (itera por todas as cidades).
  - **Listagem completa:** ex: `./buscador.sh -l` (lista todos os 217 municípios e códigos).

### 2. Consulta e Apresentação Separada de 1º e 2º Turnos
- Suporte a `-t 1`, `-t 2` ou `-t todos`:
  - **1º Turno:** Códigos TSE `6257` (Federal) e `6259` (Estadual). Cargos: Presidente, Governador, Senador, Deputado Federal e Deputado Estadual.
  - **2º Turno:** Códigos TSE `6258` (Federal) e `6260` (Estadual). Cargos: Presidente e Governador.
  - **Apresentação Separada:** Cabeçalhos com destaque visual identificando claramente cada turno.
  - **Tratamento Resiliente de HTTP 404:** Se um cargo não tiver disputa de 2º turno (ou tiver sido decidido no 1º turno), o script informa amigavelmente e segue o processamento.

### 3. Indicação Clara de Candidatos Eleitos
- Extração dos campos `.e` (eleito: `"s"/"n"`) e `.st` (situação da totalização).
- Adicionada coluna **SITUAÇÃO** e coluna **%** (percentual de votos válidos apurados).
- Destaques visuais:
  - **[ELEITO]:** Destacado em verde negrito (`\033[1;32m`).
  - **➜ 2º TURNO:** Destacado em amarelo negrito (`\033[1;33m`).
  - **Não eleito / Suplente:** Exibidos de forma limpa e discreta.

### 4. Interface CLI Completa e Robustez
- Parser de argumentos robusto via flags (`-m`, `-t`, `-c`, `-l`, `-a`, `-L`, `--cor`, `-h`).
- Manual de ajuda integrado (`--help`).
- Script de compatibilidade `tse-top-candidates.sh` repassando parâmetros para `buscador.sh`.
- Tratamento de caracteres de retorno de carro (`\r` / CRLF) para funcionamento perfeito em Windows (Git Bash), Linux e macOS.

---

## 💻 Pré-requisitos & Instalação

- **Ambiente:** Linux, macOS ou Windows (via Git Bash ou WSL).
- **Ferramentas necessárias:**
  - `bash` (versão 4 ou superior)
  - `curl`
  - `jq` (processador JSON)

> **Dica (Windows):** No Windows com Git Bash, o `jq` pode ser instalado facilmente via Chocolatey (`choco install jq`), Winget (`winget install jqlang.jq`) ou baixando o executável `jq.exe` para o PATH.

---

## 📋 Como Executar & Exemplos de Uso

### Permissão de execução (se necessário):
```bash
chmod +x buscador.sh tse-top-candidates.sh
```

### 1. Exibir manual de ajuda:
```bash
./buscador.sh --help
```

### 2. Listar todos os municípios do Maranhão cadastrados:
```bash
./buscador.sh -l
```

### 3. Consultar resultados de uma cidade por nome (1º e 2º Turnos):
```bash
./buscador.sh -m "Imperatriz"
```

### 4. Consultar apenas o 2º Turno para Presidente em Davinópolis:
```bash
./buscador.sh -m "Davinópolis" -t 2 -c 1
```

### 5. Consultar apenas o 1º Turno em São Luís limitando a 5 candidatos por cargo:
```bash
./buscador.sh -m "São Luís" -t 1 -L 5
```

### 6. Consultar o total consolidado de todo o Estado do Maranhão:
```bash
./buscador.sh -m estado -t 1 -c 3
```

### 7. Utilizar o nome de arquivo alternativo do enunciado:
```bash
./tse-top-candidates.sh -m "Caxias" -t 2 -c 1
```

---

## 🧪 Evidências de Validação

### Teste 1: Consulta do 2º Turno para Presidente em Imperatriz-MA
```text
$ ./buscador.sh -m "Imperatriz" -c 1 -t 2

======================================================================
     RESULTADOS DO 2º TURNO - IMPERATRIZ - ANO 2026     
======================================================================

Presidente (cargo 1 - 2º Turno)
+------------------+---------+-------+--------+-------------+
| NOME             | NÚMERO | VOTOS |      % | SITUAÇÃO  |
+------------------+---------+-------+--------+-------------+
| FLAVIO BOLSONARO |      22 | 84993 | 54,42% | Não eleito |
| LULA             |      13 | 71201 | 45,58% | [ELEITO]    |
+------------------+---------+-------+--------+-------------+
```

### Teste 2: Consulta do 2º Turno em Davinópolis-MA com aviso de Governador
```text
$ ./buscador.sh -m 07242 -t 2

======================================================================
     RESULTADOS DO 2º TURNO - DAVINÓPOLIS - ANO 2026     
======================================================================

Governador (cargo 3): Sem dados de 2º turno para DAVINÓPOLIS (HTTP 404 - eleição decidida em 1º turno ou não realizada).

Presidente (cargo 1 - 2º Turno)
+------------------+---------+-------+--------+-------------+
| NOME             | NÚMERO | VOTOS |      % | SITUAÇÃO  |
+------------------+---------+-------+--------+-------------+
| LULA             |      13 |  5829 | 60,01% | [ELEITO]    |
| FLAVIO BOLSONARO |      22 |  3885 | 39,99% | Não eleito |
+------------------+---------+-------+--------+-------------+
```

### Teste 3: Total Consolidado do Estado do Maranhão para Governador (1º Turno)
```text
$ ./buscador.sh -m estado -c 3 -t 1

======================================================================
     RESULTADOS DO 1º TURNO - ESTADO DO MARANHÃO (TOTAL CONSOLIDADO) - ANO 2026     
======================================================================

Governador (cargo 3 - 1º Turno)
+------------------+---------+---------+--------+-------------+
| NOME             | NÚMERO |   VOTOS |      % | SITUAÇÃO  |
+------------------+---------+---------+--------+-------------+
| EDUARDO BRAIDE   |      55 | 2104122 | 54,02% | [ELEITO]    |
| ORLEANS BRANDÃO |      15 | 1354044 | 34,76% | Não eleito |
| FELIPE CAMARÃO  |      13 |  374039 |  9,60% | Não eleito |
| ROBERTO ROCHA    |      28 |   48924 |  1,26% | Não eleito |
| ANDRÉ LUIS      |      14 |    7905 |  0,20% | Não eleito |
| SAULO ARCANGELI  |      16 |    4693 |  0,12% | Não eleito |
| REGINALDO LIMA   |      21 |    1096 |  0,03% | Não eleito |
| DIMAS CASSIMIRO  |      29 |     257 |  0,01% | Não eleito |
+------------------+---------+---------+--------+-------------+
```

---

## 🔀 Histórico de Commits e Fluxo Git

O desenvolvimento seguiu o fluxo padrão de branches com integração final:

```text
git checkout -b melhoria-xp
# Ciclos 1 ao 6 realizados em commits incrementais
git checkout main
git merge melhoria-xp
git push origin main
git push origin melhoria-xp
```

| Commit | Mensagem do Commit | Responsáveis (XP) |
| :---: | :--- | :---: |
| `c47b0af` | `docs: diagnostico inicial do script e planejamento XP pela dupla` | Guilherme (Driver) / Lucas (Navigator) |
| `e54dbd0` | `feat: indicar claramente candidatos eleitos e status na tabela de resultados` | Lucas (Driver) / Guilherme (Navigator) |
| `4195857` | `feat: permitir consultar e apresentar separadamente o 1º e 2º turnos` | Guilherme (Driver) / Lucas (Navigator) |
| `8413eff` | `feat: suportar todos os 217 municipios do Maranhao e busca por nome ou codigo` | Lucas (Driver) / Guilherme (Navigator) |
| `bf410a8` | `refactor: adicionar interface CLI completa, tratamento de erros e script compativel` | Guilherme (Driver) / Lucas (Navigator) |
| `[HEAD]`  | `docs: documentar guia completo, evidencias de testes e conclusao XP no README` | Lucas (Driver) / Guilherme (Navigator) |

---

## 📌 Checklist de Atendimento dos Critérios do Trabalho

- [x] **Repositório forkado do projeto fornecido:** `GuilhermeTeles3245/Web_Crawler_Eleicao_2026`
- [x] **Professor adicionado como colaborador:** `thalles_tsc@hotmail.com` (ThallesCanela)
- [x] **Branch de trabalho criada:** `melhoria-xp`
- [x] **Diagnóstico inicial documentado antes das alterações de código**
- [x] **Requisito 1:** Suporte a todas as cidades/municípios do Maranhão (busca por nome, código, listagem e iteração global)
- [x] **Requisito 2:** Consulta e apresentação separada do 1º e 2º turnos
- [x] **Requisito 3:** Indicação clara e visual dos candidatos eleitos (`[ELEITO]` e `➜ 2º TURNO`)
- [x] **Requisito 4:** Correção de problemas, melhorias de legibilidade, interface CLI e tratamento de erros
- [x] **Práticas de XP:** Pair programming comprovado com alternância Driver/Navigator e commits incrementais
- [x] **Merge na `main`:** Versão final validada e executável na branch principal
