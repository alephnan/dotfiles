-- Completion menu. Pulls candidates from the LSP servers enabled in
-- `plugins/lsp.lua`; blink registers its own LSP capabilities globally,
-- so the two files need no wiring between them.
--
-- The fuzzy matcher is a Rust library. The prebuilt download is
-- unreliable here, so we build it from the local toolchain instead.
return {
  "saghen/blink.cmp",
  version = "1.*",
  build = "cargo build --release",
  event = "InsertEnter",
  opts = {
    -- <C-space> open, <C-n>/<C-p> cycle, <C-y> accept, <C-e> dismiss
    keymap = { preset = "default" },
    sources = {
      default = { "lsp", "path", "snippets", "buffer" },
    },
    signature = { enabled = true },
    fuzzy = {
      implementation = "rust",
      prebuilt_binaries = { download = false },
    },
  },
}
