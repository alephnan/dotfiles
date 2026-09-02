-- LSP servers.
-- Nvim 0.12 loads server definitions from `lsp/` on the runtimepath, so
-- nvim-lspconfig is here only to ship those definitions -- we just enable
-- the servers we want.
--
-- Requires the servers on $PATH:
--   rustup component add rust-analyzer
--   npm i -g basedpyright @astral-sh/ruff
local servers = { "basedpyright", "ruff", "rust_analyzer" }

return {
  "neovim/nvim-lspconfig",
  event = { "BufReadPre", "BufNewFile" },
  config = function()
    vim.lsp.enable(servers)

    -- Diagnostics are signs-only by default
    vim.diagnostic.config({
      virtual_text = true,
      severity_sort = true,
    })

    -- 0.11+ already maps K, grn, gra, grr, gri, gO and insert-mode <C-s>
    vim.api.nvim_create_autocmd("LspAttach", {
      callback = function(args)
        vim.keymap.set("n", "gd", vim.lsp.buf.definition,
          { buffer = args.buf, desc = "Go to definition" })
      end,
    })
  end,
}
