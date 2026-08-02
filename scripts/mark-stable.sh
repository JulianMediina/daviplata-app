#!/usr/bin/env bash
# Marca una versión como la última estable del ambiente en SSM Parameter
# Store, para que rollback-ecs.sh sepa a qué versión volver si un
# despliegue futuro falla. Solo debe llamarse después de que el smoke test
# pase.
# Uso: mark-stable.sh <ambiente> <version>
set -euo pipefail

ENVIRONMENT="${1:?falta el ambiente}"
VERSION="${2:?falta la versión (vX.Y.Z)}"

aws ssm put-parameter \
  --name "/daviplata/${ENVIRONMENT}/stable-version" \
  --value "${VERSION}" \
  --type String \
  --overwrite

echo "==> /daviplata/${ENVIRONMENT}/stable-version actualizado a ${VERSION}"
