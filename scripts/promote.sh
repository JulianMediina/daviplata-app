#!/usr/bin/env bash
# Marca en las notas del release que una versión avanzó a un ambiente.
# No mueve ni copia el artefacto (nunca se reconstruye): resuelve qué
# versión semántica corresponde al commit dado (el tag vX.Y.Z que
# publish.sh dejó apuntando exactamente a ese commit) y solo actualiza
# las notas del release para dejar rastro de auditoría.
# Uso: promote.sh <commit_sha> <repo owner/name> <ambiente_destino>
set -euo pipefail

COMMIT_SHA="${1:?falta el commit SHA}"
REPO="${2:?falta el repo (owner/name)}"
TO_ENV="${3:?falta el ambiente destino}"
TIMESTAMP="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

VERSION="$(git tag --points-at "${COMMIT_SHA}" | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | head -1 || true)"

if [[ -z "${VERSION}" ]]; then
  echo "promote: no encontré un tag de versión (vX.Y.Z) apuntando a ${COMMIT_SHA}." >&2
  exit 1
fi

CURRENT_NOTES="$(gh release view "${VERSION}" --repo "${REPO}" --json body -q .body)"

echo "==> Marcando ${VERSION} (${COMMIT_SHA}) como promovido a ${TO_ENV}"
gh release edit "${VERSION}" --repo "${REPO}" \
  --notes "${CURRENT_NOTES}
- Promovido a ${TO_ENV} (${TIMESTAMP})"

echo "==> Promoción registrada: ${VERSION} -> ${TO_ENV}"
echo "${VERSION}"
