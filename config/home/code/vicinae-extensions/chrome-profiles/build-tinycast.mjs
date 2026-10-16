// Build this vicinae extension for Tinycast, which runs Raycast extensions.
//
// The source imports @vicinae/api; vicinae's API mirrors Raycast's, so the
// same code runs once the import is pointed at @raycast/api. Tinycast supplies
// @raycast/api, react and the Node built-ins itself, so they stay external —
// the output is the layout `ray build` produces: package.json, assets/ and one
// CommonJS <command>.js per command. Install it with Tinycast's
// Settings → Extensions → Install New → Add from folder → dist-tinycast/.
import { build } from "esbuild";
import { cpSync, mkdirSync, readFileSync, rmSync } from "node:fs";

const OUT_DIR = "dist-tinycast";
const manifest = JSON.parse(readFileSync("package.json", "utf8"));

rmSync(OUT_DIR, { recursive: true, force: true });
mkdirSync(OUT_DIR, { recursive: true });

await build({
  entryPoints: manifest.commands.map((command) => ({
    in: `src/${command.name}.tsx`,
    out: command.name,
  })),
  outdir: OUT_DIR,
  bundle: true,
  format: "cjs",
  platform: "node",
  target: "es2020",
  jsx: "automatic",
  alias: { "@vicinae/api": "@raycast/api" },
  external: ["@raycast/api", "react", "react/jsx-runtime"],
});

cpSync("package.json", `${OUT_DIR}/package.json`);
cpSync("assets", `${OUT_DIR}/assets`, { recursive: true });
console.log(`Built ${manifest.commands.length} command(s) into ${OUT_DIR}/`);
