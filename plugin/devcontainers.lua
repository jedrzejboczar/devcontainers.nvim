local augroup = vim.api.nvim_create_augroup('devcontainers', { clear = true })

local log_filetype_added = false

vim.api.nvim_create_user_command('DevcontainersLog', function(args)
    -- Delay requiring the log module so that user has time to configure logging settings before its loaded
    local log_path = require('devcontainers.log')().path
    if not log_filetype_added then
        log_filetype_added = true
        vim.filetype.add {
            filename = {
                [log_path] = 'devcontainers-log',
            },
        }
    end
    vim.cmd { cmd = 'edit', args = { log_path }, mods = args.smods }
end, { desc = 'devcontainers.nvim: open log' })

vim.api.nvim_create_user_command('DevcontainersUp', function(args)
    local manager = require('devcontainers.manager')
    local log = require('devcontainers.log')()
    local utils = require('devcontainers.utils')

    local workspace_dir = manager.find_workspace_dir()
    if not workspace_dir then
        log.notify.error('Could not find devcontainers workspace directory')
        return
    end

    coroutine.wrap(manager.ensure_up)(workspace_dir)
end, { desc = 'devcontainers.nvim: start devcontainer' })

vim.api.nvim_create_user_command('DevcontainersExec', function(args)
    local cli = require('devcontainers.cli')
    local manager = require('devcontainers.manager')
    local log = require('devcontainers.log')()

    local workspace_dir = manager.find_workspace_dir()
    if not workspace_dir then
        log.notify.error('Could not find devcontainers workspace directory')
        return
    end

    coroutine.wrap(function()
        local result = cli.exec(workspace_dir, args.fargs)
        print(result.stdout)
    end)()
end, { nargs = '+', desc = 'devcontainers.nvim: execute command in container' })

vim.api.nvim_create_autocmd({ 'BufNew', 'BufReadPre', 'BufReadPost', 'BufAdd' }, {
    group = augroup,
    pattern = 'docker://*',
    callback = function(args)
        local log = require('devcontainers.log').plugin
        log.trace('%s matched docker:// for buf=%s', args.event, args.buf)
        if args.event == 'BufNew' then
            vim.bo[args.buf].buftype = 'nofile'
        elseif args.event == 'BufAdd' then
            vim.bo[args.buf].modifiable = false
        end
    end
})
