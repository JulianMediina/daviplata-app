#!/usr/bin/env bash
# Restaura la última versión estable conocida del ambiente: la lee de SSM
# Parameter Store y vuelve a apuntar el servicio ECS Express a esa imagen,
# ya publicada en ECR -no reconstruye nada.
# Uso: rollback-ecs.sh <service_arn> <cluster> <service_name> <repository_url> <ambiente> [container_port]
set -euo pipefail

SERVICE_ARN="${1:?falta el ARN del servicio}"
CLUSTER="${2:?falta el nombre del cluster}"
SERVICE_NAME="${3:?falta el nombre del servicio}"
REPOSITORY_URL="${4:?falta la URL del repositorio ECR}"
ENVIRONMENT="${5:?falta el ambiente}"
CONTAINER_PORT="${6:-8080}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "==> Leyendo versión estable de /daviplata/${ENVIRONMENT}/stable-version"
STABLE_VERSION=$(aws ssm get-parameter --name "/daviplata/${ENVIRONMENT}/stable-version" --query 'Parameter.Value' --output text 2>/dev/null || true)

if [[ -z "${STABLE_VERSION}" || "${STABLE_VERSION}" == "None" ]]; then
  echo "rollback-ecs: no hay una versión estable previa registrada para ${ENVIRONMENT}. Rollback abortado." >&2
  exit 1
fi

echo "==> Última versión estable: ${STABLE_VERSION}"
"${ROOT_DIR}/scripts/deploy-ecs.sh" "${SERVICE_ARN}" "${CLUSTER}" "${SERVICE_NAME}" "${REPOSITORY_URL}" "${STABLE_VERSION}" "${CONTAINER_PORT}"

echo "==> Rollback completado a ${STABLE_VERSION}"
