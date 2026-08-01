# GitOps sin Kubernetes

No hay clúster ni controlador de reconciliación en este proyecto, así que "GitOps" se traduce aquí a un modelo de **rama por ambiente**, todo verificable en los repos y en el historial de GitHub Actions.

## 0. Modelo de ramas

`terraform-live` y `daviplata-app` tienen tres ramas largas, una por ambiente:

```
feature/algo → PR → integracion → PR → laboratorio → PR → main (producción)
```

- Todo cambio nace en `feature/*` (o `fix/*`) contra `integracion` — nunca directo a una rama de ambiente.
- La promoción entre ambientes es un PR entre ramas (`integracion`→`laboratorio`, `laboratorio`→`main`), no un simple gate sobre el mismo commit.
- Las tres ramas tienen protección: requieren PR + 1 revisión aprobada antes de mergear (`terraform-modules` es la excepción — se queda en trunk-based a `main`, porque no tiene "ambientes": se versiona por tag semántico y todo cambio igual entra por PR desde una rama `feature/*`).

## 1. Git como única fuente de verdad

Ningún cambio de infraestructura o de la app llega a AWS sin pasar antes por un PR mergeado en la rama del ambiente correspondiente. No existe un `terraform apply` ni un `aws s3 sync` manual desde una laptop — ni siquiera `terraform-foundation`, que tiene su propio `foundation-plan.yml`/`foundation-apply.yml` (ver su README para cómo resuelve la dependencia circular de su propio backend de estado).

## 2. Cambios declarativos, revisados antes de aplicarse

- **Infraestructura (`terraform-live`):** `plan-integracion.yml` / `plan-laboratorio.yml` / `plan-produccion.yml` corren `terraform plan` para el ambiente correspondiente en cada PR que apunte a esa rama, y comentan el resultado exacto — el revisor ve qué va a cambiar antes de aprobar.
- **Aplicación (`daviplata-app`):** `pr-validation.yml` construye y prueba el mismo bundle que luego se promueve, así que lo que se revisa en el PR es funcionalmente lo que se despliega. También valida que cada PR venga de la rama correcta según a dónde apunta (feature/fix/release → integracion; integracion → laboratorio; laboratorio → main), para que nadie salte un ambiente.

## 3. Reconciliación automatizada y auditable

- **`apply-integracion.yml` / `apply-laboratorio.yml` / `apply-produccion.yml`** (y sus equivalentes `deploy-*.yml` en `daviplata-app`) aplican al **cerrar** el PR de promoción correspondiente — no con un `push` directo a la rama. Usan `github.event.pull_request.head.sha`, el commit exacto que se revisó, para no depender de qué estrategia de merge usó GitHub (merge commit, squash o rebase cambian el SHA de la rama, pero no el del PR).
- **`drift-detection.yml`** corre `terraform plan -detailed-exitcode` a diario contra las tres ramas (cada una con el código real desplegado en su ambiente); si detecta divergencia, abre una incidencia automáticamente en vez de corregir en silencio — la corrección sigue pasando por PR.

## 4. Promoción sin reconstrucción

El artefacto de `daviplata-app` se construye **una sola vez**, al mergear a `integracion`, y se publica como un GitHub Release con **versión semántica** (`vX.Y.Z`, calculada por `scripts/next-version.sh` a partir de Conventional Commits: `feat:` → minor, `BREAKING CHANGE`/`!:` → major, cualquier otra cosa → patch). "Promover" a laboratorio o producción no reconstruye ni copia el archivo — es el mismo asset, descargado tal cual; `scripts/promote.sh` solo añade una línea a las notas del release marcando por qué ambiente pasó, para trazabilidad. Lo que se prueba en integración es, en bytes, lo que llega a producción — verificable comparando `version.json.commit` en los tres ambientes.

## Control de cambios

Branch protection en `integracion`/`laboratorio`/`main` (`terraform-live` y `daviplata-app`) exige PR + revisión antes de mergear; producción, además, exige aprobación explícita en su GitHub Environment antes de que `apply.yml`/`deploy.yml` corran contra ese ambiente. El historial de Git (quién y cuándo aprobó cada PR) más las notas de cada GitHub Release son, juntos, el registro de auditoría de la plataforma.

**Limitación conocida (cuenta individual):** GitHub permite que un administrador del repositorio evite (bypass) tanto el gate de revisión de PR como el de aprobación de Environment. En un equipo real, con revisores distintos al autor, este bypass no aplicaría porque el revisor sería otra persona. Aquí, al ser una cuenta de una sola persona, el control es honesto pero no absoluto — está documentado, no oculto.
