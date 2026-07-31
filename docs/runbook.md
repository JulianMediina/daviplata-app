# Runbook operativo

## 1. Requisitos previos

- Cuenta AWS con capacidad de crear un usuario IAM.
- AWS CLI v2 instalado (`aws --version`) — solo hace falta para el paso 2 (generar la credencial de arranque) y para diagnóstico local.
- `gh` CLI instalado y autenticado (`gh auth login`) — para crear repos, secrets y Environments desde la terminal.
- Cuenta gratuita creada en SonarQube Cloud (sonarcloud.io).
- Node.js 20+ para el tooling de `daviplata-app`.
- Los 4 repositorios creados en GitHub bajo el mismo usuario/organización (públicos, para que Actions y GitHub Releases no tengan costo).

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

```
cd terraform-foundation
git push -u origin main
```

El push a `main` dispara `foundation-apply.yml`: crea (si no existen) el bucket/tabla de estado propios de `terraform-foundation` vía `scripts/ensure-backend.sh`, y aplica el resto (buckets/locks/KMS por ambiente, proveedor OIDC, roles `gha-<ambiente>`, alarma de presupuesto). Para cambios posteriores, el flujo normal es PR → `foundation-plan.yml` comenta el plan → merge → `foundation-apply.yml` aplica (con aprobación del Environment `foundation`).

Copia los outputs del job de apply (`gha_role_arns`, `tfstate_buckets`, `site_kms_key_arns`) — los necesitas para el siguiente paso.

## 5. Configurar GitHub Environments y secrets

En cada uno de `terraform-live` y `daviplata-app`, crea 3 GitHub Environments: `integracion`, `laboratorio`, `produccion` (Settings → Environments). En `laboratorio` agrega 1 revisor requerido; en `produccion`, 2 (o el mismo revisor dos veces si es una cuenta individual — documentar la limitación).

Por ambiente, agrega:
- Secret `AWS_ROLE_ARN`: el `gha_role_arns.<ambiente>` que salió del bootstrap.
- (Solo `daviplata-app`) Variables `SITE_BUCKET`, `DISTRIBUTION_ID`, `DISTRIBUTION_DOMAIN` — se obtienen de los outputs de `terraform-live` tras aplicar ese ambiente (paso 6).

A nivel de repositorio (no por ambiente), en `daviplata-app` agrega el secret `SONAR_TOKEN` y, opcionalmente, `SLACK_WEBHOOK_URL`. **No hace falta ningún secret de artefactos**: la publicación usa GitHub Releases con el `GITHUB_TOKEN` que Actions ya inyecta automáticamente (solo hace falta el permiso `contents: write`, ya declarado en `release-deploy.yml`).

## 6. Desplegar la infraestructura por ambiente

```
cd terraform-live
git push -u origin main
```

El push dispara `infra-apply.yml`: aplica integración → laboratorio → producción en ese orden, pausando en cada Environment protegido hasta que se apruebe. Para cambios posteriores, igual que foundation: PR → `infra-plan.yml` comenta el plan → merge → `infra-apply.yml` aplica.

## 7. Primer despliegue de la aplicación

Mergear un PR a `main` en `daviplata-app` dispara `release-deploy.yml`: build → publicar como GitHub Release (`build-<SHA>`) → Trivy → desplegar integración → smoke → marcar promoción a laboratorio → smoke → (aprobación) → marcar promoción a producción → smoke → notificar.

## 8. Diagnóstico rápido

| Síntoma | Dónde mirar |
|---|---|
| El pipeline falla en `terraform plan` (foundation o live) | Comentario del PR en `foundation-plan.yml`/`infra-plan.yml`; revisar que el backend/tfvars del ambiente sean correctos |
| El pipeline falla en el quality gate de Sonar | Panel del proyecto en sonarcloud.io; el check de GitHub enlaza directo al análisis |
| El pipeline falla en Trivy | Log del paso "SCA con Trivy" en `release-deploy.yml`; lista las CVE encontradas |
| El smoke test falla | Log del paso "smoke test"; confirma manualmente con `curl https://<dominio>/health.json` y `curl https://<dominio>/version.json` |
| Se disparó un rollback | `docs/evidence/rollback/` + artefacto subido en la ejecución del workflow en GitHub Actions |
| Drift detectado | Incidencia abierta automáticamente por `drift-detection.yml`; correr `make plan ENV=<ambiente>` en `terraform-live` para ver el detalle |
| El sitio no carga / 403 | Revisar que la política del bucket (creada por el módulo `cloudfront-oac`) siga apuntando al ARN de distribución correcto; un cambio manual del bucket puede haberla roto |
| No se encuentra el release/artefacto | `gh release list --repo <tu-usuario>/daviplata-app`; el tag es `build-<SHA>`, no el SHA solo |

## 9. Reproducibilidad desde cero

Este runbook, en orden (2 → 3 → 4 → 5 → 6 → 7), es suficiente para reconstruir toda la plataforma en una cuenta AWS nueva. El único paso verdaderamente manual es el 2 (generar la credencial de arranque de `terraform-foundation` y cargarla como secret) — todo lo demás corre por Actions.

## 10. Cierre / limpieza

Ver `docs/cost.md` → sección "Cierre de ambientes de prueba" para el orden correcto de `terraform destroy`.
