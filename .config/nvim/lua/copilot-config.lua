


-- Require the CopilotChat module and assign it to the local variable 'chat'.
-- This module is used for handling chat functionalities within the Copilot configuration.
local chat = require("CopilotChat")


-- Call the function to set the chat window width


chat.setup({
	window = {
		width = 60,
--		layout = 'float',
	},
    question_header = '',
    answer_header = '',
    error_header = '',
    allow_insecure = true,
    mappings = {
        reset = {
            normal = '',
            insert = '',
        },
    },
    prompts = {
        Explain = {
            mapping = '<leader>ge',
            description = 'AI Explain',
	    prompt = 'Erkläre den Code auf Deutsch:',
        },
        Review = {
            mapping = '<leader>gr',
            description = 'AI Review',
	    prompt = 'Überprüfe den Code auf Fehler:',
        },
        Tests = {
            mapping = '<leader>gt',
            description = 'AI Tests',
	    prompt = 'Schreibe Tests für den Code:',
        },
        Fix = {
            mapping = '<leader>gf',
            description = 'AI Fix',
	    prompt = 'Der Code hat Fehler. Bitte korrigiere ihn:',
        },
        Optimize = {
            mapping = '<leader>go',
            description = 'AI Optimize',
	    prompt = 'Optimiere den Code, um ihn schneller zu machen und lesbarer zu gestalten:',
        },
        Docs = {
            mapping = '<leader>gd',
            description = 'AI Documentation',
        },
--        CommitStaged = {
--            mapping = '<leader>ac',
--            description = 'AI Generate Commit',
--	    prompt = 'Schreibe eine Commit-Nachricht:',
--        },
    },
})

vim.keymap.set({ 'n', 'v' }, '<leader>ga', chat.toggle, { desc = 'AI Toggle' })
vim.keymap.set({ 'n', 'v' }, '<leader>gx', chat.reset, { desc = 'AI Reset' })
--vim.keymap.set({ 'n', 'v' }, '<leader>gh', pick(actions.help_actions), { desc = 'AI Help Actions' })
--vim.keymap.set({ 'n', 'v' }, '<leader>gp', pick(actions.prompt_actions), { desc = 'AI Prompt Actions' })

