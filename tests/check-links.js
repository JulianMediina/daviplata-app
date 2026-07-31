#!/usr/bin/env node
"use strict";

const fs = require("fs");
const path = require("path");

const DIST_DIR = path.resolve(__dirname, "..", "dist");
const ATTR_PATTERN = /(?:href|src)="([^"]+)"/g;

function listHtmlFiles(dir) {
  return fs
    .readdirSync(dir, { withFileTypes: true })
    .flatMap((entry) => {
      const fullPath = path.join(dir, entry.name);
      if (entry.isDirectory()) {
        return listHtmlFiles(fullPath);
      }
      return entry.name.endsWith(".html") ? [fullPath] : [];
    });
}

function isExternal(link) {
  return /^(https?:)?\/\//.test(link) || link.startsWith("mailto:") || link.startsWith("#");
}

function checkFile(filePath) {
  const contents = fs.readFileSync(filePath, "utf8");
  const errors = [];
  let match;

  while ((match = ATTR_PATTERN.exec(contents)) !== null) {
    const link = match[1];
    if (isExternal(link)) {
      continue;
    }

    const cleanLink = link.split("#")[0].split("?")[0];
    const target = cleanLink.startsWith("/")
      ? path.join(DIST_DIR, cleanLink)
      : path.resolve(path.dirname(filePath), cleanLink);

    if (!fs.existsSync(target)) {
      errors.push(`${path.relative(DIST_DIR, filePath)}: enlace roto -> ${link}`);
    }
  }

  return errors;
}

function main() {
  if (!fs.existsSync(DIST_DIR)) {
    console.error(`No existe ${DIST_DIR}. Corre "make build" primero.`);
    process.exit(1);
  }

  const htmlFiles = listHtmlFiles(DIST_DIR);
  const allErrors = htmlFiles.flatMap(checkFile);

  if (allErrors.length > 0) {
    console.error("Enlaces rotos encontrados:");
    allErrors.forEach((error) => console.error(`  - ${error}`));
    process.exit(1);
  }

  console.log(`OK: ${htmlFiles.length} archivo(s) HTML sin enlaces locales rotos.`);
}

main();
