'use strict';

const fs = require('fs');
const file = process.env.DEVCONTAINER_JSON;

try {
  const rawData = fs
    .readFileSync(file, 'utf8')
    .replace(/\/\*[\s\S]*?\*\/|\/\/.*/g, '');
  const config = JSON.parse(rawData);

  const targetBase = 'ghcr.io/miguelrodo/devcontainerfeatures/build-info';
  let foundKey = null;

  if (config.features) {
    foundKey = Object.keys(config.features).find(
      (key) =>
        key.toLowerCase() === targetBase.toLowerCase() ||
        key.toLowerCase().startsWith(`${targetBase.toLowerCase()}:`),
    );
  }

  if (foundKey) {
    console.log(`💉 Injecting metadata into ${file}...`);
    console.log(`   Version: ${process.env.IMAGE_VERSION}`);

    const existingVal = config.features[foundKey];

    if (typeof existingVal === 'string') {
      config.features[foundKey] = {
        version: existingVal,
        imageVersion: process.env.IMAGE_VERSION,
      };
    } else if (typeof existingVal === 'object' && existingVal !== null) {
      config.features[foundKey].imageVersion = process.env.IMAGE_VERSION;
    } else {
      config.features[foundKey] = {
        imageVersion: process.env.IMAGE_VERSION,
      };
    }

    fs.writeFileSync(file, JSON.stringify(config, null, 4));
    console.log(`✅ Successfully injected build-info version into ${foundKey}.`);
  } else {
    console.log('⏭️ Feature build-info not found in devcontainer.json. Skipping injection.');
  }
} catch (err) {
  console.error('❌ Failed to inject metadata into devcontainer.json:', err.message);
  process.exit(1);
}
