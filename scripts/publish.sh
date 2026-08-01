#!/usr/bin/env bash
# Empaqueta dist/ y lo publica como un GitHub Release con versión semántica
# (calculada por next-version.sh a partir de Conventional Commits). El tag
# de versión se crea apuntando exactamente al commit que se construyó, así
# que scripts/promote.sh y scripts/rollback.sh pueden resolver "qué versión
# corresponde a este commit" con `git tag --points-at` más adelante, sin
# tener que reconstruir nada.
# Requiere GH_TOKEN (o GITHUB_TOKEN) con permiso contents:write.
# Uso: publish.sh <commit_sha> <repo owner/name>
set -euo pipefail

COMMIT_SHA="${1:?falta el commit SHA}"
REPO="${2:?falta el repo (owner/name)}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARTIFACT_NAME="site-${COMMIT_SHA}.tar.gz"
ARTIFACT_PATH="${ROOT_DIR}/${ARTIFACT_NAME}"

echo "==> Empaquetando dist/ como ${ARTIFACT_NAME}"
tar -czf "${ARTIFACT_PATH}" -C "${ROOT_DIR}/dist" .

EXISTING_TAG="$(git tag --points-at "${COMMIT_SHA}" | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | head -1 || true)"

if [[ -n "${EXISTING_TAG}" ]]; then
  echo "==> ${COMMIT_SHA} ya tiene la versión ${EXISTING_TAG} (re-ejecución del pipeline) — no se reconstruye"
  echo "${EXISTING_TAG}"
  exit 0
fi

VERSION="$("${ROOT_DIR}/scripts/next-version.sh" "${COMMIT_SHA}")"

echo "==> Etiquetando ${COMMIT_SHA} como ${VERSION}"
git tag -a "${VERSION}" "${COMMIT_SHA}" -m "Release ${VERSION}"
git push origin "${VERSION}"

echo "==> Publicando release ${VERSION} en ${REPO}"
gh release create "${VERSION}" "${ARTIFACT_PATH}" \
  --repo "${REPO}" \
  --target "${COMMIT_SHA}" \
  --title "DaviPlata ${VERSION}" \
  --notes "Bundle inmutable generado por el pipeline para el commit ${COMMIT_SHA}."

echo "==> Publicado: ${VERSION} (${ARTIFACT_NAME})"
echo "${VERSION}"
