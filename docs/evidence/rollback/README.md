# Evidencia de rollback

Se llena automáticamente: cada ejecución de `scripts/rollback.sh` escribe un log `incident-<timestamp>.log` en esta carpeta con el bucket afectado, la distribución invalidada y el commit restaurado. `deploy.yml` también sube ese log como artefacto del workflow cuando el rollback se dispara en el pipeline.

Pendiente de la Fase 3 (bootstrap + despliegue real): aquí debe quedar el registro de al menos una ejecución real de rollback, junto con capturas del pipeline mostrando el paso "rollback automático" en rojo seguido de la validación post-rollback en verde.
