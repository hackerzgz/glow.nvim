local api = vim.api

local mdfile_path;
local editor_winid;
local preview_winid;
local preview_bufnr;

local function has_value(tab, val)
    for _, value in ipairs(tab) do if value == val then return true end end
    return false
end

local M = {}

local function validate(path)
    -- TODO: download glow if bin not found

    -- trim and get the full path
    path = string.gsub(path, "%s+", "")
    path = string.gsub(path, "\"", "")
    path = path == "" and "%" or path
    path = vim.fn.expand(path)
    path = vim.fn.fnamemodify(path, ":p")

    -- check if file exists
    local file_exists = vim.fn.filereadable(path) == 1
    if not file_exists then
        api.nvim_err_writeln("file does not exists")
        return
    end

    -- check if file extension if validate markdown or not
    local ext = vim.fn.fnamemodify(path, ":e")
    if not has_value({
        "md", "markdown", "mkd", "mkdn", "mdwn", "mdtxt", "mdtext"
    }, ext) then
        api.nvim_err_writeln("glow only support markdown file")
        return
    end

    return path
end

local function open_window(path)
    -- calculate the size of splitted buffer
    local cursor_position = api.nvim_win_get_cursor(0);
    local line = cursor_position[1];
    -- local column = cursor_position[2];

    -- set minimum window width if user already set
    -- if glow_width and glow_width < win_width then glow_width = win_width end

    editor_winid = vim.fn.win_getid();
    -- local editor_bufnr = api.nvim_get_current_buf();

    vim.cmd("vnew")
    preview_winid = vim.fn.win_getid();

    preview_bufnr = api.nvim_create_buf(false, false);
    api.nvim_buf_set_option(preview_bufnr, "filetype", "glowpreview");
    api.nvim_win_set_buf(preview_winid, preview_bufnr);

    vim.fn.termopen(string.format("%s %s %s", "/usr/bin/glow", "--local",
                                  vim.fn.shellescape(path)));
    vim.cmd(string.format(":%s", line));

    -- FIXME: set buffer callback function via `nvim_buf_attach.on_changedtick` from editor
    -- Waiting for this issue: https://github.com/neovim/neovim/issues/13786
    -- print(editor_bufnr);
    -- api.nvim_buf_attach(editor_bufnr, false, {
    --     on_lines = function()
    --         print('on_lines triggered');
    --         -- vim.cmd(string.format("%s %s", "bd", preview_bufnr - 1));
    --         preview_bufnr = api.nvim_create_buf(false, false);

    --         api.nvim_set_current_win(preview_winid);
    --         api.nvim_win_set_buf(preview_winid, preview_bufnr);
    --         vim.fn.termopen(string.format("%s %s %s", "/usr/bin/glow",
    --                                       "--local", vim.fn.shellescape(path)));
    --         api.nvim_set_current_win(editor_winid);
    --     end,
    --     on_changedtick = function()
    --         print('on_changedtick triggered');
    --         vim.fn.termopen(string.format("%s %s %s", "/usr/bin/glow",
    --                                       "--local", vim.fn.shellescape(path)));
    --     end
    -- });

    -- return to the editor window
    vim.api.nvim_set_current_win(editor_winid);

    vim.api.nvim_exec([[
    augroup RefreshPreviewAutogroup
      autocmd!
      autocmd BufWritePost <buffer> :lua require("plugins/glow").refresh()
    augroup END
    ]], true)
end

local function close_preview_win()
    api.nvim_win_close(preview_winid, true);
    preview_winid = nil;

    vim.cmd(string.format("%s %s", "bdelete", preview_bufnr - 1));
    preview_bufnr = nil;
end

function M.glow(file)
    if preview_winid ~= nil then
        close_preview_win()
    else
        local path = validate(file)
        if path == nil then
            -- display error log
            return
        end
        mdfile_path = path;
        open_window(path)
    end
end

function M.refresh()
    if preview_bufnr == nil then return end -- no need to refresh any more

    local cursor_position = api.nvim_win_get_cursor(0);
    local line = cursor_position[1];

    vim.cmd(string.format("%s %s", "bdelete", preview_bufnr - 1));
    preview_bufnr = api.nvim_create_buf(false, false);
    api.nvim_buf_set_option(preview_bufnr, "filetype", "glowpreview");

    api.nvim_set_current_win(preview_winid);
    api.nvim_win_set_buf(preview_winid, preview_bufnr);
    vim.fn.termopen(string.format("%s %s %s", "/usr/bin/glow", "--local",
                                  vim.fn.shellescape(mdfile_path)));
    vim.cmd(string.format(":%s", line));
    api.nvim_set_current_win(editor_winid);
end

return M
