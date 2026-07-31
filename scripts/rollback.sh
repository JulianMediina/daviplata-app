#!/usr/bin/env bash
# Restaura la última versión estable conocida: descarga el bundle marcado
# como estable desde JFrog y lo vuelve a sincronizar al bucket del ambiente.
# Requiere JFROG_URL, JFROG_USER, JFROG_TOKEN, JFROG_REPO en el entorno.
# Uso: rollback.sh <bucket> <distribution_id>
set -euo pipefail

BUCKET="${1:?falta el nombre del bucket}"
DISTRIBUTION_ID="${2:?falta el distribution id de CloudFront}"
: "${JFROG_URL:?falta JFROG_URL}"
: "${JFROG_USER:?falta JFROG_USER}"
: "${JFROG_TOKEN:?falta JFROG_TOKEN}"
: "${JFROG_REPO:?falta JFROG_REPO}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "${WORK_DIR}"' EXIT

echo "==> Leyendo puntero de última versión estable en s3://${BUCKET}/_meta/stable.txt"
STABLE_SHA=$(aws s3 cp "s3://${BUCKET}/_meta/stable.txt" - 2>/dev/null || true)

if [[ -z "${STABLE_SHA}" ]]; then
  echo "rollback: no hay una versión estable previa registrada en ${BUCKET}. Rollback abortado." >&2
  exit 1
fi

echo "==> Última versión estable: ${STABLE_SHA}"
ARTIFACT_NAME="site-${STABLE_SHA}.tar.gz"

echo "==> Descargando ${ARTIFACT_NAME} desde JFrog"
curl --fail --silent --show-error \
  -u "${JFROG_USER}:${JFROG_TOKEN}" \
  -o "${WORK_DIR}/${ARTIFACT_NAME}" \
  "${JFROG_URL}/${JFROG_REPO}/${ARTIFACT_NAME}"

mkdir -p "${WORK_DIR}/extracted"
tar -xzf "${WORK_DIR}/${ARTIFACT_NAME}" -C "${WORK_DIR}/extracted"

echo "==> Restaurando en s3://${BUCKET}"
aws s3 sync "${WORK_DIR}/extracted" "s3://${BUCKET}" \
  --delete \
  --exclude "_meta/*" \
  --cache-control "public, max-age=300"

echo "==> Invalidando CloudFront (${DISTRIBUTION_ID})"
aws cloudfront create-invalidation \
  --distribution-id "${DISTRIBUTION_ID}" \
  --paths "/*" \
  --query "Invalidation.Id" \
  --output text

echo "==> Rollback completado a la versión ${STABLE_SHA}"

INCIDENT_LOG="${ROOT_DIR}/docs/evidence/rollback/incident-$(date -u +%Y%m%dT%H%M%SZ).log"
mkdir -p "$(dirname "${INCIDENT_LOG}")"
{
  echo "timestamp_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "bucket=${BUCKET}"
  echo "distribution_id=${DISTRIBUTION_ID}"
  echo "restored_commit=${STABLE_SHA}"
} > "${INCIDENT_LOG}"

echo "==> Registro de incidente: ${INCIDENT_LOG}"
