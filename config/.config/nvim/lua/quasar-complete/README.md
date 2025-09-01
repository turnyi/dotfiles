# Quasar Completion Plugin

A Neovim plugin that provides intelligent auto-completion for Quasar CSS classes in Vue.js projects.

## Features

- **Smart Detection**: Automatically detects when you're typing in `class=""` or `:class=""` attributes in Vue templates
- **Comprehensive Coverage**: Includes 150+ Quasar CSS classes covering spacing, typography, colors, shadows, and components
- **Dual Integration**: Works with both nvim-cmp and Vim's built-in completion
- **Performance Optimized**: Lazy loading and suggestion limits for smooth performance
- **Configurable**: Customize filetypes, triggers, and suggestion limits

## Installation

The plugin is already integrated into your Neovim configuration via lazy.nvim.

## Configuration

The plugin is configured in `lua/plugins/quasar-complete.lua`:

```lua
require("quasar-complete").setup({
  filetypes = { "vue", "javascript", "typescript", "html" },
  max_suggestions = 50,
  trigger_characters = { "q-", "text-", "bg-", "border-", "shadow-" },
})
```

## Usage

1. Open a Vue file
2. Start typing in a `class=""` or `:class=""` attribute
3. Type trigger characters like `q-`, `text-`, `bg-`, etc.
4. Completion suggestions will appear automatically

### Examples

```vue
<template>
  <!-- Spacing classes -->
  <div class="q-pa-md q-mt-lg">
  
  <!-- Typography classes -->
  <h1 class="text-h1 text-primary">
  
  <!-- Color classes -->
  <button class="bg-primary text-white">
  
  <!-- Shadow classes -->
  <q-card class="shadow-3">
</template>
```

## Supported Classes

### Spacing
- `q-pa-*` - Padding all sides
- `q-px-*` - Padding horizontal
- `q-py-*` - Padding vertical
- `q-ma-*` - Margin all sides
- `q-mx-*` - Margin horizontal
- `q-my-*` - Margin vertical
- `q-mt-*`, `q-mr-*`, `q-mb-*`, `q-ml-*` - Margin individual sides

### Typography
- `text-h1` through `text-h6` - Headings
- `text-subtitle1`, `text-subtitle2` - Subtitles
- `text-body1`, `text-body2` - Body text
- `text-caption`, `text-overline` - Small text
- `text-weight-*` - Font weights
- `text-*` - Text colors

### Colors
- `bg-*` - Background colors
- `text-*` - Text colors
- `border-*` - Border colors

### Shadows
- `shadow-1` through `shadow-24` - Box shadows

## Keybindings

- `<C-n>` / `<C-p>` - Navigate completion items
- `<C-y>` - Accept completion
- `<C-e>` - Close completion menu

## Troubleshooting

If completions don't appear:
1. Make sure you're in a supported filetype (vue, js, ts, html)
2. Ensure you're typing within `class=""` or `:class=""` attributes
3. Try typing trigger characters like `q-`, `text-`, `bg-`

## Customization

You can customize the plugin by modifying the setup call in `lua/plugins/quasar-complete.lua`:

```lua
require("quasar-complete").setup({
  filetypes = { "vue", "svelte" }, -- Add more filetypes
  max_suggestions = 25,            -- Limit suggestions
  trigger_characters = { "q-" },   -- Custom triggers
  enable_builtin_completion = true -- Enable/disable built-in completion
})
```
