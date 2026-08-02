#!/usr/bin/env bash
# Copia la imagen ya publicada del ambiente anterior al repositorio ECR del
# ambiente destino, sin reconstruir nada -son repositorios ECR aislados por
# ambiente (misma separación que ya existía por bucket S3).
# Uso: promote-image.sh <source_repository_url> <target_repository_url> <version>
set -euo pipefail

SOURCE_REPO="${1:?falta el repositorio origen}"
TARGET_REPO="${2:?falta el repositorio destino}"
VERSION="${3:?falta la versión (vX.Y.Z)}"

echo "==> Autenticando en ECR"
aws ecr get-login-password --region "${AWS_REGION:-us-east-1}" \
  | docker login --username AWS --password-stdin "${SOURCE_REPO%%/*}"

echo "==> docker pull ${SOURCE_REPO}:${VERSION}"
docker pull "${SOURCE_REPO}:${VERSION}"

docker tag "${SOURCE_REPO}:${VERSION}" "${TARGET_REPO}:${VERSION}"

echo "==> docker push ${TARGET_REPO}:${VERSION}"
docker push "${TARGET_REPO}:${VERSION}"

echo "==> Promoción completada: ${VERSION}"
