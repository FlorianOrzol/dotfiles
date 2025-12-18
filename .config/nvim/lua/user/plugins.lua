return {
  "nvim-lua/plenary.nvim",

  {
    "github/copilot.vim",
	--event = "InsertEnter",
    config = function()
      vim.cmd('Copilot enable')
    end,
  },

  {
    "CopilotC-Nvim/CopilotChat.nvim",
    branch = "main",
    dependencies = {
      "nvim-lua/plenary.nvim",
    },
    config = function()
      -- Die Konfigurationsdatei wird hier geladen!
      require("copilot-config")
    end,
  },
}
