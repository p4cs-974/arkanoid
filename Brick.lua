Brick = Class {}

function Brick:init(x, y, width, height, color)
    self.x = x
    self.y = y
    self.width = width
    self.height = height
    self.color = color
    self.alive = true
end

function Brick:render()
    old_r, old_g, old_b, old_a = love.graphics.getColor()
    love.graphics.setColor(self.color[1], self.color[2], self.color[3], self.color[4])
    love.graphics.rectangle('fill', self.x, self.y, self.width, self.height)
    love.graphics.setColor(old_r, old_g, old_b, old_a)
end
