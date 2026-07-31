#!/usr/bin/env bash
# Sincroniza dist/ al bucket del ambiente e invalida CloudFront.
# Uso: deploy.sh <bucket> <distribution_id>
set -euo pipefail

BUCKET="${1:?falta el nombre del bucket}"
DISTRIBUTION_ID="${2:?falta el distribution id de CloudFront}"
DIST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/dist"

if [[ ! -d "${DIST_DIR}" ]]; then
  echo "No existe ${DIST_DIR}. Corre 'make build' primero." >&2
  exit 1
fi

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
