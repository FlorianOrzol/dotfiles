-- ~/.config/nvim-gemini/init.lua

-- Funktion zum Laden des Gemini API-Keys aus der .credentials-Datei
local function load_gemini_key()
  local credentials_path = vim.fn.expand("~/.credentials")
  local ok, file = pcall(io.open, credentials_path, "r")

  if not ok or not file then
    vim.notify("Credentials-Datei nicht gefunden: " .. credentials_path, vim.log.levels.WARN)
    return
  end

  local key = file:read("*a") -- Lese die ganze Datei
  file:close()
  key = key:gsub("%s+", "") -- Entferne alle Leerzeichen und Zeilenumbrüche

  -- Korrigierte Überprüfung: Nur prüfen, ob der Schlüssel nicht leer ist
  if key and key ~= "" then
    vim.env.GEMINI_API_KEY = key
    -- vim.notify("Gemini API Key geladen.", vim.log.levels.INFO) -- Optional: für leisen Start auskommentieren
  else
    vim.notify("Bitte füge deinen Gemini API Key in " .. credentials_path .. " ein.", vim.log.levels.WARN)
  end
end

-- Lade den Schlüssel beim Start
load_gemini_key()

-- Bootstrap für lazy.nvim Plugin Manager
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable", -- latest stable release
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- Lade Konfigurationen, die in lua/plugins/init.lua liegen
require("lazy").setup({
    spec = {
        { import = "plugins.init" }, -- Korrigierter Importpfad
    },
})
