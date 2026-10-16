-- Catppuccin Macchiato, frosted-glass edition.
-- Ported from the shell config at github.com/wthrajat/dotfiles-mac, adapted to
-- this Lua setup. Colours are ARGB (0xAARRGGBB): the leading byte is alpha, and
-- it is what makes the pills read as glass rather than as flat rectangles.

-- ── raw palette (opaque) ───────────────────────────────────────────────────
local p = {
  crust    = 0xff181926,
  mantle   = 0xff1e2030,
  base     = 0xff24273a,
  surface0 = 0xff363a4f,
  surface1 = 0xff494d64,
  overlay0 = 0xff6e738d,
  overlay1 = 0xff8087a2,
  subtext0 = 0xffa5adcb,
  text     = 0xffcad3f5,
  lavender = 0xffb7bdf8,
  blue     = 0xff8aadf4,
  sky      = 0xff91d7e3,
  teal     = 0xff8bd5ca,
  green    = 0xffa6da95,
  yellow   = 0xffeed49f,
  peach    = 0xfff5a97f,
  maroon   = 0xffee99a0,
  red      = 0xffed8796,
  mauve    = 0xffc6a0f6,
  pink     = 0xfff5bde6,
}

return {
  palette = p,

  -- ── named colours the widgets already reference ──────────────────────────
  -- Kept under their original names so every existing item re-themes without
  -- being touched; only the values move onto Macchiato.
  black = p.crust,
  white = p.text,
  red = p.red,
  green = p.green,
  blue = p.sky,
  yellow = p.yellow,
  orange = p.peach,
  magenta = p.mauve,
  grey = p.overlay1,
  transparent = 0x00000000,

  -- ── semantic layer ───────────────────────────────────────────────────────
  -- The reference paints every status icon the same sky blue, which looks
  -- tidy but means colour carries no information — a glance tells you nothing.
  -- Here a resting widget is neutral and colour only appears when a value has
  -- something to say, so the bar is scannable at a glance.
  muted = p.overlay1,    -- resting icon: present, not shouting
  accent = p.lavender,   -- focused / selected
  active = p.yellow,     -- playing, charging, running
  ok = p.green,
  warn = p.yellow,
  high = p.peach,
  crit = p.red,

  -- ── frosted surfaces ─────────────────────────────────────────────────────
  -- Alpha is doing the work: the pill is ~75% opaque over a 30px blur, so the
  -- wallpaper shows through as colour without ever reaching the text.
  bar = {
    bg = 0x00000000,     -- the bar itself draws nothing; only pills are visible
    border = p.surface0,
  },
  popup = {
    bg = 0xf01e2030,     -- mantle, near-opaque: popups must stay readable
    border = p.surface1,
  },

  -- bg1/bg2 are the pill fill and its outline. Every widget's bracket uses
  -- these two, which is why re-pointing them re-skins the whole bar.
  --
  -- The pill is blur, not paint. bg1 carries almost no colour of its own — it
  -- is just enough darkening to keep light text legible if the wallpaper
  -- behind it turns bright. The frosted look comes from blur_radius, so the
  -- pill reads as the wallpaper out of focus rather than as a grey rectangle.
  bg1 = 0x14181926,      -- crust @ 8%
  bg2 = 0x33494d64,      -- surface1 @ 20%, a hint of an edge

  highlight = p.yellow,  -- solid, so the active space pops off the glass

  with_alpha = function(color, alpha)
    if alpha > 1.0 or alpha < 0.0 then
      return color
    end
    return (color & 0x00ffffff) | (math.floor(alpha * 255.0) << 24)
  end,
}
