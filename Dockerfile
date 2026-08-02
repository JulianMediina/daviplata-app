# Imagen inmutable: el bundle (dist/) y los tres config.<ambiente>.json viajan
# juntos. Qué ambiente sirve cada contenedor se decide en runtime (variable
# ENVIRONMENT), no en build -la misma imagen se promueve sin reconstruir,
# igual que el bundle .tar.gz que este Dockerfile reemplaza.
# Tag "alpine" (no una versión de nginx fijada) a propósito: se reconstruye
# seguido con los últimos parches de Alpine, a diferencia de un tag de minor
# fijo que puede quedar con paquetes de SO desactualizados durante meses. El
# scan de Trivy en release.yml es el que de verdad confirma que no hay
# CRITICAL/HIGH sin parchar en cada build, no una versión fija "de una vez".
FROM nginxinc/nginx-unprivileged:alpine

# El resto de dist/ queda de solo lectura para el usuario de runtime (no hay
# razón para que un proceso comprometido pueda modificar el sitio servido);
# solo config.json y version.json necesitan ser reescribibles, porque
# 40-inject-config.sh los reemplaza en cada arranque de contenedor.
COPY dist/ /usr/share/nginx/html/
COPY --chown=nginx:nginx dist/config.json dist/version.json /usr/share/nginx/html/
COPY config/ /etc/daviplata/config/
COPY docker/default.conf /etc/nginx/conf.d/default.conf

# La imagen base ya corre como usuario no-root (nginx-unprivileged) desde
# antes de esta capa: un RUN chmod normal falla porque el build no es dueño
# de /docker-entrypoint.d. --chmod en el COPY evita necesitar un paso RUN.
COPY --chmod=755 docker/40-inject-config.sh /docker-entrypoint.d/40-inject-config.sh

EXPOSE 8080
