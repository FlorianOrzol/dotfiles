return {
  "nvim-lua/plenary.nvim",

  {
    "github/copilot.vim",
    event = "InsertEnter",
    config = function()
      vim.cmd('Copilot enable')
    end,
  },

  {
    "CopilotC-Nvim/CopilotChat.nvim",
    -- Ändern Sie 'canary' zu 'main'
    branch = "main",
    dependencies = {
      "nvim-lua/plenary.nvim",
    },
    config = function()
      require("CopilotChat").setup()
    end,
  },
}
