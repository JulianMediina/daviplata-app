#!/usr/bin/env bash
# Empaqueta dist/ y lo publica como un GitHub Release, usando el commit SHA
# como identificador — el mismo asset que luego se descarga sin reconstruir
# en cada ambiente. Requiere GH_TOKEN (o GITHUB_TOKEN) con permiso
# contents:write, ya presente en el contexto del workflow.
# Uso: publish.sh <commit_sha> <repo owner/name>
set -euo pipefail

COMMIT_SHA="${1:?falta el commit SHA}"
REPO="${2:?falta el repo (owner/name)}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARTIFACT_NAME="site-${COMMIT_SHA}.tar.gz"
ARTIFACT_PATH="${ROOT_DIR}/${ARTIFACT_NAME}"
TAG="build-${COMMIT_SHA}"

echo "==> Empaquetando dist/ como ${ARTIFACT_NAME}"
tar -czf "${ARTIFACT_PATH}" -C "${ROOT_DIR}/dist" .

echo "==> Publicando release ${TAG} en ${REPO}"
gh release create "${TAG}" "${ARTIFACT_PATH}" \
  --repo "${REPO}" \
  --target "${COMMIT_SHA}" \
  --title "build ${COMMIT_SHA}" \
  --notes "Bundle inmutable generado por release-deploy.yml para el commit ${COMMIT_SHA}."

echo "==> Publicado: ${TAG} (${ARTIFACT_NAME})"
