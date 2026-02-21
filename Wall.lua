Wall = Class {}

function Wall:init(config)
    -- Default configuration
    config = config or {}
    self.rowCount = config.rowCount or 6
    self.bricksPerRow = config.bricksPerRow or 10
    self.baseHP = config.baseHP or 1
    self.hpScaling = config.hpScaling or 'descending' -- 'descending', 'ascending', 'uniform', or 'random'
    self.colors = config.colors or {
        { 254 / 255, 52 / 255,  43 / 255,  1 },       -- red
        { 255 / 255, 54 / 255,  201 / 255, 1 },       -- pink
        { 255 / 255, 121 / 255, 12 / 255,  1 },       -- orange
        { 58 / 255,  49 / 255,  255 / 255, 1 },       -- dark blue
        { 43 / 255,  249 / 255, 254 / 255, 1 },       -- cyan
        { 49 / 255,  255 / 255, 8 / 255,   1 },       -- green
    }
    self.rows = {}

    self:buildRows()
end

function Wall:getHPForRow(rowIndex)
    if self.hpScaling == 'descending' then
        -- Top rows have higher HP (like original: 7 - rowIndex)
        return math.max(1, self.baseHP + self.rowCount - rowIndex)
    elseif self.hpScaling == 'ascending' then
        -- Bottom rows have higher HP
        return math.max(1, self.baseHP + rowIndex - 1)
    elseif self.hpScaling == 'uniform' then
        -- All rows have the same HP
        return self.baseHP
    elseif self.hpScaling == 'random' then
        -- Random HP between baseHP and baseHP + rowCount
        return math.random(self.baseHP, self.baseHP + self.rowCount - 1)
    end
    return self.baseHP
end

function Wall:buildRows()
    self.rows = {}
    for rowIndex = 1, self.rowCount do
        local hp = self:getHPForRow(rowIndex)
        local color = self.colors[(rowIndex - 1) % #self.colors + 1]
        local row = Row(rowIndex, color, self.bricksPerRow, hp)
        table.insert(self.rows, row)
    end
end

function Wall:render()
    for _, row in ipairs(self.rows) do
        row:render()
    end
end

function Wall:reset()
    self:buildRows()
end
