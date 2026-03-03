PowerUp = Class {}

function PowerUp:init(x, y, kind)
    self.x = x
    self.y = y
    self.kind = kind
    self.radius = 6
    self.width = self.radius * 2
    self.height = self.radius * 2
    self.dy = 55
end

function PowerUp:update(dt)
    self.y = self.y + self.dy * dt
end

function PowerUp:collides(target)
    if self.x > target.x + target.width or target.x > self.x + self.width then
        return false
    end

    if self.y > target.y + target.height or target.y > self.y + self.height then
        return false
    end

    return true
end

function PowerUp:getColor()
    if self.kind == 'widen' then
        return 0.2, 0.7, 1
    elseif self.kind == 'fork' then
        return 0.3, 1, 0.4
    end

    return 1, 0.4, 0.8
end

function PowerUp:getLabel()
    if self.kind == 'widen' then
        return '='
    elseif self.kind == 'fork' then
        return '2'
    end

    return '1'
end

function PowerUp:render()
    local oldR, oldG, oldB, oldA = love.graphics.getColor()
    local r, g, b = self:getColor()

    love.graphics.setColor(r, g, b, 1)
    love.graphics.circle('fill', self.x + self.radius, self.y + self.radius, self.radius)

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(smallFont)
    love.graphics.printf(self:getLabel(), self.x, self.y + 2, self.width, 'center')
    love.graphics.setColor(oldR, oldG, oldB, oldA)
end
