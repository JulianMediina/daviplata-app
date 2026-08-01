#!/usr/bin/env bash
# Restaura la última versión estable conocida: descarga el bundle marcado
# como estable desde el GitHub Release correspondiente y lo vuelve a
# sincronizar al bucket del ambiente.
# Uso: rollback.sh <bucket> <distribution_id> <repo owner/name> <ambiente>
set -euo pipefail

BUCKET="${1:?falta el nombre del bucket}"
DISTRIBUTION_ID="${2:?falta el distribution id de CloudFront}"
REPO="${3:?falta el repo (owner/name)}"
ENVIRONMENT="${4:?falta el ambiente (integracion|laboratorio|produccion)}"

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
TAG="build-${STABLE_SHA}"

echo "==> Descargando release ${TAG} de ${REPO}"
gh release download "${TAG}" --repo "${REPO}" --pattern "site-*.tar.gz" --dir "${WORK_DIR}"

mkdir -p "${WORK_DIR}/extracted"
tar -xzf "${WORK_DIR}"/site-*.tar.gz -C "${WORK_DIR}/extracted"

echo "==> Ajustando config.json y version.json al ambiente ${ENVIRONMENT}"
cp "${ROOT_DIR}/config/config.${ENVIRONMENT}.json" "${WORK_DIR}/extracted/config.json"
tmp_version="$(mktemp)"
sed "s/\"environment\": \"[^\"]*\"/\"environment\": \"${ENVIRONMENT}\"/" "${WORK_DIR}/extracted/version.json" > "${tmp_version}"
mv "${tmp_version}" "${WORK_DIR}/extracted/version.json"

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
