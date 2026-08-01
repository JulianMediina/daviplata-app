#!/usr/bin/env bash
# Calcula la siguiente versión semántica a partir del último tag vX.Y.Z
# alcanzable desde HEAD y el mensaje del commit que se está construyendo,
# siguiendo Conventional Commits: "BREAKING CHANGE"/"!:" -> major,
# "feat:" -> minor, cualquier otra cosa (fix:, chore:, etc.) -> patch.
# Requiere que el checkout tenga el historial y los tags completos
# (fetch-depth: 0 en actions/checkout).
# Uso: next-version.sh [<commit-ish>]
set -euo pipefail

COMMIT="${1:-HEAD}"
LAST_TAG=$(git describe --tags --match "v[0-9]*.[0-9]*.[0-9]*" --abbrev=0 "${COMMIT}" 2>/dev/null || echo "v0.0.0")

MAJOR=$(echo "${LAST_TAG#v}" | cut -d. -f1)
MINOR=$(echo "${LAST_TAG#v}" | cut -d. -f2)
PATCH=$(echo "${LAST_TAG#v}" | cut -d. -f3)

MESSAGE=$(git log -1 --pretty=%B "${COMMIT}")

if echo "${MESSAGE}" | grep -qE "BREAKING CHANGE|^[a-z]+(\([^)]*\))?!:"; then
  MAJOR=$((MAJOR + 1))
  MINOR=0
  PATCH=0
elif echo "${MESSAGE}" | grep -qE "^feat(\([^)]*\))?:"; then
  MINOR=$((MINOR + 1))
  PATCH=0
else
  PATCH=$((PATCH + 1))
fi

echo "v${MAJOR}.${MINOR}.${PATCH}"
