# GitOps sin Kubernetes

No hay clúster ni controlador de reconciliación en este proyecto, así que "GitOps" se traduce aquí a cuatro principios concretos, todos verificables en los repos y en el historial de GitHub Actions:

## 1. Git como única fuente de verdad

Ningún cambio de infraestructura o de la app llega a AWS sin pasar antes por un commit en `main`. No existe un `terraform apply` ni un `aws s3 sync` documentado como paso manual desde una laptop fuera de `terraform-foundation/bootstrap` (que es, por diseño, la única excepción — ver su README).

## 2. Cambios declarativos, revisados antes de aplicarse

- **Infraestructura (`terraform-live`):** `infra-plan.yml` corre `terraform plan` para los tres ambientes en cada PR y comenta el resultado exacto — el revisor ve qué va a cambiar antes de aprobar.
- **Aplicación (`daviplata-app`):** `pr-validation.yml` construye y prueba el mismo bundle que luego se promueve, así que lo que se revisa en el PR es funcionalmente lo que se despliega.

## 3. Reconciliación automatizada y auditable

- **`infra-apply.yml`** aplica automáticamente al hacer merge a `main`, en el orden integración → laboratorio → producción, sin intervención manual salvo las aprobaciones de ambiente configuradas en GitHub.
- **`drift-detection.yml`** corre `terraform plan -detailed-exitcode` a diario contra cada ambiente; si detecta divergencia entre el estado y la infraestructura real (alguien cambió algo fuera de Terraform), abre una incidencia automáticamente en vez de corregir en silencio — la corrección sigue pasando por PR.

## 4. Promoción sin reconstrucción

El artefacto de `daviplata-app` se construye **una sola vez** por commit y se promueve por SHA entre repositorios de JFrog Artifactory (`daviplata-integracion` → `daviplata-laboratorio` → `daviplata-produccion`). Lo que se prueba en integración es, en bytes, lo que llega a producción — la promoción es una operación de copia, no un nuevo build.

## Control de cambios

Branch protection en `main` de los 4 repos + revisión obligatoria por PR es el mecanismo de "cuatro ojos" para infraestructura y aplicación en general; producción, además, exige aprobación explícita en su GitHub Environment antes de que `promote-produccion`/`apply-produccion` corran. El historial de Git (quién y cuándo aprobó cada PR) más el historial de promociones en JFrog son, juntos, el registro de auditoría de la plataforma.
