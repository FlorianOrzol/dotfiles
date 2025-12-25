-- ~/.config/nvim-gemini/lua/plugins/init.lua
-- Diese Datei importiert die Konfigurationen für alle Plugins.

return {
  -- 1. Plugin für Live Completion: minuet-ai.nvim (temporär deaktiviert)
  -- {
  --   "minuet-ai/minuet-ai.nvim",
  --   config = function()
  --     require("minuet").setup({
  --       model = {
  --         provider = "gemini",
  --         name = "gemini-3-flash-preview", -- Optimiert für Completion
  --         api_key = os.getenv("GEMINI_API_KEY"), -- Liest den Schlüssel aus der Umgebung
  --         params = {
  --           temperature = 0.5, -- Standardwert, anpassen nach Bedarf
  --           top_p = 0.95,
  --           top_k = 64,
  --         },
  --       },
  --     })
  --     vim.notify("minuet-ai.nvim (Gemini Completion) wurde geladen.", vim.log.levels.INFO)
  --   end,
  -- },

  -- 2. Plugin für interaktiven Chat: CopilotC-Nvim/CopilotChat.nvim
  {
    "CopilotC-Nvim/CopilotChat.nvim",
    branch = "main", -- Von canary auf main geändert
    dependencies = {
      { "nvim-lua/plenary.nvim" },
      { "nvim-telescope/telescope.nvim" },
    },
    config = function()
      require("CopilotChat").setup({
        debug = false, -- Auf true setzen für Debug-Meldungen
        show_help = false, -- Hilfefenster beim Start deaktivieren
        question_icon = "💬",
        answer_icon = "🤖",
        -- Standard-Backend auf Gemini setzen
        alias = {
          Gemini = {
            provider = "gemini",
            model = "gemini-3-pro-preview", -- Optimiert für Chat
            api_key = os.getenv("GEMINI_API_KEY"), -- Liest den Schlüssel aus der Umgebung
            temperature = 0.7, -- Standardwert, anpassen nach Bedarf
            top_p = 0.95,
            top_k = 64,
          },
        },
        -- Setze Gemini als Standard-Modell
        default_alias = "Gemini",
        -- Optionen für das Chat-Fenster (Side-Panel)
        window = {
          width = 0.3, -- 30% der Fensterbreite
          height = 0.8, -- 80% der Fensterhöhe
          placement = "split", -- Als Split öffnen
          position = "right", -- Auf der rechten Seite
          relative = "editor", -- Relativ zum Editor
        },
      })
      vim.notify("CopilotChat.nvim (Gemini Chat) wurde geladen.", vim.log.levels.INFO)
    end,
  },
}
