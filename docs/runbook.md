# Runbook operativo

## 1. Requisitos previos

- Cuenta AWS con capacidad de crear un usuario IAM.
- AWS CLI v2 instalado (`aws --version`) — solo hace falta para el paso 2 (generar la credencial de arranque) y para diagnóstico local.
- `gh` CLI instalado y autenticado (`gh auth login`) — para crear repos, secrets y Environments desde la terminal.
- Cuenta gratuita creada en SonarQube Cloud (sonarcloud.io).
- Node.js 20+ para el tooling de `daviplata-app`.
- Los 4 repositorios creados en GitHub bajo el mismo usuario/organización (públicos, para que Actions y GitHub Releases no tengan costo).
- `terraform-live` y `daviplata-app` usan un modelo de **rama por ambiente**: `integracion`, `laboratorio`, `main` (=producción). Ver `docs/gitops.md` para el flujo completo. `terraform-foundation` y `terraform-modules` se quedan con un solo `main` (trunk-based).

## 2. Credencial de arranque para `terraform-foundation`

`terraform-foundation` es el único pipeline de la plataforma que no puede autenticarse por OIDC — es el que **crea** el proveedor OIDC del que dependen todos los demás roles. Necesita una credencial IAM de larga duración, guardada como secret del repositorio, nunca usada por ningún otro pipeline.

1. En la consola de AWS → IAM → Users, crea (o reusa) un usuario con permisos suficientes para gestionar S3, DynamoDB, KMS, IAM (roles/OIDC provider) y Budgets.
2. Genera un access key para ese usuario.
3. Guárdalo como secrets del repo `terraform-foundation` (nunca lo pegues en un PR ni en un log):
   ```
   gh secret set FOUNDATION_AWS_ACCESS_KEY_ID --repo <tu-usuario>/terraform-foundation
   gh secret set FOUNDATION_AWS_SECRET_ACCESS_KEY --repo <tu-usuario>/terraform-foundation
   ```
4. Crea el GitHub Environment `foundation` en ese repo (Settings → Environments) con al menos un revisor requerido.

## 3. Publicar la primera versión de los módulos

```
cd terraform-modules
git remote add origin https://github.com/<tu-usuario>/terraform-modules.git
git push -u origin main
git tag v0.1.0
git push origin v0.1.0
```

Confirma en GitHub Actions que `module-ci.yml` pasó en verde antes de continuar.

## 4. Bootstrap de la plataforma

Antes del primer push, define la variable de repositorio (no es secreta, así que va como `vars`, no como `secrets`) que usa `github_org`/`budget_notification_emails`:

```
gh variable set BUDGET_NOTIFICATION_EMAILS --repo <tu-usuario>/terraform-foundation --body '["tu-correo@example.com"]'
```

`github_org` no hace falta configurarlo: el workflow lo toma directo de `github.repository_owner`.

```
cd terraform-foundation
git push -u origin main
```

El push a `main` dispara `foundation-apply.yml`: crea (si no existen) el bucket/tabla de estado propios de `terraform-foundation` vía `scripts/ensure-backend.sh`, y aplica el resto (buckets/locks/KMS por ambiente, proveedor OIDC, roles `gha-<ambiente>`, alarma de presupuesto). Para cambios posteriores, el flujo normal es PR → `foundation-plan.yml` comenta el plan → merge → `foundation-apply.yml` aplica (con aprobación del Environment `foundation`).

Copia los outputs del job de apply (`gha_role_arns`, `tfstate_buckets`, `site_kms_key_arns`) — los necesitas para el siguiente paso.

## 5. Crear las ramas de ambiente y configurar GitHub Environments/secrets

En `terraform-live` y `daviplata-app`, crea las ramas `integracion` y `laboratorio` a partir de `main` (que queda como producción):

```
git checkout -b integracion && git push -u origin integracion
git checkout -b laboratorio && git push -u origin laboratorio
```

Protege las tres ramas (requiere PR + 1 revisión antes de mergear):

```
gh api --method PUT repos/<tu-usuario>/<repo>/branches/integracion/protection \
  -f required_pull_request_reviews[required_approving_review_count]=1 \
  -F enforce_admins=false
# repetir para laboratorio y main
```

Crea 3 GitHub Environments en cada repo (Settings → Environments): `integracion`, `laboratorio`, `produccion`. En `laboratorio` agrega 1 revisor requerido; en `produccion`, 2 (o el mismo revisor dos veces si es una cuenta individual — documentado como limitación en `docs/gitops.md`).

