# Runbook operativo

## 1. Requisitos previos

- Cuenta AWS con capacidad de crear un usuario/rol IAM administrativo temporal.
- AWS CLI v2 instalado (`aws --version`).
- Terraform >= 1.9 instalado (`terraform -version`).
- Cuentas gratuitas creadas en SonarQube Cloud (sonarcloud.io) y JFrog Cloud (jfrog.com/start-free).
- Node.js 20+ para el tooling de `daviplata-app`.
- Los 4 repositorios creados en GitHub bajo el mismo usuario/organización.

## 2. Configurar credenciales AWS (primera vez, en tu máquina)

1. En la consola de AWS → IAM → Users, crea un usuario `bootstrap-admin` con acceso mediante clave de acceso (no acceso a consola).
2. Adjunta la política administrada `AdministratorAccess` **temporalmente** — solo se usa para el bootstrap inicial, no para el día a día.
3. Genera un access key para ese usuario.
4. En tu terminal:
   ```
   aws configure
   # AWS Access Key ID: <la que generaste>
   # AWS Secret Access Key: <la que generaste>
   # Default region name: us-east-1
   # Default output format: json
   ```
5. Verifica: `aws sts get-caller-identity`.
6. Tras completar el bootstrap (paso 4 de este runbook), **elimina el access key** de `bootstrap-admin` o desactiva el usuario: el resto de la plataforma usa roles OIDC, no esta credencial.

## 3. Publicar la primera versión de los módulos

```
cd terraform-modules
git remote add origin https://github.com/JulianMediina/terraform-modules.git
git push -u origin main
git tag v0.1.0
git push origin v0.1.0
```

Confirma en GitHub Actions que `module-ci.yml` pasó en verde antes de continuar.

## 4. Bootstrap de la plataforma (una sola vez)

```
cd terraform-foundation/bootstrap
cp terraform.tfvars.example terraform.tfvars
# editar terraform.tfvars: github_org, modules_repo_ref=v0.1.0, budget_notification_emails
terraform init
terraform plan
terraform apply
```

Guarda los outputs (`gha_role_arns`, `tfstate_buckets`, `site_kms_key_arns`) — los vas a necesitar para configurar los secrets de GitHub Actions en el siguiente paso.

## 5. Configurar GitHub Environments y secrets

En cada uno de `terraform-live` y `daviplata-app`, crea 3 GitHub Environments: `integracion`, `laboratorio`, `produccion` (Settings → Environments). En `laboratorio` agrega 1 revisor requerido; en `produccion`, 2.

Por ambiente, agrega:
- Secret `AWS_ROLE_ARN`: el `gha_role_arns.<ambiente>` que salió del bootstrap.
- (Solo `daviplata-app`) Variables `SITE_BUCKET`, `DISTRIBUTION_ID`, `DISTRIBUTION_DOMAIN` — se obtienen de los outputs de `terraform-live` tras aplicar ese ambiente (paso 6).

A nivel de repositorio (no por ambiente), en `daviplata-app` agrega los secrets `SONAR_TOKEN`, `JFROG_URL`, `JFROG_USER`, `JFROG_TOKEN` y, opcionalmente, `SLACK_WEBHOOK_URL`.

## 6. Desplegar la infraestructura por ambiente

```
cd terraform-live/live
terraform init  -backend-config=integracion.s3.tfbackend -reconfigure
terraform plan  -var-file=integracion.tfvars
terraform apply -var-file=integracion.tfvars
terraform output   # copiar bucket_id, distribution_id, distribution_domain_name
```

Repite para `laboratorio` y `produccion`, o dejá que `infra-apply.yml` lo haga automáticamente al mergear un PR que toque `live/**` (recomendado una vez que los secrets estén configurados).

## 7. Primer despliegue de la aplicación

Mergear un PR a `main` en `daviplata-app` dispara `release-deploy.yml`: build → publicar en JFrog → Trivy → desplegar integración → smoke → promover a laboratorio → smoke → (aprobación) → promover a producción → smoke → notificar.

## 8. Diagnóstico rápido

| Síntoma | Dónde mirar |
|---|---|
| El pipeline falla en `terraform plan` | Comentario del PR en `infra-plan.yml`; revisar que el backend/tfvars del ambiente sean correctos |
| El pipeline falla en el quality gate de Sonar | Panel del proyecto en sonarcloud.io; el check de GitHub enlaza directo al análisis |
| El pipeline falla en Trivy | Log del paso "SCA con Trivy" en `release-deploy.yml`; lista las CVE encontradas |
| El smoke test falla | Log del paso "smoke test"; confirma manualmente con `curl https://<dominio>/health.json` y `curl https://<dominio>/version.json` |
| Se disparó un rollback | `docs/evidence/rollback/` + artefacto subido en la ejecución del workflow en GitHub Actions |
| Drift detectado | Incidencia abierta automáticamente por `drift-detection.yml`; correr `make plan ENV=<ambiente>` en `terraform-live` para ver el detalle |
| El sitio no carga / 403 | Revisar que la política del bucket (creada por el módulo `cloudfront-oac`) siga apuntando al ARN de distribución correcto; un cambio manual del bucket puede haberla roto |

## 9. Reproducibilidad desde cero

Este runbook, en orden (2 → 3 → 4 → 5 → 6 → 7), es suficiente para reconstruir toda la plataforma en una cuenta AWS nueva sin ningún paso manual adicional fuera de la creación de cuentas externas (GitHub, SonarQube Cloud, JFrog) y de la configuración inicial de credenciales del paso 2.

## 10. Cierre / limpieza

Ver `docs/cost.md` → sección "Cierre de ambientes de prueba" para el orden correcto de `terraform destroy`.
