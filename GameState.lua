--[[
    GameState Enum

    Provides named constants for all game states to improve DX
    and avoid typos in state string literals.

    Usage:
        -- Instead of: gameState = 'start'
        -- Use:        gameState = GameState.START
]]

GameState = {
    START = 'start',
    DEMO = 'demo',
    SERVE = 'serve',
    STAGE_1 = 'stage-1',
    STAGE_1_PASSED = 'stage-1-passed',
    STAGE_2 = 'stage-2',
    DONE = 'done',
    OVER = 'over'
}

-- Make the table read-only to prevent accidental modifications
local readonly_mt = {
    __index = function(_, key)
        error("Attempt to access undefined GameState: " .. tostring(key), 2)
    end,
    __newindex = function()
        error("Cannot modify GameState enum", 2)
    end
}

return setmetatable(GameState, readonly_mt)
