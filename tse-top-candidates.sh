#!/usr/bin/env bash
# Wrapper para compatibilidade com o enunciado da atividade prática
# Repassa todos os parâmetros diretamente para o buscador.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/buscador.sh" "$@"
