#!/usr/bin/env bash
# Copia el mismo artefacto (identificado por SHA) entre repositorios de
# ambiente en JFrog Artifactory, sin reconstruirlo.
# Requiere JFROG_URL, JFROG_USER, JFROG_TOKEN en el entorno.
# Uso: promote.sh <commit_sha> <repo_origen> <repo_destino>
set -euo pipefail

COMMIT_SHA="${1:?falta el commit SHA}"
FROM_REPO="${2:?falta el repositorio de origen}"
TO_REPO="${3:?falta el repositorio de destino}"
: "${JFROG_URL:?falta JFROG_URL}"
: "${JFROG_USER:?falta JFROG_USER}"
: "${JFROG_TOKEN:?falta JFROG_TOKEN}"

ARTIFACT_NAME="site-${COMMIT_SHA}.tar.gz"

echo "==> Promoviendo ${ARTIFACT_NAME}: ${FROM_REPO} -> ${TO_REPO}"
curl --fail --silent --show-error -X POST \
  -u "${JFROG_USER}:${JFROG_TOKEN}" \
  "${JFROG_URL}/api/copy/${FROM_REPO}/${ARTIFACT_NAME}?to=/${TO_REPO}/${ARTIFACT_NAME}"

echo "==> Promoción completada"
