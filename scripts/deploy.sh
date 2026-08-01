#!/usr/bin/env bash
# Sincroniza dist/ al bucket del ambiente e invalida CloudFront.
# El bundle es inmutable y se promueve sin reconstruir, pero config.json y
# version.json.environment SÍ dependen del ambiente de destino — se
# sobrescriben aquí, justo antes del sync, en vez de hornearse en el build.
# Uso: deploy.sh <bucket> <distribution_id> <ambiente>
set -euo pipefail

BUCKET="${1:?falta el nombre del bucket}"
DISTRIBUTION_ID="${2:?falta el distribution id de CloudFront}"
ENVIRONMENT="${3:?falta el ambiente (integracion|laboratorio|produccion)}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="${ROOT_DIR}/dist"
CONFIG_SRC="${ROOT_DIR}/config/config.${ENVIRONMENT}.json"

if [[ ! -d "${DIST_DIR}" ]]; then
  echo "No existe ${DIST_DIR}. Corre 'make build' primero." >&2
  exit 1
fi

if [[ ! -f "${CONFIG_SRC}" ]]; then
  echo "No existe ${CONFIG_SRC}." >&2
  exit 1
fi

echo "==> Ajustando config.json y version.json al ambiente ${ENVIRONMENT}"
cp "${CONFIG_SRC}" "${DIST_DIR}/config.json"
tmp_version="$(mktemp)"
sed "s/\"environment\": \"[^\"]*\"/\"environment\": \"${ENVIRONMENT}\"/" "${DIST_DIR}/version.json" > "${tmp_version}"
mv "${tmp_version}" "${DIST_DIR}/version.json"

echo "==> Sincronizando ${DIST_DIR} -> s3://${BUCKET}"
aws s3 sync "${DIST_DIR}" "s3://${BUCKET}" \
  --delete \
  --exclude "_meta/*" \
  --cache-control "public, max-age=300"

echo "==> Invalidando CloudFront (${DISTRIBUTION_ID})"
INVALIDATION_ID=$(aws cloudfront create-invalidation \
  --distribution-id "${DISTRIBUTION_ID}" \
  --paths "/*" \
  --query "Invalidation.Id" \
  --output text)

echo "==> Invalidación creada: ${INVALIDATION_ID}"
