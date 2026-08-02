# daviplata-app

Sitio estático (HTML/CSS/JS sin framework), empaquetado en una imagen de contenedor y desplegado en Amazon ECS Express Mode.

## Arquitectura

El sitio se sirve con nginx dentro de un contenedor (`nginxinc/nginx-unprivileged`, no-root). La imagen es inmutable y se promueve sin reconstruir entre ambientes: `config.json` y `version.json` se inyectan en el arranque del contenedor según la variable de entorno `ENVIRONMENT` (ver `docker/40-inject-config.sh`), no se hornean en el build. El servicio corre en ECS Express Mode (Fargate + Application Load Balancer + auto-scaling en un solo recurso, gestionado desde `terraform-live`).

## Estructura

```
src/            contenido fuente: index.html, 404.html, estilos, JS mínimo, health.json, version.json.tmpl
config/         config.<ambiente>.json — configuración pública, una por ambiente
docker/         configuración de nginx y el script que inyecta config.json/version.json en runtime
Dockerfile      imagen de la aplicación
tests/          validación de enlaces (check-links.js) + configuración de linters/Lighthouse
scripts/        build.js, deploy-ecs.sh, smoke-test.sh, rollback-ecs.sh, promote-image.sh, mark-stable.sh
```

## Build

`npm run build` genera `dist/`: copia `src/` y renderiza `version.json` desde `version.json.tmpl` con las variables de entorno `BUILD_VERSION`/`BUILD_COMMIT`/`BUILD_ENVIRONMENT`/`BUILD_TIME`. `docker build` empaqueta ese `dist/` junto con los tres `config.<ambiente>.json` en una única imagen; la misma imagen se promueve entre ambientes sin reconstruir.

## Pipeline

- **`pr-validation.yml`**: valida convención de rama, exige título de PR en formato Conventional Commits (solo hacia `integracion`, con `amannn/action-semantic-pull-request`), instala dependencias, build de referencia, `check-links`, Lighthouse CI, y delega en `reusable-security.yml` (SonarQube Cloud + Gitleaks, ambos bloqueantes y requeridos en la protección de rama).
- **`release.yml`** (al mergear a `integracion`): calcula la versión semántica con `semantic-release` (lee Conventional Commits desde el último tag alcanzable, no solo el último commit) y crea + empuja el tag `vX.Y.Z`, construye la imagen, la escanea con Trivy (bloqueante) y la publica en el repositorio ECR del ambiente. Si el título del PR no trae un prefijo reconocible no se genera versión y el job falla explícitamente, en vez de desplegar sin saber qué se está desplegando.
- **`deploy.yml`** (uno solo para los 3 ambientes): se dispara automáticamente cuando `release.yml` termina bien (despliega a integración) o al cerrar el PR de promoción hacia `laboratorio`/`main` (resuelve el ambiente de la rama base). En promociones, copia la imagen ya publicada al repositorio ECR del ambiente destino sin reconstruir. Actualiza el servicio ECS Express, corre smoke test, marca la versión estable en SSM Parameter Store o hace rollback automático, y notifica por correo (SNS) y opcionalmente Slack. También admite `workflow_dispatch` para redesplegar manualmente sin abrir un PR.

## Desarrollo local

```
npm install
make build ENV=integracion     # o: BUILD_ENVIRONMENT=integracion npm run build
make lint
make test
docker build -t daviplata-app:local .
docker run -p 8080:8080 -e ENVIRONMENT=integracion daviplata-app:local
```

`scripts/deploy-ecs.sh`, `scripts/smoke-test.sh`, `scripts/rollback-ecs.sh` y `scripts/promote-image.sh` se pueden ejecutar localmente con credenciales AWS válidas — en la práctica solo el pipeline los invoca.
