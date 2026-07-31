#!/usr/bin/env bash
# Empaqueta dist/ y lo publica en JFrog Artifactory bajo el SHA del commit.
# Requiere JFROG_URL, JFROG_USER, JFROG_TOKEN, JFROG_REPO en el entorno.
# Uso: publish.sh <commit_sha>
set -euo pipefail

COMMIT_SHA="${1:?falta el commit SHA}"
: "${JFROG_URL:?falta JFROG_URL}"
: "${JFROG_USER:?falta JFROG_USER}"
: "${JFROG_TOKEN:?falta JFROG_TOKEN}"
: "${JFROG_REPO:?falta JFROG_REPO}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARTIFACT_NAME="site-${COMMIT_SHA}.tar.gz"
ARTIFACT_PATH="${ROOT_DIR}/${ARTIFACT_NAME}"

echo "==> Empaquetando dist/ como ${ARTIFACT_NAME}"
tar -czf "${ARTIFACT_PATH}" -C "${ROOT_DIR}/dist" .

echo "==> Publicando en ${JFROG_URL}/${JFROG_REPO}/${ARTIFACT_NAME}"
curl --fail --silent --show-error \
  -u "${JFROG_USER}:${JFROG_TOKEN}" \
  -T "${ARTIFACT_PATH}" \
  "${JFROG_URL}/${JFROG_REPO}/${ARTIFACT_NAME}"

echo "==> Publicado: ${ARTIFACT_NAME}"
