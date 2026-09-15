--- Automatic mode: run language servers in a devcontainer without wrapping each `cmd` with
--- `devcontainers.lsp_cmd()` by hand.
---
--- The wrapping is done where `vim.lsp` resolves a client configuration, which is early enough for
--- two reasons. Servers whose `cmd` is set by someone else -- a `lsp/<name>.lua` runtime file, or a
--- plugin such as mason-lspconfig -- are already merged in by then. And `vim.lsp` refuses to start
--- a server whose `cmd` is not executable on the host, which for this plugin is the normal case:
--- turning `cmd` into a function this early is what keeps a container-only server startable.
local M = {}

--- The `__index` of `vim.lsp.config` as it was before enable(), also the flag saying we are in.
---@type fun(self: table, name: string): vim.lsp.Config?
local original_index = nil

---@param name string
---@param config vim.lsp.Config
---@return boolean
local function wanted(name, config)
    local lsp_auto = require('devcontainers.config').lsp_auto
    if vim.is_callable(lsp_auto) then
        return lsp_auto(name, config) and true or false
    end
    return lsp_auto and true or false
end

--- Start wrapping. Idempotent, and setup() calls it for you when `lsp_auto` is set.
function M.enable()
    if original_index then
        return
    end

    local mt = getmetatable(vim.lsp.config)
    original_index = mt.__index

    ---@param name string
    ---@return vim.lsp.Config?
    mt.__index = function(self, name)
        local config = original_index(self, name)
        -- A cmd that is not a table is either already wrapped in lsp_cmd() or something we cannot
        -- inspect, which also makes repeated resolutions of the same config a no-op.
        if
            config
            and type(config.cmd) == 'table'
            and config.cmd[1] ~= 'devcontainer'
            and wanted(name, config)
        then
            require('devcontainers.log')().debug('auto: wrapping cmd of %s', name)
            -- In place: this is the resolved configuration vim.lsp builds and caches, not a table
            -- belonging to the user. Whether the server really ends up in a container is decided
            -- by lsp_cmd() once root_dir is known.
            config.cmd = require('devcontainers').lsp_cmd(config.cmd, {
                probe = require('devcontainers.config').lsp_auto_probe,
            })
        end
        return config
    end

    -- Configurations resolved before this point are cached with a plain cmd.
    vim.lsp.config('*', {})
end

--- Stop wrapping. Servers already running are not affected.
function M.disable()
    if not original_index then
        return
    end
    getmetatable(vim.lsp.config).__index = original_index
    original_index = nil
    vim.lsp.config('*', {})
end

return M
