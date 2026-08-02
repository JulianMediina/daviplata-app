#!/usr/bin/env bash
# Etiqueta el commit con la versión semántica calculada por next-version.sh.
# El artefacto real ahora es la imagen publicada en ECR (ver release.yml);
# este tag solo deja constancia de qué versión semántica corresponde a qué
# commit, para que deploy.yml pueda resolverla en cada promoción.
# Uso: tag-version.sh <version vX.Y.Z> <commit_sha>
set -euo pipefail

VERSION="${1:?falta la versión (vX.Y.Z)}"
COMMIT_SHA="${2:?falta el commit SHA}"

if git rev-parse "${VERSION}" >/dev/null 2>&1; then
  EXISTING_SHA=$(git rev-list -n1 "${VERSION}")
  if [[ "${EXISTING_SHA}" != "${COMMIT_SHA}" ]]; then
    echo "tag-version: ${VERSION} ya existe pero apunta a ${EXISTING_SHA}, no a ${COMMIT_SHA}." >&2
    echo "tag-version: esto es una colisión de versión, no una re-ejecución segura." >&2
    exit 1
  fi
  echo "==> ${VERSION} ya existe y apunta al mismo commit (re-ejecución del pipeline)"
else
  echo "==> Etiquetando ${COMMIT_SHA} como ${VERSION}"
  git tag -a "${VERSION}" "${COMMIT_SHA}" -m "Release ${VERSION}"
  git push origin "${VERSION}"
fi
