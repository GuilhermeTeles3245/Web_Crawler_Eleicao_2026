#!/usr/bin/env bash
# ==============================================================================
# Web Crawler - Eleições Oficiais TSE (Maranhão)
# Atividade Prática: Manifesto Ágil e Extreme Programming (XP)
# Dupla: Guilherme Teles Pacheco & Lucas Paixão Cardoso Luis
# Disciplina: Engenharia de Software - UNIFACIMP Wyden
# ==============================================================================
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MUNICIPIOS_FILE="$SCRIPT_DIR/municipios_ma.tsv"

readonly DEFAULT_BASE_URL="https://resultados.tse.jus.br/oficial"
readonly -a DEFAULT_CARGOS=(6 7 5 3 1)

BASE_URL="${TSE_RESULTS_BASE_URL:-$DEFAULT_BASE_URL}"
YEAR="${TSE_RESULTS_YEAR:-2026}"
UF="${TSE_RESULTS_UF:-ma}"
MUNICIPIO_PARAM="${TSE_RESULTS_MUNICIPALITY:-07242}"
LIMIT="${TSE_RESULTS_LIMIT:-20}"
TURNO="${TSE_RESULTS_TURNO:-todos}"
COLOR_MODE="${TSE_RESULTS_COLOR:-auto}"
CARGO_FILTRO="${TSE_RESULTS_CARGO:-}"

FEDERAL_ELECTION_1T="${TSE_RESULTS_FEDERAL_ELECTION_1T:-6257}"
STATE_ELECTION_1T="${TSE_RESULTS_STATE_ELECTION_1T:-6259}"
FEDERAL_ELECTION_2T="${TSE_RESULTS_FEDERAL_ELECTION_2T:-6258}"
STATE_ELECTION_2T="${TSE_RESULTS_STATE_ELECTION_2T:-6260}"

MODO_TODOS=false
MODO_LISTAR=false

die() { printf 'Erro: %s\n' "$*" >&2; exit 1; }

exibir_ajuda() {
  cat <<'EOF'
Uso: ./buscador.sh [OPÇÕES]

Crawler para consulta de resultados de apuração do TSE para o Maranhão.
Desenvolvido com práticas de Extreme Programming (XP) e princípios do Manifesto Ágil.

OPÇÕES:
  -m, --municipio <NOME|CÓDIGO>  Nome ou código TSE (5 dígitos) do município
                                 (ex: "Imperatriz", "São Luís", 07242, "estado")
  -t, --turno <1|2|todos>        Turno da eleição a consultar (padrão: todos)
  -c, --cargo <NÚMERO>           Filtra por cargo específico:
                                   1: Presidente
                                   3: Governador
                                   5: Senador
                                   6: Deputado Federal
                                   7: Deputado Estadual
  -a, --todos-municipios         Consulta os resultados para todas as 217 cidades do Maranhão
  -l, --listar, --municipios     Lista todos os 217 municípios do Maranhão com seus códigos
  -L, --limite <NÚMERO>          Limite de candidatos por tabela (padrão: 20)
  --cor <auto|always|never>      Modo de coloração da saída (padrão: auto)
  -h, --help, --ajuda            Exibe esta mensagem de ajuda

EXEMPLOS DE USO:
  ./buscador.sh -m "Imperatriz" -t 1
  ./buscador.sh -m "São Luís" -t 2
  ./buscador.sh -m 07242 -t todos
  ./buscador.sh -m estado -t 1
  ./buscador.sh -l
  ./buscador.sh --todos-municipios -c 1 -t 2
EOF
  exit 0
}

