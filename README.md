# daviplata-app

Sitio estático de referencia (HTML/CSS/JS sin framework) y su pipeline de CI/CD. El peso del ejercicio no está en la aplicación —deliberadamente mínima— sino en la cadena de build, seguridad, despliegue, monitoreo y rollback que la rodea.

## Por qué no hay Dockerfile

El sitio se sirve como archivos estáticos detrás de CloudFront + S3 privado (OAC); no hay proceso de servidor que empaquetar. Un contenedor añadiría una capa de infraestructura (ECS/Fargate, ALB, red) sin aportar nada sobre lo que ya resuelve S3+CloudFront para este caso de uso, y con más superficie de costo y de mantenimiento.

## Estructura

```
src/            contenido fuente: index.html, 404.html, estilos, JS mínimo, health.json, version.json.tmpl
config/         config.<ambiente>.json — configuración pública, una por ambiente
tests/          validación de enlaces (check-links.js) + configuración de linters/Lighthouse
scripts/        build.js, deploy.sh, smoke-test.sh, rollback.sh, publish.sh, promote.sh, mark-stable.sh
docs/           documentación entregable (arquitectura, runbook, costos, rollback, monitoreo, gitops, preguntas)
```

## Build

`npm run build` genera `dist/`: copia `src/`, renderiza `version.json` desde `version.json.tmpl` con las variables de entorno `BUILD_VERSION`/`BUILD_COMMIT`/`BUILD_ENVIRONMENT`/`BUILD_TIME`, y copia el `config.<ambiente>.json` correspondiente como `dist/config.json`. El artefacto se empaqueta como `site-<SHA>.tar.gz` y es **el mismo bundle** que se promueve entre ambientes — nunca se reconstruye.

## Pipeline

- **`pr-validation.yml`**: valida convención de rama, instala dependencias, build de referencia, `check-links`, Lighthouse CI, y delega en `reusable-security.yml` (SonarQube Cloud + Gitleaks, ambos bloqueantes).
- **`release-deploy.yml`** (al hacer merge a `main`): build único por SHA → publica como GitHub Release (`build-<SHA>`) → Trivy SCA (bloqueante) → despliega integración → smoke test → si falla, rollback automático + evidencia; si pasa, marca la versión como estable y promueve el mismo artefacto a laboratorio (repite el ciclo) y, con aprobación de dos revisores, a producción → notificación final.

Ver `docs/gitops.md` para el detalle de por qué esto cuenta como GitOps sin Kubernetes, y `docs/rollback-strategy.md` para el mecanismo de recuperación.

## Desarrollo local

```
npm install
make build ENV=integracion     # o: BUILD_ENVIRONMENT=integracion npm run build
make lint
make test
```

`scripts/deploy.sh`, `scripts/smoke-test.sh`, `scripts/rollback.sh`, `scripts/publish.sh` y `scripts/promote.sh` se pueden ejecutar localmente con credenciales AWS válidas y `gh` autenticado (para los que usan GitHub Releases) — en la práctica solo el pipeline los invoca.

