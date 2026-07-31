async function loadJson(path) {
  const response = await fetch(path, { cache: "no-store" });
  if (!response.ok) {
    throw new Error(`No se pudo cargar ${path}: HTTP ${response.status}`);
  }
  return response.json();
}

function setField(id, value) {
  document.getElementById(id).textContent = value;
}

async function render() {
  try {
    const version = await loadJson("version.json");
    setField("field-environment", version.environment ?? "desconocido");
    setField("field-version", version.version ?? "desconocido");
    setField("field-commit", version.commit ?? "desconocido");
    setField("field-build-time", version.build_time ?? "desconocido");
  } catch (error) {
    setField("field-environment", "error");
    setField("field-version", "error");
    setField("field-commit", "error");
    setField("field-build-time", "error");
  }

  try {
    const health = await loadJson("health.json");
    setField("field-health", health.status ?? "desconocido");
  } catch (error) {
    setField("field-health", "no disponible");
  }
}

render();
