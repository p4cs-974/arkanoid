Wall = Class {}

function Wall:init(minY, maxY)
    self.rowCount = 6
    self.colors = {
        { 254 / 255, 52 / 255,  43,        255, 1 }, --red
        { 255 / 255, 54 / 255,  201 / 255, 1 },      -- pink
        { 255 / 255, 121 / 255, 12 / 255,  1 },      -- orange
        { 58 / 255,  49 / 255,  255 / 255, 1 },      -- dark blue
        { 43 / 255,  249 / 255, 254 / 255, 1 },      -- cyan
        { 49 / 255,  255 / 255, 8 / 255,   1 },
    }                                                -- green
    self.rows = {}

    for rowIndex = 1, self.rowCount do
        local row = Row(rowIndex, self.colors[rowIndex])
        table.insert(self.rows, row)
    end
end

function Wall:render()
    for _, row in ipairs(self.rows) do
        row:render()
    end
end

function Wall:reset()
    self.rows = {}
    for rowIndex = 1, self.rowCount do
        local row = Row(rowIndex, self.colors[rowIndex])
        table.insert(self.rows, row)
    end
end
