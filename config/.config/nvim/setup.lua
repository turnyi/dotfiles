vim.opt.termguicolors = true
package.path = package.path .. ";" .. vim.fn.expand("$HOME") .. "/.luarocks/share/lua/3.9.2/?/init.lua;"
package.path = package.path .. ";" .. vim.fn.expand("$HOME") .. "/.luarocks/share/lua/3.9.2/?.lua;"
require("plugins")
require("plugins")
