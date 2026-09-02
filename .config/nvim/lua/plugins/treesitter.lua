-- Parsers to install, and the filetypes that should use them.
-- The `main` branch no longer has highlight/indent modules -- we enable them
-- ourselves via `vim.treesitter.start()` on FileType.
local parsers = { "lua", "vim", "vimdoc", "bash", "python", "json" }
local filetypes = { "lua", "vim", "help", "sh", "bash", "python", "json" }

return {
  "nvim-treesitter/nvim-treesitter",
  branch = "main",
  lazy = false, -- the main branch does not support lazy-loading
  build = ":TSUpdate",
  config = function()
    require("nvim-treesitter").install(parsers)

    -- `sh` files are parsed by the bash grammar
    vim.treesitter.language.register("bash", "sh")

    vim.api.nvim_create_autocmd("FileType", {
      pattern = filetypes,
      callback = function()
        vim.treesitter.start()
        vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
      end,
    })
  end,
}
