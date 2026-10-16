import { spawn } from "child_process";
import { existsSync, readFileSync } from "fs";
import { homedir, platform } from "os";
import { join } from "path";

export type Profile = {
  /** The folder name Chrome's --profile-directory takes, e.g. "Profile 2". */
  directory: string;
  name: string;
  email: string;
  avatar?: string;
};

type InfoCacheEntry = {
  name?: string;
  user_name?: string;
  gaia_picture_file_name?: string;
};

type LocalState = {
  profile?: {
    info_cache?: Record<string, InfoCacheEntry>;
    profiles_order?: string[];
  };
};

const IS_MAC = platform() === "darwin";

/** Where Chrome keeps its profiles: macOS under Application Support, Linux under XDG config. */
function userDataDir(): string {
  return IS_MAC
    ? join(homedir(), "Library", "Application Support", "Google", "Chrome")
    : join(homedir(), ".config", "google-chrome");
}

/**
 * Chrome lists every profile in `Local State`, in the order its own profile
 * picker shows them. Read it instead of scanning folders: leftover folders of
 * deleted profiles stay on disk, but drop out of `info_cache`.
 */
export function readProfiles(): Profile[] {
  const dataDir = userDataDir();
  const state = JSON.parse(
    readFileSync(join(dataDir, "Local State"), "utf8"),
  ) as LocalState;
  const cache = state.profile?.info_cache ?? {};
  const order = state.profile?.profiles_order ?? [];
  const directories = [
    ...order.filter((dir) => dir in cache),
    ...Object.keys(cache).filter((dir) => !order.includes(dir)),
  ];

  return directories.map((directory) => {
    const info = cache[directory];
    const picture = info.gaia_picture_file_name
      ? join(dataDir, directory, info.gaia_picture_file_name)
      : undefined;
    return {
      directory,
      name: info.name || directory,
      email: info.user_name ?? "",
      avatar: picture && existsSync(picture) ? picture : undefined,
    };
  });
}

/**
 * Turn what was typed into something Chrome opens: nothing is a new tab,
 * anything that looks like an address is visited, the rest is a Google search.
 */
export function toUrl(text: string): string {
  const query = text.trim();
  if (!query) return "chrome://newtab/";
  if (/^[a-z][a-z0-9+.-]*:\/\//i.test(query) || /^(about|chrome):/i.test(query))
    return query;
  if (!/\s/.test(query)) {
    if (/^(localhost|127\.0\.0\.1)(:\d+)?(\/|$)/i.test(query))
      return `http://${query}`;
    if (/^[^/]+\.[a-z]{2,}(:\d+)?(\/|$)/i.test(query)) return `https://${query}`;
  }
  return `https://www.google.com/search?q=${encodeURIComponent(query)}`;
}

/**
 * Hand the URL to Chrome for one profile. A running Chrome takes it as a new
 * tab in that profile's last window (or a new window with `newWindow`); a
 * stopped one starts with it. Detached, so closing the launcher can't kill it.
 */
export function openInProfile(
  profile: Profile,
  url: string,
  newWindow = false,
): void {
  const chromeArgs = [
    `--profile-directory=${profile.directory}`,
    ...(newWindow ? ["--new-window"] : []),
    url,
  ];
  const [file, args] = IS_MAC
    ? ["/usr/bin/open", ["-na", "Google Chrome", "--args", ...chromeArgs]]
    : ["google-chrome-stable", chromeArgs];
  spawn(file, args, { detached: true, stdio: "ignore" }).unref();
}
