#!/bin/sh
# Ejecutado automáticamente por la imagen base (docker-entrypoint.d/) antes
# de arrancar nginx: fija config.json y version.json.environment al
# ambiente real del contenedor, sin reconstruir la imagen.
#
# El directorio web root es de solo lectura para el usuario nginx (solo
# config.json/version.json son suyos, ver Dockerfile) -por eso se escribe
# con redirección (abre-y-trunca el archivo existente) en vez de "cp"/
# "sed -i" (que intentan reemplazar el archivo completo, y para eso
# necesitan permiso de escritura sobre el directorio, no solo el archivo).
set -eu

: "${ENVIRONMENT:?falta la variable de entorno ENVIRONMENT}"

CONFIG_SRC="/etc/daviplata/config/config.${ENVIRONMENT}.json"
WEB_ROOT="/usr/share/nginx/html"

if [ ! -f "$CONFIG_SRC" ]; then
  echo "No existe $CONFIG_SRC" >&2
  exit 1
fi

cat "$CONFIG_SRC" > "${WEB_ROOT}/config.json"
sed "s/\"environment\": \"[^\"]*\"/\"environment\": \"${ENVIRONMENT}\"/" "${WEB_ROOT}/version.json" > /tmp/version.json
cat /tmp/version.json > "${WEB_ROOT}/version.json"
rm -f /tmp/version.json
