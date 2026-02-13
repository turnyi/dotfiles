import { exec } from "child_process";
import util from "util";
import { existsSync } from "fs";
import { access, stat } from "fs/promises";
import { constants } from "fs";
import path from "path";

const execp = util.promisify(exec);

export type Pkg = {
  name: string;
  current: string;
  available: string;
};

export async function fetchCheckupdates(): Promise<Pkg[]> {
  try {
    const { stdout: exists } = await execp(
      `bash -lc "command -v checkupdates || echo ''"`,
    );
    if (!exists.trim()) {
      throw new Error("checkupdates not found. Install pacman-contrib.");
    }

    const pkgs: Pkg[] = [];

    // Check official repos
    const { stdout: officialStdout } = await execp(
      `bash -lc "checkupdates || true"`,
    );
    const officialLines = officialStdout.trim().split("\n").filter(Boolean);
    pkgs.push(
      ...officialLines.map((line) => {
        const arrowIdx = line.indexOf("->");
        if (arrowIdx === -1)
          return { name: line.trim(), current: "", available: "" };
        const left = line.slice(0, arrowIdx).trim();
        const right = line.slice(arrowIdx + 2).trim();
        const parts = left.split(/\s+/);
        const name = parts.shift() ?? "";
        const current = parts.join(" ");
        const available = right;
        return { name, current, available };
      }),
    );

    // Check AUR with yay if available
    try {
      const { stdout: yayExists } = await execp(
        `bash -lc "command -v yay || echo ''"`,
      );
      if (yayExists.trim()) {
        const { stdout: aurStdout } = await execp(
          `bash -lc "yay -Qua || true"`,
        );
        const aurLines = aurStdout.trim().split("\n").filter(Boolean);
        pkgs.push(
          ...aurLines.map((line) => {
            const arrowIdx = line.indexOf("->");
            if (arrowIdx === -1)
              return { name: line.trim(), current: "", available: "" };
            const left = line.slice(0, arrowIdx).trim();
            const right = line.slice(arrowIdx + 2).trim();
            const parts = left.split(/\s+/);
            const name = parts.shift() ?? "";
            const current = parts.join(" ");
            const available = right;
            return { name, current, available };
          }),
        );
      }
    } catch (aurError) {
      console.log("AUR check failed, continuing with official repos only");
    }

    return pkgs;
  } catch (e: any) {
    const msg =
      e?.stderr?.toString().trim() ||
      e?.stdout?.toString().trim() ||
      e?.message ||
      "Unknown error";
    throw new Error(msg);
  }
}

export const toggleVicinae = (): void => {
  exec(`vicinae vicinae://toggle`);
};

export async function scriptIsExecutable(p: string): Promise<boolean> {
  try {
    const resolved = p.startsWith("~")
      ? path.join(process.env.HOME || "", p.slice(1))
      : p;

    const abs = path.isAbsolute(resolved) ? resolved : path.resolve(resolved);
    const s = await stat(abs);

    if (!s.isFile()) return false;
    await access(abs, constants.F_OK | constants.X_OK);
    return true;
  } catch (e) {
    console.error("scriptIsExecutable failed:", e);
    return false;
  }
}
