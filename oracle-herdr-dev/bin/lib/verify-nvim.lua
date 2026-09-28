-- Headless Neovim checks, run by bin/verify-environment with the user config loaded:
--   VERIFY_WORKTREE=~/worktrees/1 nvim --headless "+luafile verify-nvim.lua"
-- (`nvim -l` would skip init.lua, so the worktree comes in through the environment.)
-- Prints one "OK: ..." / "FAIL: ..." line per check and exits non-zero on failure.
local worktree = vim.env.VERIFY_WORKTREE
if not worktree or vim.fn.isdirectory(worktree) == 0 then
  io.stderr:write("usage: VERIFY_WORKTREE=<worktree-dir> nvim --headless +'luafile verify-nvim.lua'\n")
  os.exit(2)
end

local failures = 0
local function ok(msg) io.stdout:write("OK:   " .. msg .. "\n"); io.stdout:flush() end
local function fail(msg) failures = failures + 1; io.stdout:write("FAIL: " .. msg .. "\n"); io.stdout:flush() end
local function check(cond, msg, detail)
  if cond then ok(msg) else fail(msg .. (detail and (" -- " .. tostring(detail)) or "")) end
  return cond
end

local function main()
-- 1. plugins loaded by lazy.nvim
local lazy_ok, lazy = pcall(require, "lazy")
check(lazy_ok, "lazy.nvim loaded")
if lazy_ok then
  local missing = {}
  for _, p in ipairs(lazy.plugins()) do
    if not p._.installed then table.insert(missing, p.name) end
  end
  check(#missing == 0, "all lazy.nvim plugins installed", table.concat(missing, ","))
  -- Lazy-loaded plugins (conform, telescope, blink, ...) are loaded on demand in
  -- normal use; load them explicitly here so require() below works headlessly.
  lazy.load({ plugins = { "conform.nvim", "telescope.nvim", "telescope-fzf-native.nvim", "blink.cmp", "oil.nvim", "gitsigns.nvim", "which-key.nvim", "nvim-autopairs", "lualine.nvim" } })
end
for _, mod in ipairs({ "blink.cmp", "conform", "telescope", "oil", "gitsigns", "which-key", "nvim-autopairs", "lualine", "nvim-treesitter" }) do
  check(pcall(require, mod), "require('" .. mod .. "')")
end

-- 2. treesitter parsers (wait for the async install kicked off by the plugin spec)
local ts = require("nvim-treesitter")
local want = { "typescript", "tsx", "javascript", "go", "gomod", "gosum", "gowork", "json", "css", "html", "lua" }
ts.install(want):wait(600000)
local installed = {}
for _, l in ipairs(ts.get_installed("parsers")) do installed[l] = true end
local missing = {}
for _, l in ipairs(want) do if not installed[l] then table.insert(missing, l) end end
check(#missing == 0, "treesitter parsers: " .. table.concat(want, " "), "missing " .. table.concat(missing, ","))

-- 3. telescope + native fzf + external tools
check(vim.fn.executable("rg") == 1 and vim.fn.executable("fd") == 1, "telescope deps: rg and fd on PATH")
local tel_ok = pcall(require, "telescope.builtin")
local fzf_ok = tel_ok and pcall(function() return require("telescope").extensions.fzf end)
check(fzf_ok, "telescope-fzf-native loaded (compiled)")

-- 4. blink.cmp fuzzy implementation
local blink_impl = "unknown"
pcall(function()
  local fuzzy = require("blink.cmp.fuzzy")
  if fuzzy.get_implementation then
    blink_impl = fuzzy.get_implementation() and fuzzy.get_implementation().name or "lua"
  end
end)
ok("blink.cmp fuzzy implementation: " .. tostring(blink_impl))

-- helpers -------------------------------------------------------------------
local function open(path)
  vim.cmd.edit(path)
  local buf = vim.api.nvim_get_current_buf()
  vim.cmd.doautocmd("BufReadPost")
  return buf
end

local function wait_client(buf, name, ms)
  local found
  vim.wait(ms or 30000, function()
    for _, c in ipairs(vim.lsp.get_clients({ bufnr = buf })) do
      if c.name == name and c.initialized then found = c; return true end
    end
    return false
  end, 200)
  return found
end

-- Returns the list of {uri, line} definition targets for a position, following one
-- extra hop when the first answer is an import binding in the same file (tsserver
-- reports the local import specifier before the real declaration).
local function definitions_at(buf, client, line, col, hop)
  local params = {
    textDocument = { uri = vim.uri_from_bufnr(buf) },
    position = { line = line, character = col },
  }
  local res = client:request_sync("textDocument/definition", params, 15000, buf)
  if not res or res.err or not res.result then return {} end
  local r = res.result
  if not vim.islist(r) then r = { r } end
  local out = {}
  for _, loc in ipairs(r) do
    local range = loc.targetSelectionRange or loc.targetRange or loc.range
    table.insert(out, { uri = loc.uri or loc.targetUri, line = range and range.start.line, col = range and range.start.character })
  end
  if hop ~= false and #out == 1 and out[1].uri == vim.uri_from_bufnr(buf) and out[1].line ~= line then
    vim.list_extend(out, definitions_at(buf, client, out[1].line, out[1].col, false))
  end
  return out
end

local function definition_uri_matching(buf, client, line, col, needle)
  local seen = {}
  for _, d in ipairs(definitions_at(buf, client, line, col)) do
    table.insert(seen, d.uri)
    if d.uri and d.uri:find(needle, 1, true) then return d.uri, seen end
  end
  return nil, seen
end

local function references_at(buf, client, line, col)
  local params = {
    textDocument = { uri = vim.uri_from_bufnr(buf) },
    position = { line = line, character = col },
    context = { includeDeclaration = true },
  }
  local res = client:request_sync("textDocument/references", params, 15000, buf)
  return res and res.result and #res.result or 0
end

local function find_pos(buf, needle)
  for i, l in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
    local s = l:find(needle, 1, true)
    if s then return i - 1, s - 1 end
  end
end

local function format_scratch(path, before)
  vim.fn.writefile(vim.split(before, "\n"), path)
  local buf = open(path)
  local conform = require("conform")
  local ok_fmt, err = conform.format({ bufnr = buf, timeout_ms = 15000, lsp_format = "never", quiet = true })
  local after = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
  vim.cmd("silent! bwipeout! " .. buf)
  vim.fn.delete(path)
  return ok_fmt, after, err
end

-- 5. TypeScript / TSX: vtsls + eslint attach, definition, references, oxfmt --------
local tsx = worktree .. "/frontend/src/App.tsx"
if check(vim.fn.filereadable(tsx) == 1, "fixture file " .. tsx) then
  local buf = open(tsx)
  local vtsls = wait_client(buf, "vtsls", 60000)
  if check(vtsls ~= nil, "vtsls attached to App.tsx") then
    -- wait for the project to load (first request can be slow on a cold start)
    local line, col = find_pos(buf, "<Counter ")
    local uri, seen
    vim.wait(60000, function()
      uri, seen = definition_uri_matching(buf, vtsls, line, col + 1, "components/Counter.tsx")
      return uri ~= nil
    end, 500)
    check(uri ~= nil, "vtsls go-to-definition Counter -> components/Counter.tsx", vim.inspect(seen))
    local nrefs = references_at(buf, vtsls, line, col + 1)
    check(nrefs >= 2, "vtsls references for Counter (>=2)", nrefs)
    -- the workspace TypeScript (frontend/node_modules/typescript) should be in use
    local ws_ts = worktree .. "/frontend/node_modules/typescript/package.json"
    check(vim.fn.filereadable(ws_ts) == 1, "workspace TypeScript present (autoUseWorkspaceTsdk target)")
  end
  local eslint = wait_client(buf, "eslint", 30000)
  check(eslint ~= nil, "eslint language server attached to App.tsx")

  -- conform must resolve the project-local oxfmt
  local info = require("conform").get_formatter_info("oxfmt", buf)
  check(info.available and info.command:find("node_modules/.bin/oxfmt", 1, true) ~= nil,
    "conform resolves project-local oxfmt", vim.inspect({ available = info.available, command = info.command }))
  vim.cmd("silent! bwipeout! " .. buf)

  local ok_fmt, after = format_scratch(worktree .. "/frontend/src/__verify_format.tsx",
    'export const answer = { "a":1,"b":2 };\nexport function f( x:number ){ return x+1; }\n')
  check(ok_fmt and after:find("const answer = { a: 1, b: 2 }", 1, true) ~= nil and after:find(";", 1, true) == nil,
    "oxfmt formats a TSX buffer via conform", after)
end

-- 6. Go: gopls attach, definition, references, goimports/gofmt ------------------
local gofile = worktree .. "/backend/cmd/server/main.go"
if check(vim.fn.filereadable(gofile) == 1, "fixture file " .. gofile) then
  local buf = open(gofile)
  local gopls = wait_client(buf, "gopls", 60000)
  if check(gopls ~= nil, "gopls attached to main.go") then
    local line, col = find_pos(buf, "greeting.NewService(")
    local uri, seen
    vim.wait(60000, function()
      uri, seen = definition_uri_matching(buf, gopls, line, col + #"greeting." + 1, "internal/greeting/greeting.go")
      return uri ~= nil
    end, 500)
    check(uri ~= nil, "gopls go-to-definition NewService -> internal/greeting/greeting.go", vim.inspect(seen))
    local nrefs = references_at(buf, gopls, line, col + #"greeting." + 1)
    check(nrefs >= 2, "gopls references for NewService (>=2)", nrefs)
  end
  local ginfo = require("conform").get_formatter_info("goimports", buf)
  check(ginfo.available, "conform finds goimports", ginfo.command)
  local gfinfo = require("conform").get_formatter_info("gofmt", buf)
  check(gfinfo.available, "conform finds gofmt (fallback)", gfinfo.command)
  vim.cmd("silent! bwipeout! " .. buf)

  -- unindented body + missing import: goimports must add the tab and the import block
  local ok_fmt, after = format_scratch(worktree .. "/backend/cmd/server/__verify_format.go",
    'package main\nfunc main() {\nfmt.Println("x")\n}\n')
  check(ok_fmt and after:find('import "fmt"', 1, true) ~= nil and after:find('\n\tfmt.Println("x")\n', 1, true) ~= nil,
    "goimports formats a Go buffer via conform (adds import + indentation)", after)
end

end

-- Any uncaught error must still end the headless process (otherwise nvim keeps running).
local ran, err = pcall(main)
if not ran then fail("script error: " .. tostring(err)) end
io.stdout:write(string.format("nvim checks: %d failure(s)\n", failures))
io.stdout:flush()
os.exit(failures == 0 and 0 or 1)
