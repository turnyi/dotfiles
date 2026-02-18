import { readFileSync, writeFileSync, existsSync, mkdirSync } from "fs";
import { exec } from "child_process";
import path from "path";

const HOME = process.env.HOME || "";
const SNIPPETS_DIR = path.join(HOME, ".config", "snippets");
const SNIPPETS_FILE = path.join(SNIPPETS_DIR, "snippets.json");
const SYNC_SCRIPT = path.join(SNIPPETS_DIR, "sync-snippets.sh");

export type Snippet = {
  id: string;
  name: string;
  keyword: string;
  content: string;
  category: string;
};

function ensureFile(): void {
  if (!existsSync(SNIPPETS_DIR)) {
    mkdirSync(SNIPPETS_DIR, { recursive: true });
  }
  if (!existsSync(SNIPPETS_FILE)) {
    writeFileSync(SNIPPETS_FILE, "[]", "utf-8");
  }
}

export function loadSnippets(): Snippet[] {
  ensureFile();
  const raw = readFileSync(SNIPPETS_FILE, "utf-8");
  return JSON.parse(raw) as Snippet[];
}

function syncEspanso(): void {
  if (existsSync(SYNC_SCRIPT)) {
    exec(`bash "${SYNC_SCRIPT}"`);
  }
}

export function saveSnippets(snippets: Snippet[]): void {
  ensureFile();
  writeFileSync(SNIPPETS_FILE, JSON.stringify(snippets, null, 2), "utf-8");
  syncEspanso();
}

export function addSnippet(snippet: Omit<Snippet, "id">): Snippet {
  const snippets = loadSnippets();
  const id = Date.now().toString(36);
  const entry: Snippet = { id, ...snippet };
  snippets.push(entry);
  saveSnippets(snippets);
  return entry;
}

export function deleteSnippet(id: string): void {
  const snippets = loadSnippets().filter((s) => s.id !== id);
  saveSnippets(snippets);
}
