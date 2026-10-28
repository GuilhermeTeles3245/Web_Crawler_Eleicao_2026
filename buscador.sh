#!/usr/bin/env bash
set -Eeuo pipefail

readonly DEFAULT_BASE_URL="https://resultados.tse.jus.br/oficial"
readonly -a CARGOS=(6 7 5 3 1)

BASE_URL="${TSE_RESULTS_BASE_URL:-$DEFAULT_BASE_URL}"
YEAR="${TSE_RESULTS_YEAR:-2026}"
UF="${TSE_RESULTS_UF:-ma}"
MUNICIPIO="${TSE_RESULTS_MUNICIPALITY:-07242}"
LIMIT="${TSE_RESULTS_LIMIT:-20}"
FEDERAL_ELECTION="${TSE_RESULTS_FEDERAL_ELECTION:-6257}"
STATE_ELECTION="${TSE_RESULTS_STATE_ELECTION:-6259}"
COLOR_MODE="${TSE_RESULTS_COLOR:-auto}"

die() { printf 'Erro: %s\n' "$*" >&2; exit 1; }
command -v curl >/dev/null || die "curl não encontrado"
command -v jq >/dev/null || die "jq não encontrado"
[[ "$UF" =~ ^[[:alpha:]]{2}$ ]] || die "TSE_RESULTS_UF deve conter duas letras"
[[ "$MUNICIPIO" =~ ^[0-9]{5}$ ]] || die "TSE_RESULTS_MUNICIPALITY deve conter cinco dígitos"
[[ "$YEAR" =~ ^[0-9]{4}$ ]] || die "TSE_RESULTS_YEAR deve conter quatro dígitos"
[[ "$LIMIT" =~ ^[1-9][0-9]*$ ]] || die "TSE_RESULTS_LIMIT deve ser um inteiro positivo"
[[ "$FEDERAL_ELECTION" =~ ^[0-9]+$ && "$STATE_ELECTION" =~ ^[0-9]+$ ]] || die "códigos de eleição devem ser numéricos"
[[ "$COLOR_MODE" =~ ^(auto|always|never)$ ]] || die "TSE_RESULTS_COLOR deve ser auto, always ou never"

UF="${UF,,}"
BASE_URL="${BASE_URL%/}"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

use_color=false
if [[ "$COLOR_MODE" == always ]] || { [[ "$COLOR_MODE" == auto && -t 1 && "${TERM:-dumb}" != dumb ]] && [[ ! -v NO_COLOR ]]; }; then
  use_color=true
fi

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

TURNO="${TSE_RESULTS_TURNO:-todos}"
FEDERAL_ELECTION_1T="${TSE_RESULTS_FEDERAL_ELECTION_1T:-6257}"
STATE_ELECTION_1T="${TSE_RESULTS_STATE_ELECTION_1T:-6259}"
FEDERAL_ELECTION_2T="${TSE_RESULTS_FEDERAL_ELECTION_2T:-6258}"
STATE_ELECTION_2T="${TSE_RESULTS_STATE_ELECTION_2T:-6260}"

consultar_turno() {
  local t="$1"
  local fed_election state_election
  local -a cargos_turno

  if [[ "$t" == "1" ]]; then
    fed_election="$FEDERAL_ELECTION_1T"
    state_election="$STATE_ELECTION_1T"
    cargos_turno=("${CARGOS[@]}")
  elif [[ "$t" == "2" ]]; then
    fed_election="$FEDERAL_ELECTION_2T"
    state_election="$STATE_ELECTION_2T"
    # No 2º turno, apenas cargos do executivo participam
    cargos_turno=(3 1)
  else
    die "turno inválido: $t (use 1, 2 ou todos)"
  fi

  printf '\n'
  if $use_color; then
    printf '\033[1;34m======================================================================\033[0m\n'
    printf '\033[1;37;44m                   RESULTADOS DO %sº TURNO - ANO %s                 \033[0m\n' "$t" "$YEAR"
    printf '\033[1;34m======================================================================\033[0m\n'
  else
    printf '======================================================================\n'
    printf '                   RESULTADOS DO %sº TURNO - ANO %s                 \n' "$t" "$YEAR"
    printf '======================================================================\n'
  fi

  for cargo in "${cargos_turno[@]}"; do
    local election
    case "$cargo" in
      1) election="$fed_election" ;;
      3|5|6|7) election="$state_election" ;;
      *) continue ;;
    esac

    local file="$tmp_dir/turno-$t-cargo-$cargo.json"
    local cargo_padded election_padded
    printf -v cargo_padded '%04d' "$cargo"
    printf -v election_padded '%06d' "$election"
    local url="$BASE_URL/ele$YEAR/$election/dados/$UF/${UF}${MUNICIPIO}-c${cargo_padded}-e${election_padded}-u.json"

    local http_code
    http_code=$(curl --silent --show-error --location \
      --write-out '%{http_code}' \
      --retry 2 --connect-timeout 8 --max-time 25 \
      --output "$file" "$url" 2>/dev/null || echo "000")

    if [[ "$http_code" != "200" ]]; then
      if [[ "$t" == "2" ]]; then
        local desc_cargo="Cargo $cargo"
        [[ "$cargo" == "3" ]] && desc_cargo="Governador"
        [[ "$cargo" == "1" ]] && desc_cargo="Presidente"
        printf '\n%s: Sem dados de 2º turno disponíveis para este município (HTTP %s).\n' "$desc_cargo" "$http_code"
      else
        printf '\nCargo %s: Consulta não retornou dados para este município (HTTP %s).\n' "$cargo" "$http_code"
      fi
      continue
    fi

    if ! jq -e '.carg | type == "array"' "$file" >/dev/null 2>&1; then
      printf '\nCargo %s: Resposta retornou estrutura incompatível.\n' "$cargo"
      continue
    fi

    local cargo_name
    cargo_name="$(jq -r --arg cargo "$cargo" '.carg[] | select(.cd == $cargo) | .nmn' "$file" 2>/dev/null | head -n 1)"
    [[ -z "$cargo_name" || "$cargo_name" == "null" ]] && cargo_name="Cargo $cargo"

    printf '\n%s (cargo %s - %sº Turno)\n' "$cargo_name" "$cargo" "$t"
    local rows_file="$tmp_dir/turno-$t-cargo-$cargo.tsv"
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

case "${TURNO,,}" in
  1) consultar_turno 1 ;;
  2) consultar_turno 2 ;;
  todos|ambos|"")
    consultar_turno 1
    consultar_turno 2
    ;;
  *) die "Turno inválido: $TURNO (informe 1, 2 ou todos)" ;;
esac