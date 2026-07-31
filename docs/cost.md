# Gestión de costos

## Decisiones que bajan el costo por diseño

- **Una sola cuenta AWS**, en vez de una cuenta por ambiente: evita duplicar cargos base (Config, GuardDuty si se activaran, etc.) y la sobrecarga operativa de gestionar múltiples cuentas para un ejercicio de este tamaño. Se documenta como decisión de costo, no como recomendación final para banca real — ver `docs/answers-to-questions.md`, pregunta 9.
- **S3 + CloudFront, sin cómputo propio:** nada de ECS, Fargate, EC2, ALB ni NAT Gateway. El sitio es estático; no hay proceso de servidor que correr.
- **`PriceClass_100`** en CloudFront: sirve desde Norteamérica/Europa, suficiente para una prueba técnica, y evita las tarifas más altas de otras regiones de edge.
- **Sin dominio propio:** se usa el dominio por defecto `*.cloudfront.net`. Un dominio propio implicaría una hosted zone de Route53 (costo mensual fijo) y el módulo `acm` (que además solo aplica en `us-east-1`); ambos existen en el código pero no se activan por defecto.
- **JFrog solo como Artifactory:** el complemento de escaneo de vulnerabilidades (Xray) es de pago; se sustituye por Trivy, que es gratuito y cubre el mismo control de SCA para este caso de uso.
- **SonarQube Cloud Free:** cubre repos privados hasta 50k líneas — el sitio estático de esta prueba está muy por debajo de ese límite.

## Controles de consumo

- **Lifecycle de S3:** las versiones no vigentes de los objetos del bucket de sitio expiran a los `noncurrent_version_expiration_days` (30 por defecto) — evita que el versionado acumule costo indefinidamente.
- **Tags de costo** (`Project`, `Environment`, `CostCenter`) en todos los recursos, para poder filtrar por ambiente en Cost Explorer y Budgets.
- **Alarma de presupuesto:** `terraform-foundation/bootstrap` crea un `aws_budgets_budget` mensual con notificación al 80% (gasto real) y 100% (gasto proyectado).
- **Monitoreo sin costo adicional:** en vez de CloudWatch Synthetics (canary de pago), el smoke test corre gratis como workflow programado de GitHub Actions (`scheduled-smoke.yml`).

## Cierre de ambientes de prueba

Al terminar de evaluar el proyecto, cada ambiente se puede destruir de forma independiente sin tocar el estado de los demás:

```
make destroy ENV=integracion   # en terraform-live
make destroy ENV=laboratorio
make destroy ENV=produccion
```

`terraform-foundation/bootstrap` (backend de estado, OIDC, roles) se destruye aparte, y solo al final, porque los tres ambientes dependen de él mientras existan.
