Brick = Class {}

function Brick:init(x, y, width, height, color, hp)
    self.x = x
    self.y = y
    self.width = width
    self.height = height
    self.color = color
    self.alive = true
    self.hp = hp
    self.initialHP = hp
end

function Brick:setHP(hp)
    self.hp = hp
    self.initialHP = hp
end

function Brick:hit()
    self.hp = self.hp - 1
    if self.hp <= 0 then
        self.alive = false
    end
end

function Brick:render()
    if not self.alive then
        return
    end

    -- Calculate alpha based on current HP: decreases from 1.0 to 0.3 in initialHP steps
    local alpha = 0.3 + 0.7 * (self.hp / self.initialHP)

    old_r, old_g, old_b, old_a = love.graphics.getColor()
    love.graphics.setColor(self.color[1], self.color[2], self.color[3], alpha)
    love.graphics.rectangle('fill', self.x, self.y, self.width, self.height)
    love.graphics.setColor(old_r, old_g, old_b, old_a)
end
