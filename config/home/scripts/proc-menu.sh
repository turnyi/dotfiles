#!/usr/bin/env bash
# proc-menu — minimal live process monitor, same popup family as pf-menu / the ★
# bookmarks menu. Four metrics only: CPU%, RAM (MB/GB), GPU%, threads. No PID, no tree,
# no chrome. Rows are the heaviest consumers of the ACTIVE sort, top first.
#
#   tab      cycle sort:  CPU → RAM → GPU → THR → CPU
#            the sorted column lights up mauve in the header.
#   C-f      search mode: type to filter by process name (esc leaves search).
#   j / k    move        g / G  top / bottom      esc / q  close (silent)
#
# The list re-samples itself every 2s (fzf load-loop), so it stays live without a
# blocking foreground like htop. GPU% is per-process SM utilisation from
# `nvidia-smi pmon`; it reads 0 on machines with no nvidia-smi or an idle GPU.
#
#   proc-menu           picker in the current terminal
#   proc-menu --popup   centered tmux popup (bind a key to this)
#   proc-menu --float   floating terminal window (waybar click / WM bind)
#   proc-menu --list    emit the row feed for the active sort (fzf reload)
#   proc-menu --header   emit the header line (fzf transform-header)
#   proc-menu --header-full  thermals block + header line
#   proc-menu --cycle   advance the sort key (tab)
set -uo pipefail

SELF="$HOME/scripts/proc-menu.sh"
RUN_DIR="${XDG_RUNTIME_DIR:-$HOME/.cache}/proc-menu"
SORT_FILE="$RUN_DIR/sort"
TOP=22
mkdir -p "$RUN_DIR"

# Catppuccin Mocha.
RED=$'\033[38;2;243;139;168m'; YEL=$'\033[38;2;249;226;175m'
GRN=$'\033[38;2;166;227;161m'; MAUVE=$'\033[38;2;203;166;247m'
DIM=$'\033[38;2;127;132;156m'; BLUE=$'\033[38;2;137;180;250m'
BOLD=$'\033[1m'; RST=$'\033[0m'

sortkey() { case "$(cat "$SORT_FILE" 2>/dev/null)" in ram|gpu|thr) cat "$SORT_FILE" ;; *) echo cpu ;; esac; }
# Compute next, THEN write. `case … esac >FILE` would truncate FILE before the
# `$(sortkey)` word is expanded, so it would always read empty and reset to ram.
cycle() {
  local next
  case "$(sortkey)" in
    cpu) next=ram ;; ram) next=gpu ;; gpu) next=thr ;; *) next=cpu ;;
  esac
  printf '%s\n' "$next" >"$SORT_FILE"
}

# Idle rows stay calm (dim); a metric only gains colour once it is actually
# consuming, shading green → yellow → red so real hogs jump out at a glance.
shade() {
  local pct="${1%.*}"; pct="${pct:-0}"
  if   ((pct >= 85)); then printf '%s' "$RED"
  elif ((pct >= 60)); then printf '%s' "$YEL"
  elif ((pct >= 15)); then printf '%s' "$GRN"
  else printf '%s' "$DIM"; fi
}