# ------------------------------------------------------------------------------
# Processamento de Parâmetros de Linha de Comando (CLI)
# ------------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help|--ajuda) exibir_ajuda ;;
    -l|--listar|--municipios) MODO_LISTAR=true; shift ;;
    -a|--todos|--todos-municipios) MODO_TODOS=true; shift ;;
    -m|--municipio)
      [[ $# -ge 2 ]] || die "A opção $1 requer um argumento (nome ou código)"
      MUNICIPIO_PARAM="$2"; shift 2 ;;
    -t|--turno)
      [[ $# -ge 2 ]] || die "A opção $1 requer um argumento (1, 2 ou todos)"
      TURNO="$2"; shift 2 ;;
    -c|--cargo)
      [[ $# -ge 2 ]] || die "A opção $1 requer o código do cargo (ex: 1, 3, 5, 6, 7)"
      CARGO_FILTRO="$2"; shift 2 ;;
    -L|--limite)
      [[ $# -ge 2 ]] || die "A opção $1 requer um valor numérico positivo"
      LIMIT="$2"; shift 2 ;;
    --cor)
      [[ $# -ge 2 ]] || die "A opção $1 requer: auto, always ou never"
      COLOR_MODE="$2"; shift 2 ;;
    *) die "Opção desconhecida: $1. Use --help para ver as opções válidas." ;;
  esac
done

command -v curl >/dev/null || die "curl não encontrado no sistema"
command -v jq >/dev/null || die "jq não encontrado no sistema (instale via apt, choco ou winget)"
[[ "$UF" =~ ^[[:alpha:]]{2}$ ]] || die "UF deve conter exatamente duas letras (ex: ma)"
[[ "$YEAR" =~ ^[0-9]{4}$ ]] || die "Ano deve conter quatro dígitos (ex: 2026)"
[[ "$LIMIT" =~ ^[1-9][0-9]*$ ]] || die "Limite deve ser um inteiro positivo"
[[ "$COLOR_MODE" =~ ^(auto|always|never)$ ]] || die "Modo de cor deve ser auto, always ou never"

UF="${UF,,}"
BASE_URL="${BASE_URL%/}"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

use_color=false
if [[ "$COLOR_MODE" == always ]] || { [[ "$COLOR_MODE" == auto && -t 1 && "${TERM:-dumb}" != dumb ]] && [[ ! -v NO_COLOR ]]; }; then
  use_color=true
fi

# ------------------------------------------------------------------------------
# Gestão e Resolução de Municípios do Maranhão
# ------------------------------------------------------------------------------
listar_municipios() {
  if [[ ! -f "$MUNICIPIOS_FILE" ]]; then
    die "Arquivo de municípios não encontrado: $MUNICIPIOS_FILE"
  fi
  local total
  total=$(wc -l <"$MUNICIPIOS_FILE" | tr -d ' ')
  printf 'Municípios cadastrados do Maranhão (%s municípios disponíveis):\n\n' "$total"
  printf '+-------+------------------------------------------------+\n'
  printf '| CÓD.  | MUNICÍPIO                                      |\n'
  printf '+-------+------------------------------------------------+\n'
  while IFS=$'\t' read -r cd nm; do
    cd="${cd%$'\r'}"
    nm="${nm%$'\r'}"
    [[ -n "$cd" && -n "$nm" ]] || continue
    printf '| %-5s | %-46s |\n' "$cd" "$nm"
  done <"$MUNICIPIOS_FILE"
  printf '+-------+------------------------------------------------+\n'
  exit 0
}

resolver_municipio() {
  local query="$1"
  # Trim
  query="${query#"${query%%[![:space:]]*}"}"
  query="${query%"${query##*[![:space:]]}"}"

  if [[ "$query" == "todos" || "$query" == "all" || "$query" == "todas" ]]; then
    RESOLVED_COD="TODOS"
    RESOLVED_NAME="TODOS OS MUNICÍPIOS DO MARANHÃO"
    return 0
  fi

  if [[ "$query" == "estado" || "$query" == "ma" || "$query" == "geral" || -z "$query" ]]; then
    RESOLVED_COD=""
    RESOLVED_NAME="ESTADO DO MARANHÃO (TOTAL CONSOLIDADO)"
    return 0
  fi

  if [[ ! -f "$MUNICIPIOS_FILE" ]]; then
    if [[ "$query" =~ ^[0-9]{5}$ ]]; then
      RESOLVED_COD="$query"
      RESOLVED_NAME="Município $query"
      return 0
    else
      die "Lista de municípios ($MUNICIPIOS_FILE) não encontrada para busca textual."
    fi
  fi

  # 1. Se for código numérico de 5 dígitos
  if [[ "$query" =~ ^[0-9]{5}$ ]]; then
    local match
    match=$(grep -m 1 "^$query"$'\t' "$MUNICIPIOS_FILE" 2>/dev/null || true)
    if [[ -n "$match" ]]; then
      RESOLVED_COD="$query"
      RESOLVED_NAME="$(cut -f2 <<<"$match" | tr -d '\r')"
      return 0
    else
      RESOLVED_COD="$query"
      RESOLVED_NAME="Município $query"
      return 0
    fi
  fi

  # 2. Busca ultra-rápida em pure bash usando nome e coluna normalizada
  local q_lower="${query,,}"
  local matches=()

  while IFS=$'\t' read -r cd nm norm; do
    cd="${cd%$'\r'}"
    nm="${nm%$'\r'}"
    norm="${norm%$'\r'}"
    local nm_lower="${nm,,}"

    if [[ "$nm_lower" == "$q_lower" || "$norm" == "$q_lower" ]]; then
      RESOLVED_COD="$cd"
      RESOLVED_NAME="$nm"
      return 0
    elif [[ "$nm_lower" == *"$q_lower"* || "$norm" == *"$q_lower"* ]]; then
      matches+=("$cd"$'\t'"$nm")
    fi
  done <"$MUNICIPIOS_FILE"

  if (( ${#matches[@]} == 1 )); then
    IFS=$'\t' read -r RESOLVED_COD RESOLVED_NAME <<<"${matches[0]}"
    return 0
  elif (( ${#matches[@]} > 1 )); then
    # Verifica se algum começa exatamente com o termo buscado
    for m in "${matches[@]}"; do
      IFS=$'\t' read -r cd nm <<<"$m"
      local nm_lower="${nm,,}"
      if [[ "$nm_lower" == "$q_lower "* || "$nm_lower" == "$q_lower" ]]; then
        RESOLVED_COD="$cd"
        RESOLVED_NAME="$nm"
        return 0
      fi
    done

    printf 'Erro: Consulta ambígua para "%s". Cidades encontradas:\n' "$query" >&2
    for m in "${matches[@]}"; do
      IFS=$'\t' read -r cd nm <<<"$m"
      printf '  - %s (Código TSE: %s)\n' "$nm" "$cd" >&2
    done
    die "Por favor, especifique o código de 5 dígitos ou o nome completo."
  fi

  die "Município '$query' não encontrado no Maranhão. Use -l para listar todas as cidades disponíveis."
}

# ------------------------------------------------------------------------------
# Funções de Formatação de Tabelas e Resultados
# ------------------------------------------------------------------------------
readonly name_header="NOME" number_header="NÚMERO" votes_header="VOTOS" pct_header="%" status_header="SITUAÇÃO"

print_rule() {
  local name_width="$1" number_width="$2" votes_width="$3" pct_width="$4" status_width="$5"
  printf '+-%*s-+-%*s-+-%*s-+-%*s-+-%*s-+\n' \
    "$name_width" '' "$number_width" '' "$votes_width" '' "$pct_width" '' "$status_width" '' | tr ' ' '-'
}

print_table() {
  local -n table_rows="$1"
  local name_width=${#name_header} number_width=${#number_header} votes_width=${#votes_header}
  local pct_width=${#pct_header} status_width=${#status_header}
  local row name number votes pct situacao eleito
  local clean_status

  for row in "${table_rows[@]}"; do
    row="${row%$'\r'}"
    IFS=$'\t' read -r name number votes pct situacao eleito <<<"$row"
    eleito="${eleito%$'\r'}"
    clean_status="$situacao"
    if [[ "$situacao" == *"2º turno"* || "$situacao" == *"2o turno"* ]]; then
      clean_status="➜ 2º TURNO"
    elif [[ "$eleito" == "s" || "$situacao" == "Eleito" ]]; then
      if [[ "$situacao" != "-" && "$situacao" != "Eleito" ]]; then
        clean_status="[ELEITO] $situacao"
      else
        clean_status="[ELEITO]"
      fi
    fi
    (( ${#name} > name_width )) && name_width=${#name}
    (( ${#number} > number_width )) && number_width=${#number}
    (( ${#votes} > votes_width )) && votes_width=${#votes}
    (( ${#pct} > pct_width )) && pct_width=${#pct}
    (( ${#clean_status} > status_width )) && status_width=${#clean_status}
  done

  print_rule "$name_width" "$number_width" "$votes_width" "$pct_width" "$status_width"
  printf '| %-*s | %*s | %*s | %*s | %-*s |\n' \
    "$name_width" "$name_header" "$number_width" "$number_header" "$votes_width" "$votes_header" "$pct_width" "$pct_header" "$status_width" "$status_header"
  print_rule "$name_width" "$number_width" "$votes_width" "$pct_width" "$status_width"

  for row in "${table_rows[@]}"; do
    row="${row%$'\r'}"
    IFS=$'\t' read -r name number votes pct situacao eleito <<<"$row"
    eleito="${eleito%$'\r'}"
    clean_status="$situacao"
    local is_eleito=false is_2t=false
    if [[ "$situacao" == *"2º turno"* || "$situacao" == *"2o turno"* ]]; then
      clean_status="➜ 2º TURNO"
      is_2t=true
    elif [[ "$eleito" == "s" || "$situacao" == "Eleito" ]]; then
      if [[ "$situacao" != "-" && "$situacao" != "Eleito" ]]; then
        clean_status="[ELEITO] $situacao"
      else
        clean_status="[ELEITO]"
      fi
      is_eleito=true
    fi

    if $use_color; then
      if $is_eleito; then
        printf '| \033[1;32m%-*s\033[0m | %*s | \033[1;32m%*s\033[0m | %*s | \033[1;32m%-*s\033[0m |\n' \
          "$name_width" "$name" "$number_width" "$number" "$votes_width" "$votes" "$pct_width" "$pct" "$status_width" "$clean_status"
      elif $is_2t; then
        printf '| \033[1;33m%-*s\033[0m | %*s | \033[1;33m%*s\033[0m | %*s | \033[1;33m%-*s\033[0m |\n' \
          "$name_width" "$name" "$number_width" "$number" "$votes_width" "$votes" "$pct_width" "$pct" "$status_width" "$clean_status"
      else
        printf '| \033[36m%-*s\033[0m | %*s | \033[32m%*s\033[0m | %*s | \033[90m%-*s\033[0m |\n' \
          "$name_width" "$name" "$number_width" "$number" "$votes_width" "$votes" "$pct_width" "$pct" "$status_width" "$clean_status"
      fi
    else
      printf '| %-*s | %*s | %*s | %*s | %-*s |\n' \
        "$name_width" "$name" "$number_width" "$number" "$votes_width" "$votes" "$pct_width" "$pct" "$status_width" "$clean_status"
    fi
  done
  print_rule "$name_width" "$number_width" "$votes_width" "$pct_width" "$status_width"
}

# ------------------------------------------------------------------------------
# Execução da Consulta de Resultados
# ------------------------------------------------------------------------------
consultar_turno_municipio() {
  local t="$1"
  local mun_cod="$2"
  local mun_nome="$3"
  local fed_election state_election
  local -a cargos_turno

  if [[ "$t" == "1" ]]; then
    fed_election="$FEDERAL_ELECTION_1T"
    state_election="$STATE_ELECTION_1T"
    if [[ -n "$CARGO_FILTRO" ]]; then
      cargos_turno=("$CARGO_FILTRO")
    else
      cargos_turno=("${DEFAULT_CARGOS[@]}")
    fi
  elif [[ "$t" == "2" ]]; then
    fed_election="$FEDERAL_ELECTION_2T"
    state_election="$STATE_ELECTION_2T"
    if [[ -n "$CARGO_FILTRO" ]]; then
      cargos_turno=("$CARGO_FILTRO")
    else
      cargos_turno=(3 1)
    fi
  else
    die "Turno inválido: $t (use 1, 2 ou todos)"
  fi

  printf '\n'
  if $use_color; then
    printf '\033[1;34m======================================================================\033[0m\n'
    printf '\033[1;37;44m     RESULTADOS DO %sº TURNO - %s - ANO %s     \033[0m\n' "$t" "$mun_nome" "$YEAR"
    printf '\033[1;34m======================================================================\033[0m\n'
  else
    printf '======================================================================\n'
    printf '     RESULTADOS DO %sº TURNO - %s - ANO %s     \n' "$t" "$mun_nome" "$YEAR"
    printf '======================================================================\n'
  fi

  for cargo in "${cargos_turno[@]}"; do
    local election
    case "$cargo" in
      1) election="$fed_election" ;;
      3|5|6|7) election="$state_election" ;;
      *) printf '\nCargo %s não suportado.\n' "$cargo"; continue ;;
    esac

    local cargo_padded election_padded
    printf -v cargo_padded '%04d' "$cargo"
    printf -v election_padded '%06d' "$election"

    local url
    if [[ -z "$mun_cod" ]]; then
      # Consolidado estadual do Maranhão
      url="$BASE_URL/ele$YEAR/$election/dados/$UF/${UF}-c${cargo_padded}-e${election_padded}-u.json"
    else
      # Município específico do Maranhão
      url="$BASE_URL/ele$YEAR/$election/dados/$UF/${UF}${mun_cod}-c${cargo_padded}-e${election_padded}-u.json"
    fi

    local file="$tmp_dir/t${t}_m${mun_cod}_c${cargo}.json"
    local http_code
    http_code=$(curl --silent --show-error --location \
      --write-out '%{http_code}' \
      --retry 2 --connect-timeout 8 --max-time 25 \
      --output "$file" "$url" 2>/dev/null || echo "000")

    if [[ "$http_code" != "200" ]]; then
      if [[ "$t" == "2" ]]; then
        local desc_cargo="Cargo $cargo"
        [[ "$cargo" == "3" ]] && desc_cargo="Governador (cargo 3)"
        [[ "$cargo" == "1" ]] && desc_cargo="Presidente (cargo 1)"
        printf '\n%s: Sem dados de 2º turno para %s (HTTP %s - eleição decidida em 1º turno ou não realizada).\n' "$desc_cargo" "$mun_nome" "$http_code"
      else
        printf '\nCargo %s: Consulta não retornou dados para %s (HTTP %s).\n' "$cargo" "$mun_nome" "$http_code"
      fi
      continue
    fi

    if ! jq -e '.carg | type == "array"' "$file" >/dev/null 2>&1; then
      printf '\nCargo %s: Resposta retornou estrutura inesperada.\n' "$cargo"
      continue
    fi

    local cargo_name
    cargo_name="$(jq -r --arg cargo "$cargo" '.carg[] | select(.cd == $cargo) | .nmn' "$file" 2>/dev/null | head -n 1)"
    [[ -z "$cargo_name" || "$cargo_name" == "null" ]] && cargo_name="Cargo $cargo"

    printf '\n%s (cargo %s - %sº Turno)\n' "$cargo_name" "$cargo" "$t"
    local rows_file="$tmp_dir/t${t}_m${mun_cod}_c${cargo}.tsv"
    jq -r --arg cargo "$cargo" --argjson limit "$LIMIT" '
      [
        .carg[] | select(.cd == $cargo)
        | .. | objects | .cand? // empty | .[]
        | select((.nmu // "") != "" and (.n // "") != "")
        | {
            nome: (.nmu | gsub("[[:cntrl:]]"; " ")),
            numero: .n,
            votos: ((.vap // "0") | tonumber),
            pct: ((.pvap // "0,00") + "%"),
            situacao: (if ((.st // "") | length) > 0 then .st else "-" end),
            eleito: (.e // "n")
          }
      ]
      | unique_by(.numero)
      | sort_by([-.votos, (.nome | ascii_downcase), .numero])
      | .[:$limit][]
      | [.nome, .numero, (.votos | tostring), .pct, .situacao, .eleito] | @tsv
    ' "$file" >"$rows_file"

    mapfile -t rows <"$rows_file"
    if (( ${#rows[@]} > 0 )); then
      print_table rows
    else
      printf 'Nenhum candidato listado para este cargo.\n'
    fi
  done
}

processar_municipio() {
  local cod="$1"
  local nome="$2"

  case "${TURNO,,}" in
    1) consultar_turno_municipio 1 "$cod" "$nome" ;;
    2) consultar_turno_municipio 2 "$cod" "$nome" ;;
    todos|ambos|"")
      consultar_turno_municipio 1 "$cod" "$nome"
      consultar_turno_municipio 2 "$cod" "$nome"
      ;;
    *) die "Turno inválido: $TURNO (informe 1, 2 ou todos)" ;;
  esac
}

# ------------------------------------------------------------------------------
# Ponto de Entrada Principal
# ------------------------------------------------------------------------------
if $MODO_LISTAR; then
  listar_municipios
fi

if $MODO_TODOS; then
  [[ -f "$MUNICIPIOS_FILE" ]] || die "Arquivo $MUNICIPIOS_FILE não encontrado para iterar todos os municípios."
  total_mun=$(wc -l <"$MUNICIPIOS_FILE" | tr -d ' ')
  printf 'Iniciando consulta para todos os %s municípios do Maranhão...\n' "$total_mun"
  i=1
  while IFS=$'\t' read -r cd nm; do
    cd="${cd%$'\r'}"
    nm="${nm%$'\r'}"
    [[ -n "$cd" && -n "$nm" ]] || continue
    printf '\n[%s/%s] Processando: %s (%s)...\n' "$i" "$total_mun" "$nm" "$cd"
    processar_municipio "$cd" "$nm"
    ((i++))
  done <"$MUNICIPIOS_FILE"
  printf '\nProcessamento de todos os municípios concluído com sucesso!\n'
  exit 0
fi

resolver_municipio "$MUNICIPIO_PARAM"

if [[ "$RESOLVED_COD" == "TODOS" ]]; then
  [[ -f "$MUNICIPIOS_FILE" ]] || die "Arquivo $MUNICIPIOS_FILE não encontrado."
  total_mun=$(wc -l <"$MUNICIPIOS_FILE" | tr -d ' ')
  printf 'Iniciando consulta para todos os %s municípios do Maranhão...\n' "$total_mun"
  i=1
  while IFS=$'\t' read -r cd nm; do
    cd="${cd%$'\r'}"
    nm="${nm%$'\r'}"
    [[ -n "$cd" && -n "$nm" ]] || continue
    printf '\n[%s/%s] Processando: %s (%s)...\n' "$i" "$total_mun" "$nm" "$cd"
    processar_municipio "$cd" "$nm"
    ((i++))
  done <"$MUNICIPIOS_FILE"
  printf '\nProcessamento concluído com sucesso!\n'
else
  processar_municipio "$RESOLVED_COD" "$RESOLVED_NAME"
fi