#!/usr/bin/env bash
# Marca un commit como la última versión estable del ambiente, para que
# rollback.sh sepa a qué artefacto volver si un despliegue futuro falla.
# Solo debe llamarse después de que el smoke test pase.
# Uso: mark-stable.sh <bucket> <commit_sha>
set -euo pipefail

BUCKET="${1:?falta el nombre del bucket}"
COMMIT_SHA="${2:?falta el commit SHA}"

echo -n "${COMMIT_SHA}" | aws s3 cp - "s3://${BUCKET}/_meta/stable.txt" --content-type "text/plain"
echo "==> ${BUCKET}/_meta/stable.txt actualizado a ${COMMIT_SHA}"
