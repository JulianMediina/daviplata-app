# Monitoreo y observabilidad

## Qué se mide y dónde

| Requisito | Mecanismo |
|---|---|
| Disponibilidad | Smoke test en cada despliegue (`scripts/smoke-test.sh`) + alarma de `TotalErrorRate` en CloudWatch |
| Salud de la app | `/health.json`, consultado por el smoke test |
| Versión desplegada | `/version.json`, con aserción `commit == SHA` esperado en el smoke test |
| Tiempo de respuesta | Métrica `OriginLatency` de CloudFront + alarma sobre el umbral configurado por ambiente |
| Resultado de cada despliegue | Publicado por `deploy.yml` al tópico SNS de observabilidad del ambiente (correo) en cada corrida, corra bien o mal |
| Reintentos controlados | `smoke-test.sh` reintenta cada endpoint hasta `MAX_ATTEMPTS` veces con espera entre intentos |
| Integridad del contenido desplegado | Política del bucket (en `terraform-modules//cloudfront-oac`) deniega explícitamente `PutObject`/`DeleteObject` a cualquier principal que no sea el rol `gha-<ambiente>` del pipeline — ni una carga manual con credenciales de administrador puede modificar el sitio por fuera de este flujo |
| Manejo de timeout | Cada request del smoke test tiene `--max-time`; cada job de GitHub Actions tiene su propio límite de tiempo |
| Respuesta del pipeline a un fallo | Un smoke test fallido devuelve código de salida distinto de 0, lo que dispara el paso de rollback automático y la notificación |

## Dashboard y alarmas

El módulo `observability` (`terraform-modules/modules/observability`) crea, por ambiente:

- Un dashboard de CloudWatch con 4 widgets: requests, tasa de error total, latencia de origen y cache hit rate.
- Dos alarmas: tasa de error (`error_rate_threshold`, por defecto 5%) y latencia de origen (`origin_latency_threshold_ms`, por defecto 2000ms) — ambos configurables por ambiente vía `*.tfvars` en `terraform-live`.
- Un tópico SNS (`daviplata-<ambiente>-alarms`) al que se suscriben los correos de `notification_emails`.

## Extender a Slack/Teams

El tópico SNS admite cualquier protocolo adicional de suscripción (además del correo ya configurado). `deploy.yml` ya publica en él el resultado de cada despliegue (versión, commit, resultado, link al run) sin importar si el smoke test pasó o falló. Para Slack o Teams, la vía más simple es suscribir un endpoint HTTPS (webhook) al mismo tópico, o —como ya deja preparado `deploy.yml`, condicionado a que exista el secret `SLACK_WEBHOOK_URL`— enviar la notificación directamente desde el workflow sin pasar por SNS.

## Qué falta con presupuesto ajustado

Si el costo de CloudWatch Synthetics no se justifica para una prueba técnica, el smoke test programado por cron en GitHub Actions cumple el mismo propósito de monitoreo activo sin costo adicional — es la opción usada aquí. Ver `docs/cost.md`.
