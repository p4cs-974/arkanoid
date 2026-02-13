Row = Class {}

function Row:init(rowIndex, color)
    self.index = rowIndex
    self.color = color
    self.bricks = {}

    local BRICKS_PER_ROW = 10
    local brickWidth = VIRTUAL_WIDTH / BRICKS_PER_ROW - 2
    local brickHeight = 10
    local startX = 2
    local startY = 40 + (rowIndex - 1) * (brickHeight + 4)

    for i = 1, BRICKS_PER_ROW do
        local brickX = startX + (i - 1) * (brickWidth + 2)
        local brickY = startY
        local brick = Brick(brickX, brickY, brickWidth, brickHeight, color)
        table.insert(self.bricks, brick)
    end
end

function Row:render()
    for _, brick in ipairs(self.bricks) do
        if brick.alive then
            brick:render()
        end
    end
end
