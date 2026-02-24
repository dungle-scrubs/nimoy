#!/usr/bin/env npx tsx
/**
 * Crops input image to 2:1 aspect ratio, resizes to 1280×640 PNG,
 * and validates file size is under 1 MB.
 *
 * @param --input  Path to source image
 * @param --output Path for final PNG (should be assets/social-share.png)
 */

import { execSync } from "node:child_process";
import { statSync, copyFileSync } from "node:fs";
import { resolve } from "node:path";

const args = process.argv.slice(2);
const inputIdx = args.indexOf("--input");
const outputIdx = args.indexOf("--output");

if (inputIdx === -1 || outputIdx === -1) {
  console.error("Usage: finalize-social-share.ts --input <path> --output <path>");
  process.exit(1);
}

const input = resolve(args[inputIdx + 1]);
const output = resolve(args[outputIdx + 1]);

// Get current dimensions
const sizeOut = execSync(`sips -g pixelWidth -g pixelHeight "${input}"`).toString();
const width = parseInt(sizeOut.match(/pixelWidth:\s*(\d+)/)?.[1] ?? "0", 10);
const height = parseInt(sizeOut.match(/pixelHeight:\s*(\d+)/)?.[1] ?? "0", 10);

console.log(`Input: ${width}×${height}`);

// Work on a temp copy
const tmp = output.replace(/\.png$/, ".tmp.png");
copyFileSync(input, tmp);

// Crop to 2:1 aspect ratio (centered)
const targetRatio = 2;
const currentRatio = width / height;

if (currentRatio > targetRatio) {
  // Too wide — crop width
  const newWidth = Math.round(height * targetRatio);
  const cropX = Math.round((width - newWidth) / 2);
  execSync(`sips --cropOffset ${0} ${cropX} --cropToHeightWidth ${height} ${newWidth} "${tmp}"`);
  console.log(`Cropped to ${newWidth}×${height}`);
} else if (currentRatio < targetRatio) {
  // Too tall — crop height
  const newHeight = Math.round(width / targetRatio);
  const cropY = Math.round((height - newHeight) / 2);
  execSync(`sips --cropOffset ${cropY} ${0} --cropToHeightWidth ${newHeight} ${width} "${tmp}"`);
  console.log(`Cropped to ${width}×${newHeight}`);
}

// Resize to exact 1280×640
execSync(`sips --resampleHeightWidth 640 1280 "${tmp}"`);
execSync(`sips -s format png "${tmp}" --out "${output}"`);

// Clean up temp
execSync(`rm -f "${tmp}"`);

// Validate size
const finalSize = statSync(output).size;
const sizeMB = (finalSize / 1024 / 1024).toFixed(2);
console.log(`Output: 1280×640 — ${sizeMB} MB`);

if (finalSize > 1_048_576) {
  console.error(`ERROR: File size ${sizeMB} MB exceeds 1 MB limit`);
  process.exit(1);
}

console.log(`✓ Saved to ${output}`);
