import { readFileSync, writeFileSync, existsSync, mkdirSync } from "fs";
import path from "path";

const SNIPPETS_DIR = path.join(process.env.HOME || "", ".config", "snippets");
const SNIPPETS_FILE = path.join(SNIPPETS_DIR, "snippets.json");

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

export function saveSnippets(snippets: Snippet[]): void {
  ensureFile();
  writeFileSync(SNIPPETS_FILE, JSON.stringify(snippets, null, 2), "utf-8");
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