Por ambiente, agrega:
- Secret `AWS_ROLE_ARN`: el `gha_role_arns.<ambiente>` que salió del bootstrap.
- (Solo `daviplata-app`) Variables `SITE_BUCKET`, `DISTRIBUTION_ID`, `DISTRIBUTION_DOMAIN` — se obtienen de los outputs de `terraform-live` tras aplicar ese ambiente (paso 6).

A nivel de repositorio (no por ambiente), en `daviplata-app` agrega el secret `SONAR_TOKEN` y, opcionalmente, `SLACK_WEBHOOK_URL`. **No hace falta ningún secret de artefactos**: la publicación usa GitHub Releases con el `GITHUB_TOKEN` que Actions ya inyecta automáticamente (solo hace falta el permiso `contents: write`, ya declarado en los workflows `deploy-*.yml`).

## 6. Desplegar la infraestructura por ambiente

La primera vez, empuja el código base a las tres ramas (`main`, `integracion`, `laboratorio` ya deberían tener el mismo contenido si se crearon como en el paso 5). Cambios posteriores siguen siempre el flujo de PR:

```
feature/algo → PR hacia integracion → (merge) dispara apply-integracion.yml
integracion  → PR hacia laboratorio → (merge) dispara apply-laboratorio.yml
laboratorio  → PR hacia main        → (merge) dispara apply-produccion.yml (con aprobación)
```

Cada `apply-*.yml` corre al **cerrar** el PR correspondiente (no con push directo), usando el commit exacto que se revisó.

## 7. Primer despliegue de la aplicación

Mismo flujo de ramas que la infraestructura:

1. PR de una rama `feature/*` hacia `integracion` → al mergear, `release.yml` construye el bundle **una sola vez**, calcula la versión semántica (`scripts/next-version.sh`, a partir de Conventional Commits), la publica como GitHub Release y corre Trivy; al terminar, dispara automáticamente `deploy.yml` (vía `workflow_run`), que despliega a integración y valida con smoke test.
2. PR de `integracion` hacia `laboratorio` → al mergear, el mismo `deploy.yml` (disparado ahora por el cierre del PR) descarga **el mismo artefacto ya publicado** (sin reconstruir), lo despliega a laboratorio y valida.
3. PR de `laboratorio` hacia `main` → al mergear, `deploy.yml` hace lo mismo contra producción, con aprobación del Environment `produccion` de por medio. El ambiente siempre se resuelve de la rama base del PR (o de la punta de `integracion` cuando lo dispara `release.yml`) — es un único archivo para los 3 ambientes.

## 8. Diagnóstico rápido

| Síntoma | Dónde mirar |
|---|---|
| El pipeline falla en `terraform plan` (foundation o live) | Comentario del PR en `foundation-plan.yml`/`plan.yml`; revisar que el backend/tfvars del ambiente sean correctos |
| El pipeline falla en el quality gate de Sonar | Panel del proyecto en sonarcloud.io; el check de GitHub enlaza directo al análisis |
| El pipeline falla en Trivy | Log del paso "SCA con Trivy" en `release.yml`; lista las CVE encontradas |
| El smoke test falla | Log del paso "smoke test"; confirma manualmente con `curl https://<dominio>/health.json` y `curl https://<dominio>/version.json` |
| Se disparó un rollback | `docs/evidence/rollback/` + artefacto subido en la ejecución del workflow en GitHub Actions |
| Drift detectado | Incidencia abierta automáticamente por `drift-detection.yml`; correr `make plan ENV=<ambiente>` en `terraform-live` para ver el detalle |
| El sitio no carga / 403 | Revisar que la política del bucket (creada por el módulo `cloudfront-oac`) siga apuntando al ARN de distribución correcto; un cambio manual del bucket puede haberla roto |
| No se encuentra el release/artefacto | `gh release list --repo <tu-usuario>/daviplata-app`; el tag es la versión semántica (`vX.Y.Z`), no el SHA — usa `git tag --points-at <sha>` para resolverlo a partir de un commit |
| Un PR de promoción no pasa la validación de rama | `pr-validation.yml` exige que el PR venga exactamente de la rama anterior en la cadena (`integracion`→`laboratorio` debe venir de `integracion`, no de otra rama) — revisa el mensaje de error del job `branch-name` |

## 9. Reproducibilidad desde cero

Este runbook, en orden (2 → 3 → 4 → 5 → 6 → 7), es suficiente para reconstruir toda la plataforma en una cuenta AWS nueva. El único paso verdaderamente manual es el 2 (generar la credencial de arranque de `terraform-foundation` y cargarla como secret) — todo lo demás corre por Actions.

## 10. Cierre / limpieza

Ver `docs/cost.md` → sección "Cierre de ambientes de prueba" para el orden correcto de `terraform destroy`.
