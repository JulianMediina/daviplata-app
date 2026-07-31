#!/usr/bin/env bash
# Marca en las notas del release que el artefacto avanzó a un ambiente.
# A diferencia de un registro con repos por ambiente, un GitHub Release es
# una sola ubicación global — "promover" no mueve ni copia el archivo
# (nunca se reconstruye), solo deja el rastro de auditoría de por dónde
# ha pasado.
# Uso: promote.sh <commit_sha> <repo owner/name> <ambiente_destino>
set -euo pipefail

COMMIT_SHA="${1:?falta el commit SHA}"
REPO="${2:?falta el repo (owner/name)}"
TO_ENV="${3:?falta el ambiente destino}"
TAG="build-${COMMIT_SHA}"
TIMESTAMP="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

CURRENT_NOTES="$(gh release view "${TAG}" --repo "${REPO}" --json body -q .body)"

echo "==> Marcando ${TAG} como promovido a ${TO_ENV}"
gh release edit "${TAG}" --repo "${REPO}" \
  --notes "${CURRENT_NOTES}
- Promovido a ${TO_ENV} (${TIMESTAMP})"

echo "==> Promoción registrada"
