# GitOps sin Kubernetes

No hay clúster ni controlador de reconciliación en este proyecto, así que "GitOps" se traduce aquí a cuatro principios concretos, todos verificables en los repos y en el historial de GitHub Actions:

## 1. Git como única fuente de verdad

Ningún cambio de infraestructura o de la app llega a AWS sin pasar antes por un commit en `main`. No existe un `terraform apply` ni un `aws s3 sync` documentado como paso manual desde una laptop — ni siquiera `terraform-foundation`, que tiene su propio `foundation-plan.yml`/`foundation-apply.yml` (ver su README para cómo resuelve la dependencia circular de su propio backend de estado).

## 2. Cambios declarativos, revisados antes de aplicarse

- **Infraestructura (`terraform-live`):** `infra-plan.yml` corre `terraform plan` para los tres ambientes en cada PR y comenta el resultado exacto — el revisor ve qué va a cambiar antes de aprobar.
- **Aplicación (`daviplata-app`):** `pr-validation.yml` construye y prueba el mismo bundle que luego se promueve, así que lo que se revisa en el PR es funcionalmente lo que se despliega.

## 3. Reconciliación automatizada y auditable

- **`infra-apply.yml`** aplica automáticamente al hacer merge a `main`, en el orden integración → laboratorio → producción, sin intervención manual salvo las aprobaciones de ambiente configuradas en GitHub.
- **`drift-detection.yml`** corre `terraform plan -detailed-exitcode` a diario contra cada ambiente; si detecta divergencia entre el estado y la infraestructura real (alguien cambió algo fuera de Terraform), abre una incidencia automáticamente en vez de corregir en silencio — la corrección sigue pasando por PR.

## 4. Promoción sin reconstrucción

El artefacto de `daviplata-app` se construye **una sola vez** por commit y se publica como un GitHub Release (`build-<SHA>`). "Promover" a laboratorio o producción no mueve ni copia el archivo — es el mismo asset, descargado tal cual en cada ambiente; `scripts/promote.sh` solo añade una línea a las notas del release marcando por qué ambientes ya pasó, para trazabilidad. Lo que se prueba en integración es, en bytes, lo que llega a producción.

## Control de cambios

Branch protection en `main` de los 4 repos + revisión obligatoria por PR es el mecanismo de "cuatro ojos" para infraestructura y aplicación en general; producción, además, exige aprobación explícita en su GitHub Environment antes de que `promote-produccion`/`apply-produccion` corran. El historial de Git (quién y cuándo aprobó cada PR) más las notas de cada GitHub Release son, juntos, el registro de auditoría de la plataforma.
