#!/usr/bin/env bash
# Empaqueta dist/ y lo publica como un GitHub Release con la versión
# semántica dada (calculada previamente por next-version.sh y ya horneada
# en dist/version.json por el paso de build — este script no la recalcula,
# solo la usa). El tag se crea apuntando exactamente al commit que se
# construyó, así que scripts/promote.sh y scripts/rollback.sh pueden
# resolver "qué versión corresponde a este commit" con `git tag --points-at`
# más adelante, sin tener que reconstruir nada.
# Requiere GH_TOKEN (o GITHUB_TOKEN) con permiso contents:write.
# Uso: publish.sh <version vX.Y.Z> <commit_sha> <repo owner/name>
set -euo pipefail

VERSION="${1:?falta la versión (vX.Y.Z)}"
COMMIT_SHA="${2:?falta el commit SHA}"
REPO="${3:?falta el repo (owner/name)}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARTIFACT_NAME="site-${COMMIT_SHA}.tar.gz"
ARTIFACT_PATH="${ROOT_DIR}/${ARTIFACT_NAME}"

echo "==> Empaquetando dist/ como ${ARTIFACT_NAME}"
tar -czf "${ARTIFACT_PATH}" -C "${ROOT_DIR}/dist" .

if gh release view "${VERSION}" --repo "${REPO}" >/dev/null 2>&1; then
  EXISTING_SHA=$(git rev-list -n1 "${VERSION}")
  if [[ "${EXISTING_SHA}" != "${COMMIT_SHA}" ]]; then
    echo "publish: ${VERSION} ya existe pero apunta a ${EXISTING_SHA}, no a ${COMMIT_SHA}." >&2
    echo "publish: esto es una colisión de versión (rama base desactualizada o next-version.sh sin el tag ancestro correcto), no una re-ejecución segura." >&2
    exit 1
  fi
  echo "==> ${VERSION} ya existe en ${REPO} y apunta al mismo commit (re-ejecución del pipeline) — no se reconstruye"
else
  echo "==> Etiquetando ${COMMIT_SHA} como ${VERSION}"
  git tag -a "${VERSION}" "${COMMIT_SHA}" -m "Release ${VERSION}"
  git push origin "${VERSION}"

  echo "==> Publicando release ${VERSION} en ${REPO}"
  gh release create "${VERSION}" "${ARTIFACT_PATH}" \
    --repo "${REPO}" \
    --target "${COMMIT_SHA}" \
    --title "DaviPlata ${VERSION}" \
    --notes "Bundle inmutable generado por el pipeline para el commit ${COMMIT_SHA}."
fi

echo "==> Publicado: ${VERSION} (${ARTIFACT_NAME})"
