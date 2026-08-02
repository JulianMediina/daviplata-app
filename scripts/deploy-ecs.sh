#!/usr/bin/env bash
# Actualiza el servicio ECS Express para que sirva la imagen indicada y
# espera a que el despliegue se estabilice. No reconstruye nada: la imagen
# ya está publicada en ECR (release.yml o promote-image.sh la pusieron ahí).
# Uso: deploy-ecs.sh <service_arn> <cluster> <service_name> <repository_url> <version> [container_port]
set -euo pipefail

SERVICE_ARN="${1:?falta el ARN del servicio}"
CLUSTER="${2:?falta el nombre del cluster}"
SERVICE_NAME="${3:?falta el nombre del servicio}"
REPOSITORY_URL="${4:?falta la URL del repositorio ECR}"
VERSION="${5:?falta la versión (vX.Y.Z)}"
CONTAINER_PORT="${6:-8080}"

IMAGE="${REPOSITORY_URL}:${VERSION}"

echo "==> Actualizando ${SERVICE_NAME} a ${IMAGE}"
aws ecs update-express-gateway-service \
  --service-arn "${SERVICE_ARN}" \
  --primary-container "{\"image\":\"${IMAGE}\",\"containerPort\":${CONTAINER_PORT}}" \
  >/dev/null

echo "==> Esperando a que el despliegue se estabilice"
# 80 intentos x 15s = 20 min: el primer despliegue real a un servicio recién
# creado por Terraform compite con el intento inicial de arrancar la imagen
# placeholder "bootstrap" (que no existe y falla en bucle hasta agotar sus
# reintentos) -en un caso real, ese solape hizo que un despliegue que sí
# terminó bien tardara más de los 10 minutos que este script permitía antes.
for i in $(seq 1 80); do
  info=$(aws ecs describe-services --cluster "${CLUSTER}" --services "${SERVICE_NAME}" \
    --query 'services[0].{running:runningCount,desired:desiredCount,rollout:deployments[0].rolloutState}' \
    --output json)
  running=$(echo "${info}" | grep -o '"running": *[0-9]*' | grep -o '[0-9]*$')
  desired=$(echo "${info}" | grep -o '"desired": *[0-9]*' | grep -o '[0-9]*$')
  rollout=$(echo "${info}" | grep -o '"rollout": *"[^"]*"' | sed 's/.*"\([^"]*\)"$/\1/')

  echo "    intento ${i}: running=${running} desired=${desired} rollout=${rollout}"

  if [[ "${rollout}" == "FAILED" ]]; then
    echo "deploy-ecs: el despliegue falló (rolloutState=FAILED)" >&2
    exit 1
  fi

  if [[ "${rollout}" == "COMPLETED" && "${running}" == "${desired}" && "${running}" != "0" ]]; then
    echo "==> Despliegue estable (${running}/${desired} tareas activas)"
    exit 0
  fi

  sleep 15
done

echo "deploy-ecs: el servicio no se estabilizó a tiempo" >&2
exit 1
