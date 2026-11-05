# Vim mode on macOS: reaching parity with Hyprland

Goal: the Mac behaves almost exactly like the Hyprland setup in
`config/.config/hypr/lua/vimmode.lua`. svim (SketchyVim) provides the vim engine,
Karabiner does the Escape timing, and JankyBorders plus SketchyBar show the mode.

## Target behaviour

| Behaviour | Hyprland (done) | Mac status |
|---|---|---|
| Single Esc reaches the app after 150ms | yes | done (task 2 widens it) |
| Esc Esc within 150ms enters NORMAL, nothing reaches the app | yes | done (only after typing in the field; task 2 fixes) |
| Esc in NORMAL goes to the app | yes | done (svim default) |
| Motions, operators, text objects, counts | HyprVim (subset) | done (svim is real vim, better than Linux) |
| Border green in NORMAL, orange in VISUAL, normal otherwise | yes | done (JankyBorders) |
| Mode label in the bar | waybar | done (SketchyBar) |
| Off in terminals | kitty, alacritty | done (svim blacklist) |
| WM shortcuts work in any mode | SUPER | **verify** (task 3) |
| Ctrl+h/j/k/l cycles app sections (F6 / Shift+F6) in NORMAL | yes | **todo** (task 4) |
| Each window remembers its mode | yes | accepted difference: svim resets to insert per field |
| Linear/WhatsApp links open in their apps | `open-link.sh` | Chrome setting only (task 5) |

## Task 1: apply and verify what is already committed

1. `git pull` in `~/Projects/dotfiles`.
2. Link svim and restart it (`setup-mac.sh` does the same):
   ```sh
   mkdir -p ~/.config/svim
   for f in blacklist svimrc svim.sh; do
     ln -sfn ~/Projects/dotfiles/config/.config/svim/$f ~/.config/svim/$f
   done
   brew services restart svim
   ```
   Grant Accessibility to svim if macOS asks.
3. `sketchybar --reload`. Karabiner reloads `karabiner.json` on its own.
4. Verify in Slack, Chrome and Notes:
   - type text, Esc Esc: border turns green, SketchyBar shows NORMAL, text box keeps focus
   - `w`, `b`, `ciw`, `dd`, `u` edit in place; `v` + `e` turns the border orange
   - `i` returns to typing, border goes back to normal
   - a single Esc still closes pop-ups (about 150ms late)
   - in kitty nothing changes and Esc is instant

How it fits together:
- `config/.config/svim/svimrc` maps insert-mode `<Esc>` to `<Nop>` so svim lets a plain Escape through
  to the app, and maps `<C-]>` to `<Esc>` as the real "enter NORMAL" key.
- `config/.config/karabiner/karabiner.json`, first rule: Escape (and Caps Lock on the built-in keyboard)
  waits 150ms. A second press inside that window sends Ctrl+]; otherwise it sends Escape.
- `config/.config/svim/svim.sh` runs on every mode change: sets the Karabiner variable `svim_insert`,
  recolors JankyBorders, and triggers the SketchyBar `svim_mode` event
  (`config/.config/sketchybar/items/svim.lua`).

## Task 2: gate the Escape delay by app, not by `svim_insert`

Problem: svim only runs `svim.sh` after the first keystroke in a field, so Esc Esc in a field you have not
typed in yet reaches the app instead of entering NORMAL.

Fix: in the Karabiner rule, replace the `variable_if svim_insert == 1` condition with a
`frontmost_application_unless` condition listing the terminals (`^net\.kovidgoyal\.kitty$`,
`^com\.googlecode\.iterm2$`, `^org\.alacritty$`, `^com\.apple\.Terminal$`). This matches Linux exactly:
the delay applies everywhere except terminals. Outside text fields a double Esc sends Ctrl+] to the app,
which nothing binds. Then drop `svim_insert` from `svim.sh`.

Optional: also skip the delay while svim is in NORMAL or VISUAL (set a `svim_vim` variable from
`svim.sh` and add `variable_unless svim_vim == 1`) so Esc in NORMAL is instant, like Linux.

## Task 3: AeroSpace `alt-` shortcuts while in NORMAL

svim only passes events that carry the Command modifier (`src/ax.c`, `ax_process_event`). In NORMAL every
other key, including Option combos, goes into vim. Check whether `alt-1`, `alt-t`, etc. still work while
the border is green. If they don't, apply the svim patch in task 6 (pass `FLAG_ALTERNATE`).

## Task 4: Ctrl+h/j/k/l cycles app sections in NORMAL

1. svim must let F6 through, otherwise vim eats it: svim patch in task 6.
2. `svim.sh`: set a Karabiner variable `svim_normal` to 1 when `MODE` is `N`, else 0.
3. Karabiner rule (with `variable_if svim_normal == 1` and the terminal exclusion):
   Ctrl+j and Ctrl+l send `f6`, Ctrl+h and Ctrl+k send Shift+`f6`.
4. Verify in Slack: focus moves sidebar, messages, thread.

## Task 5: links into web apps

No script needed on macOS. In Chrome, open `chrome://app-settings` in the profile that owns each installed
app (Linear is Profile 5 on Linux; check the Mac's profile) and turn on "Open supported links".
WhatsApp is the native app on the Mac (`alt-w`), so only Linear needs this.

## Task 6: svim patch (needed by tasks 3 and 4)

Build svim from source with two changes in `src/ax.c`, `ax_process_event`, right after the flags are read:

```c
#define FLAG_ALTERNATE 1 << 19
#define KEYCODE_F6 97

if (flags & (FLAG_COMMAND | FLAG_ALTERNATE)) return event;
if (CGEventGetIntegerValueField(event, kCGKeyboardEventKeycode) == KEYCODE_F6) return event;
```

(the second line replaces the existing `if (flags & FLAG_COMMAND) return event;`).

Steps:
1. Keep the change as `packages/svim/pass-option-and-f6.patch` in this repo.
2. Add a `setup-mac.sh` step: clone `https://github.com/FelixKratz/SketchyVim`, apply the patch, `make`,
   copy `bin/svim` over the brew one (`$(brew --prefix)/bin/svim`), `brew services restart svim`.
3. Re-run it after `brew upgrade svim`, or `brew pin svim` to stop upgrades from overwriting it.

## Out of scope on the Mac

- Monitor layout, SUPER+F hints (wl-kbptr), the waybar label: Linux only.
- Block-shaped text cursor: not possible system-wide on either OS; the border is the indicator.
