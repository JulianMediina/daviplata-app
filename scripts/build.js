#!/usr/bin/env node
"use strict";

const fs = require("fs");
const path = require("path");

const SRC_DIR = path.resolve(__dirname, "..", "src");
const DIST_DIR = path.resolve(__dirname, "..", "dist");
const CONFIG_DIR = path.resolve(__dirname, "..", "config");

function copyRecursive(src, dest) {
  const stat = fs.statSync(src);

  if (stat.isDirectory()) {
    fs.mkdirSync(dest, { recursive: true });
    for (const entry of fs.readdirSync(src)) {
      copyRecursive(path.join(src, entry), path.join(dest, entry));
    }
    return;
  }

  fs.mkdirSync(path.dirname(dest), { recursive: true });
  fs.copyFileSync(src, dest);
}

function build() {
  // La imagen se construye una sola vez y se promueve sin reconstruir; este
  // "environment" es solo el valor inicial para desarrollo local.
  // docker/40-inject-config.sh sobrescribe config.json y version.json.environment
  // con el ambiente real en el arranque del contenedor, ya que eso sí cambia
  // por destino aunque el resto de la imagen no se toque.
  const environment = process.env.BUILD_ENVIRONMENT || "integracion";
  const version = process.env.BUILD_VERSION || "0.0.0-local";
  const commit = process.env.BUILD_COMMIT || "local";
  const buildTime = process.env.BUILD_TIME || new Date().toISOString();

  fs.rmSync(DIST_DIR, { recursive: true, force: true });
  copyRecursive(SRC_DIR, DIST_DIR);

  const versionTemplate = fs.readFileSync(path.join(SRC_DIR, "version.json.tmpl"), "utf8");
  const versionJson = versionTemplate
    .replace("__VERSION__", version)
    .replace("__COMMIT__", commit)
    .replace("__ENVIRONMENT__", environment)
    .replace("__BUILD_TIME__", buildTime);

  fs.writeFileSync(path.join(DIST_DIR, "version.json"), versionJson);
  fs.rmSync(path.join(DIST_DIR, "version.json.tmpl"));

  const configSrc = path.join(CONFIG_DIR, `config.${environment}.json`);
  fs.copyFileSync(configSrc, path.join(DIST_DIR, "config.json"));

  console.log(`Build lista en dist/ (environment=${environment}, version=${version}, commit=${commit})`);
}

build();