feed() {
  local key; key=$(sortkey)

  declare -A GPU=()
  if command -v nvidia-smi >/dev/null 2>&1; then
    local _g pid _ty sm cur
    while read -r _g pid _ty sm _rest; do
      [[ $pid =~ ^[0-9]+$ && $sm =~ ^[0-9]+$ ]] || continue
      cur=${GPU[$pid]:-0}; ((sm > cur)) && GPU[$pid]=$sm
    done < <(timeout 3 nvidia-smi pmon -c 1 2>/dev/null)
  fi

  # RAM is shown as real resident memory (MB/GB), but shaded by its share of
  # MemTotal — a raw byte count carries no sense of "is this a lot on this box".
  local total_kb; total_kb=$(awk '/^MemTotal:/ {print $2; exit}' /proc/meminfo)

  # pid<TAB>cpu<TAB>rssKB<TAB>thr<TAB>gpu<TAB>name, then sort by the active column.
  local col; case "$key" in ram) col=3 ;; thr) col=4 ;; gpu) col=5 ;; *) col=2 ;; esac
  local pid cpu rss thr comm gpu
  ps -eo pid=,%cpu=,rss=,nlwp=,comm= | while read -r pid cpu rss thr comm; do
    gpu=${GPU[$pid]:-0}
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$pid" "$cpu" "$rss" "$thr" "$gpu" "$comm"
  done | sort -t$'\t' -k"${col}nr" | head -n "$TOP" | while IFS=$'\t' read -r pid cpu rss thr gpu comm; do
    local cf rf gf tf rampct tenths
    if ((rss >= 1048576)); then   # >= 1 GiB, in KB
      tenths=$((rss * 10 / 1048576))
      printf -v rf '%d.%dG' $((tenths / 10)) $((tenths % 10))
    else
      printf -v rf '%dM' $((rss / 1024))
    fi
    printf -v rf '%5s' "$rf"
    rampct=$((total_kb > 0 ? 100 * rss / total_kb : 0))
    cf=$(printf '%3.0f%%' "$cpu")
    gf=$(printf '%3d%%' "$gpu");   tf=$(printf '%4d' "$thr")
    printf ' %s%s%s  %s%s%s  %s%s%s  %s%s%s   %s%s%s\n' \
      "$(shade "$cpu")" "$cf" "$RST" \
      "$(shade "$rampct")" "$rf" "$RST" \
      "$(shade "$gpu")" "$gf" "$RST" \
      "$BLUE" "$tf" "$RST" \
      "$DIM" "$comm" "$RST"
  done
}

# Column labels double as the sort selector: the active column is mauve+bold, the
# rest dim, each sitting above its data column (widths kept in lock-step w/ feed).
header() {
  local key; key=$(sortkey)
  local c=$DIM r=$DIM g=$DIM t=$DIM
  case "$key" in
    cpu) c="$MAUVE$BOLD" ;; ram) r="$MAUVE$BOLD" ;;
    gpu) g="$MAUVE$BOLD" ;; thr) t="$MAUVE$BOLD" ;;
  esac
  printf ' %s%4s%s  %s%5s%s  %s%4s%s  %s%4s%s   %sprocess%s' \
    "$c" CPU "$RST" "$r" RAM "$RST" "$g" GPU "$RST" "$t" THR "$RST" "$DIM" "$RST"
}

header_full() {
  "$HOME/scripts/thermals.sh" --lines
  printf '\n\n'
  header
}

menu() {
  echo cpu >"$SORT_FILE"   # every open starts CPU-sorted, tab moves from there
  : | fzf --ansi --reverse --no-sort --no-input --height=100% \
    --header-first --header-lines=0 \
    --footer=" ${DIM}tab sort · C-f search · j/k move · q quit${RST}" \
    --bind="start:reload($SELF --list)+transform-header($SELF --header-full)" \
    --bind="load:reload(sleep 2; $SELF --list)+transform-header($SELF --header-full)" \
    --bind='j:down,k:up,g:first,G:last' \
    --bind="tab:execute-silent($SELF --cycle)+reload($SELF --list)+transform-header($SELF --header-full)" \
    --bind='ctrl-f:show-input+unbind(j,k,g,G,q,tab)' \
    --bind='esc:transform:[[ $FZF_INPUT_STATE = enabled ]] && echo "hide-input+rebind(j,k,g,G,q,tab)+clear-query" || echo abort' \
    --bind='q:abort' >/dev/null
  local rc=$?
  case "$rc" in 0 | 1 | 130) return 0 ;; *) return "$rc" ;; esac
}

case "${1:-menu}" in
  --list)       feed ;;
  --header)     header ;;
  --header-full) header_full ;;
  --cycle)      cycle ;;
  --menu | menu) menu ;;
  --popup)      exec tmux display-popup -E -w 46 -h 31 -T ' 󰻠 procs ' \
                  -b rounded -S 'fg=#cba6f7' -s 'bg=default' "$SELF --menu" ;;
  --float)      exec kitty --class proc-menu --title 'procs' \
                  -o "initial_window_width=46c" -o "initial_window_height=31c" \
                  -e "$SELF --menu" ;;
  -h | --help)  sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//' ;;
  *)            echo "usage: proc-menu [--popup|--float|--menu|--list]" >&2; exit 2 ;;
esac
