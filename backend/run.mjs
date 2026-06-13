// Windows-friendly Convex smoke test.
// Avoids CLI quoting issues by calling the HTTP API directly.
//
// Usage (from backend/ directory):
//   node run.mjs create "a hello world page"
//   node run.mjs get <project-id>

import { ConvexHttpClient } from "convex/browser";
import { readFileSync } from "fs";

function readConvexUrl() {
  try {
    const env = readFileSync(".env.local", "utf8");
    const m = env.match(/^CONVEX_URL=(.+)$/m);
    if (m) return m[1].trim();
  } catch {}
  if (process.env.CONVEX_URL) return process.env.CONVEX_URL;
  throw new Error("CONVEX_URL not found. Run from the backend/ directory.");
}

const client = new ConvexHttpClient(readConvexUrl());
const cmd = process.argv[2];

if (cmd === "create") {
  const prompt = process.argv.slice(3).join(" ") || "a hello world page";
  const id = await client.mutation("projects:create", { prompt });
  console.log("Created project:", id);
  console.log('\nCheck status with:  node run.mjs get ' + id);

} else if (cmd === "get") {
  const id = process.argv[3];
  if (!id) { console.error("Usage: node run.mjs get <project-id>"); process.exit(1); }
  const project = await client.query("projects:get", { id });
  console.log(JSON.stringify(project, null, 2));

} else {
  console.log("Usage:");
  console.log('  node run.mjs create "your prompt here"');
  console.log("  node run.mjs get <project-id>");
}
