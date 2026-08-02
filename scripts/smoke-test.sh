#!/usr/bin/env bash
# Verifica /, /health.json y /version.json con reintentos y timeout.
# Si se pasa un tercer argumento, valida que version.json.commit coincida.
# Uso: smoke-test.sh <base_url> [expected_commit] [max_attempts] [timeout_seconds]
set -euo pipefail

BASE_URL="${1:?falta la URL base, ej. https://daviplata-integracion.us-east-1.on.aws}"
EXPECTED_COMMIT="${2:-}"
MAX_ATTEMPTS="${3:-5}"
REQUEST_TIMEOUT="${4:-10}"
SLEEP_SECONDS=5

fetch_with_retries() {
  local path="$1"
  local attempt=1

  while (( attempt <= MAX_ATTEMPTS )); do
    if response=$(curl --fail --silent --show-error --max-time "${REQUEST_TIMEOUT}" "${BASE_URL}${path}"); then
      echo "${response}"
      return 0
    fi

    echo "intento ${attempt}/${MAX_ATTEMPTS} falló para ${path}, reintentando en ${SLEEP_SECONDS}s..." >&2
    sleep "${SLEEP_SECONDS}"
    attempt=$((attempt + 1))
  done

  echo "smoke test: ${path} no respondió tras ${MAX_ATTEMPTS} intentos" >&2
  return 1
}

echo "==> Verificando /"
fetch_with_retries "/" > /dev/null

echo "==> Verificando /health.json"
health=$(fetch_with_retries "/health.json")
status=$(echo "${health}" | grep -o '"status"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*"\([^"]*\)"$/\1/')

if [[ "${status}" != "ok" ]]; then
  echo "smoke test: health.json.status esperado 'ok', obtenido '${status}'" >&2
  exit 1
fi

echo "==> Verificando /version.json"
version_json=$(fetch_with_retries "/version.json")
commit=$(echo "${version_json}" | grep -o '"commit"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*"\([^"]*\)"$/\1/')

if [[ -n "${EXPECTED_COMMIT}" && "${commit}" != "${EXPECTED_COMMIT}" ]]; then
  echo "smoke test: version.json.commit esperado '${EXPECTED_COMMIT}', obtenido '${commit}'" >&2
  exit 1
fi

echo "==> Smoke test OK (commit=${commit})"
