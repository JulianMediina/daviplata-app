# Estrategia de rollback

## Mecanismo

Cada ambiente mantiene un puntero de "última versión estable" en `s3://<bucket>/_meta/stable.txt`, actualizado por `scripts/mark-stable.sh` **solo** después de que el smoke test de un despliegue pase. Si el smoke test de un despliegue nuevo falla, `scripts/rollback.sh`:

1. Lee `_meta/stable.txt` para saber cuál fue el último commit que sí pasó.
2. Descarga ese bundle (`site-<SHA>.tar.gz`) del GitHub Release `build-<SHA>` — el mismo artefacto inmutable que ya se había probado, no una reconstrucción.
3. Sincroniza ese bundle al bucket del ambiente (`aws s3 sync --delete`, preservando `_meta/`).
4. Invalida la caché de CloudFront.
5. Vuelve a correr el smoke test para confirmar que el rollback dejó el ambiente sano (validación post-rollback).
6. Escribe un log de incidente en `docs/evidence/rollback/incident-<timestamp>.log` con el bucket, la distribución y el commit restaurado.

En el pipeline (`release-deploy.yml`), este flujo se dispara automáticamente: el paso "rollback automático" corre con `if: failure()` inmediatamente después de un smoke test fallido, y el log resultante se sube como artefacto del workflow.

## Por qué un puntero en S3 y no versionado objeto-por-objeto

El bucket sí tiene versionado de S3 habilitado (además, como red de seguridad), pero restaurar "la versión anterior" objeto por objeto es ambiguo cuando un despliegue toca varios archivos a la vez: no hay garantía de que la versión N-1 de cada objeto individual corresponda al mismo despliegue coherente. Usar el bundle completo por SHA desde el GitHub Release garantiza que el rollback siempre restaura un conjunto de archivos que ya pasó smoke test como unidad.

## Restauración de configuración

`config.<ambiente>.json` viaja **dentro** del bundle (se copia como `dist/config.json` en build). Al restaurar el bundle anterior, la configuración anterior se restaura automáticamente — no hay un mecanismo de configuración separado que pueda quedar desincronizado del código.

## Reversión de código vs. promoción de versión

Dos mecanismos disponibles, documentados explícitamente porque cubren necesidades distintas:

- **Rollback operativo (automático, en minutos):** re-promover/re-sincronizar el `<SHA>` anterior, como se describe arriba. No requiere tocar el repositorio ni generar un nuevo commit — es la vía por defecto y la que dispara el pipeline solo.
- **Reversión de código (`git revert`):** cuando el problema no es un fallo de despliegue sino un defecto real que hay que corregir en el histórico — por ejemplo, si el commit desplegado tiene un bug que también hay que sacar de `main` para que el próximo `release-deploy` no lo vuelva a introducir. Se hace con PR normal, pasa por `pr-validation.yml` igual que cualquier otro cambio.

## Registro de incidentes y evidencia

Cada rollback deja: (a) el log en `docs/evidence/rollback/`, (b) el artefacto subido en la ejecución del workflow en GitHub Actions, (c) el historial de `_meta/stable.txt` en S3 (versionado), y (d) la notificación enviada al canal configurado. Juntos permiten reconstruir qué pasó, cuándo y quién lo vio primero.
