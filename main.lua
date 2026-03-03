--[[
    GD50 2018
    Pong Remake

    -- Main Program --

    Author: Colton Ogden
    cogden@cs50.harvard.edu

    Originally programmed by Atari in 1972. Features two
    paddles, controlled by players, with the goal of getting
    the ball past your opponent's edge. First to 10 points wins.

    This version is built to more closely resemble the NES than
    the original Pong machines or the Atari 2600 in terms of
    resolution, though in widescreen (16:9) so it looks nicer on
    modern systems.
]]

-- push is a library that will allow us to draw our game at a virtual
-- resolution, instead of however large our window is; used to provide
-- a more retro aesthetic
--
-- https://github.com/Ulydev/push
push = require 'push'

-- the "Class" library we're using will allow us to represent anything in
-- our game as code, rather than keeping track of many disparate variables and
-- methods
--
-- https://github.com/vrld/hump/blob/master/class.lua
Class = require 'class'

-- our Paddle class, which stores position and dimensions for each Paddle
-- and the logic for rendering them
require 'Paddle'

require 'Wall'
require 'Row'
require 'Brick'
require 'PowerUp'
-- our Ball class, which isn't much different than a Paddle structure-wise
-- but which will mechanically function very differently
require 'Ball'

-- GameState enum for better DX
GameState = require 'GameState'

-- size of our actual window
WINDOW_WIDTH = 750
WINDOW_HEIGHT = 1000

-- size we're trying to emulate with push
VIRTUAL_WIDTH = 225
VIRTUAL_HEIGHT = 300

-- paddle movement speed
PADDLE_SPEED = 200
PADDLE_WIDEN_AMOUNT = 14
MAX_HP = 3
POWERUP_DROP_CHANCE = 0.18

--[[
    Called just once at the beginning of the game; used to set up
    game objects, variables, etc. and prepare the game world.
]]
function love.load()
    -- set love's default filter to "nearest-neighbor", which essentially
    -- means there will be no filtering of pixels (blurriness), which is
    -- important for a nice crisp, 2D look
    love.graphics.setDefaultFilter('nearest', 'nearest')

    -- Stage configurations
    stageConfigs = {
        [1] = {
            rowCount = 5,         -- 5 rows of bricks
            bricksPerRow = 8,     -- 8 bricks per row
            baseHP = 1,           -- Base HP value
            hpScaling = 'uniform' -- All bricks have 1 HP
        },
        [2] = {
            rowCount = 6,            -- 6 rows of bricks
            bricksPerRow = 10,       -- 10 bricks per row
            baseHP = 1,              -- Base HP value
            hpScaling = 'descending' -- Top rows have more HP (1+6-row)
        },
        [3] = {
            rowCount = 7,        -- 7 rows of bricks
            bricksPerRow = 10,   -- 10 bricks per row
            baseHP = 2,          -- Higher base HP
            hpScaling = 'random' -- Random HP between 2-8 for unpredictability
        }
    }

    testWall = Wall(stageConfigs[1])
    -- set the title of our application window
    love.window.setTitle('Lovekanoid')

    -- seed the RNG so that calls to random are always random
    math.randomseed(os.time())

    -- initialize our nice-looking retro text fonts
    smallFont = love.graphics.newFont('font.ttf', 8)
    largeFont = love.graphics.newFont('font.ttf', 16)
    scoreFont = love.graphics.newFont('font.ttf', 32)
    love.graphics.setFont(smallFont)

    -- set up our sound effects; later, we can just index this table and
    -- call each entry's `play` method
    sounds = {
        ['paddle_hit'] = love.audio.newSource('sounds/paddle_hit.wav', 'static'),
        ['score'] = love.audio.newSource('sounds/score.wav', 'static'),
        ['wall_hit'] = love.audio.newSource('sounds/wall_hit.wav', 'static'),
        ['brick_hit'] = love.audio.newSource('sounds/wall_hit.wav', 'static') -- Using wall_hit as placeholder
    }

    -- initialize our virtual resolution, which will be rendered within our
    -- actual window no matter its dimensions
    push:setupScreen(VIRTUAL_WIDTH, VIRTUAL_HEIGHT, WINDOW_WIDTH, WINDOW_HEIGHT, {
        fullscreen = false,
        resizable = true,
        vsync = true,
        canvas = false
    })

    player1 = Paddle(VIRTUAL_WIDTH / 2 - 13, VIRTUAL_HEIGHT - 20, 26, 5)

    activeBalls = {}
    activePowerUps = {}
    resetBalls()

    HP = MAX_HP

    ballMaxSpeed = 250

    gameState = GameState.START

    currentStage = 0

    -- inactivity timer for demo mode
    inactivityTimer = 0
    DEMO_DELAY = 15 -- seconds before demo starts
end

function love.resize(w, h)
    push:resize(w, h)
end

function love.update(dt)
    -- track inactivity in start state
    if gameState == GameState.START then
        inactivityTimer = inactivityTimer + dt
        if inactivityTimer >= DEMO_DELAY then
            gameState = GameState.DEMO
            inactivityTimer = 0
            -- reset ball for demo
            resetBalls()
            local ball = getPrimaryBall()
            ball.dy = -200
            ball.dx = math.random(-100, 100)
        end
    end

    if gameState == GameState.DEMO then
        local ball = getPrimaryBall()

        -- AI: paddle follows ball
        local paddleCenter = player1.x + player1.width / 2
        local ballCenter = ball.x + ball.width / 2

        if ballCenter < paddleCenter - 2 then
            player1.dx = -PADDLE_SPEED
        elseif ballCenter > paddleCenter + 2 then
            player1.dx = PADDLE_SPEED
        else
            player1.dx = 0
        end
        player1:update(dt)

        -- ball physics (simplified from stage-1/stage-2)
        if ball:collides(player1) then
            local currentSpeed = math.sqrt(ball.dx ^ 2 + ball.dy ^ 2)
            local hitPoint = (ball.x - player1.x) / player1.width
            hitPoint = math.max(0, math.min(1, hitPoint))
            local angle = (hitPoint - 0.5) * 2 * (math.pi / 3)
            ball.dx = currentSpeed * math.sin(angle)
            ball.dy = -currentSpeed * math.cos(angle)
            ball.y = player1.y - ball.height - 1
            limitBallSpeed()
            sounds['paddle_hit']:play()
        end

        for _, row in ipairs(testWall.rows) do
            for _, brick in ipairs(row.bricks) do
                if brick.alive and ball:collides(brick) then
                    brick:hit()
                    ball.dy = -ball.dy
                    sounds['brick_hit']:play()
                    break
                end
            end
        end

        -- wall collisions
        if ball.y <= 0 then
            ball.y = 0
            ball.dy = -ball.dy
            sounds['wall_hit']:play()
        end

        -- demo ball never dies, just bounces back
        if ball.y >= VIRTUAL_HEIGHT - 4 then
            ball.dy = -ball.dy
            ball.y = VIRTUAL_HEIGHT - 8
            sounds['wall_hit']:play()
        end

        if ball.x < 0 then
            ball.dx = -ball.dx
            ball.x = 0
            sounds['wall_hit']:play()
        end

        if ball.x > VIRTUAL_WIDTH then
            ball.dx = -ball.dx
            ball.x = VIRTUAL_WIDTH - 4
            sounds['wall_hit']:play()
        end

        ball:update(dt)
    elseif gameState == GameState.SERVE then
        local ball = getPrimaryBall()
        ball.dy = -200
        ball.dx = math.random(-100, 100)
    elseif gameState == GameState.STAGE_1 or gameState == GameState.STAGE_2 or gameState == GameState.STAGE_3 then
        if love.keyboard.isDown('a') then
            player1.dx = -PADDLE_SPEED
        elseif love.keyboard.isDown('d') then
            player1.dx = PADDLE_SPEED
        else
            player1.dx = 0
        end
        player1:update(dt)

        for _, ball in ipairs(activeBalls) do
            if ball:collides(player1) then
                bounceBallOffPaddle(ball)
                sounds['paddle_hit']:play()
            end
        end

        for _, ball in ipairs(activeBalls) do
            local hitBrick = false

            for _, row in ipairs(testWall.rows) do
                for _, brick in ipairs(row.bricks) do
                    if brick.alive and ball:collides(brick) then
                        local destroyed = brick:hit()
                        ball.dy = -ball.dy
                        sounds['brick_hit']:play()

                        if destroyed then
                            maybeSpawnPowerUp(brick)
                        end

                        if isWallCleared() then
                            advanceStageState()
                        end

                        hitBrick = true
                        break
                    end
                end

                if hitBrick then
                    break
                end
            end
        end

        for i = #activeBalls, 1, -1 do
            local ball = activeBalls[i]

            if ball.y <= 0 then
                ball.y = 0
                ball.dy = -ball.dy
                sounds['wall_hit']:play()
            end

            if ball.y >= VIRTUAL_HEIGHT - ball.height then
                table.remove(activeBalls, i)
            elseif ball.x < 0 then
                ball.dx = -ball.dx
                ball.x = 0
                sounds['wall_hit']:play()
            elseif ball.x > VIRTUAL_WIDTH - ball.width then
                ball.dx = -ball.dx
                ball.x = VIRTUAL_WIDTH - ball.width
                sounds['wall_hit']:play()
            end
        end

        for i = #activePowerUps, 1, -1 do
            local powerUp = activePowerUps[i]
            powerUp:update(dt)

            if powerUp:collides(player1) then
                applyPowerUp(powerUp.kind)
                table.remove(activePowerUps, i)
            elseif powerUp.y > VIRTUAL_HEIGHT then
                table.remove(activePowerUps, i)
            end
        end

        if #activeBalls == 0 then
            HP = HP - 1
            activePowerUps = {}
            sounds['score']:play()

            if HP == 0 then
                gameState = GameState.OVER
            else
                gameState = GameState.SERVE
                resetBalls()
                player1:reset(false)
            end
        end
    end

    --
    -- paddles can move no matter what state we're in
    --
    -- player 1




    -- update our ball based on its DX and DY only if we're in stage-1 state;
    -- scale the velocity by dt so movement is framerate-independent
    if gameState == GameState.STAGE_1 or gameState == GameState.STAGE_2 or gameState == GameState.STAGE_3 then
        for _, ball in ipairs(activeBalls) do
            ball:update(dt)
        end
    end
end

--[[
    A callback that processes key strokes as they happen, just the once.
    Does not account for keys that are held down, which is handled by a
    separate function (`love.keyboard.isDown`). Useful for when we want
    things to happen right away, just once, like when we want to quit.
]]
function love.keypressed(key)
    -- reset inactivity timer on any key press during start state
    if gameState == 'start' then
        inactivityTimer = 0
    end

    -- `key` will be whatever key this callback detected as pressed
    if key == 'escape' then
        -- the function LÖVE2D uses to quit the application
        love.event.quit()
        -- if we press enter during either the start or serve phase, it should
        -- transition to the next appropriate state
    elseif key == 'enter' or key == 'return' then
        if gameState == GameState.START and currentStage == 0 then
            currentStage = currentStage + 1
        elseif gameState == 'start' and currentStage ~= 0 then
            gameState = 'serve'
        elseif gameState == GameState.DEMO then
            gameState = GameState.START
            resetBalls()
            activePowerUps = {}
            player1:reset(true)
            -- reset wall for demo
            testWall = Wall(stageConfigs[currentStage == 0 and 1 or currentStage])
        elseif gameState == GameState.SERVE then
            -- set max speed based on current stage
            if currentStage == 1 then
                ballMaxSpeed = 250
            elseif currentStage == 2 then
                ballMaxSpeed = 350
            elseif currentStage == 3 then
                ballMaxSpeed = 450
            end
            if currentStage == 1 then
                gameState = GameState.STAGE_1
            elseif currentStage == 2 then
                gameState = GameState.STAGE_2
            else
                gameState = GameState.STAGE_3
            end
        elseif gameState == GameState.STAGE_1_PASSED then
            HP = MAX_HP
            resetBalls()
            activePowerUps = {}
            player1:reset(true)
            testWall = Wall(stageConfigs[2])
            gameState = GameState.START
        elseif gameState == GameState.STAGE_2_PASSED then
            HP = MAX_HP
            resetBalls()
            activePowerUps = {}
            player1:reset(true)
            testWall = Wall(stageConfigs[3])
            gameState = GameState.START
        elseif gameState == GameState.DONE or gameState == GameState.OVER then
            -- game is simply in a restart phase here
            gameState = GameState.START

            resetBalls()
            activePowerUps = {}
            player1:reset(true)
            testWall = Wall(stageConfigs[1])

            HP = MAX_HP
            currentStage = 0
        end
    end
end

--[[
    Called each frame after update; is responsible simply for
    drawing all of our game objects and more to the screen.
]]
function love.draw()
    -- begin drawing with push, in our virtual resolution
    push:start()

    love.graphics.clear(40 / 255, 45 / 255, 52 / 255, 255 / 255)

    -- display debug info box in top-right corner
    -- displayDebugBox()

    testWall:render()
    -- render different things depending on which part of the game we're in
    if gameState == 'start' and currentStage == 0 then
        drawAlertBox('Welcome to Arkanoid!', 'Press ENTER to start the game.')
    elseif gameState == GameState.START and currentStage == 1 then
        -- UI messages
        drawAlertBox('STAGE 1', 'Press ENTER to begin!')
    elseif gameState == GameState.STAGE_1_PASSED then
        drawAlertBox('STAGE 1 CLEAR!', 'Press ENTER to load stage 2!')
    elseif gameState == GameState.STAGE_2_PASSED then
        drawAlertBox('STAGE 2 CLEAR!', 'Press ENTER to load stage 3!')
    elseif gameState == GameState.START and currentStage == 2 then
        drawAlertBox('LEVEL 2', 'Press ENTER to begin!')
    elseif gameState == GameState.SERVE then
        love.graphics.setFont(smallFont)
        drawAlertBox('Throw the ball!', 'Press ENTER to launch!')
    elseif gameState == GameState.DEMO then
        drawDemoBox()
    elseif gameState == GameState.OVER then
        drawAlertBox('You lose =(', 'Press ENTER to reset.')
        -- love.graphics.setFont(largeFont)
        -- love.graphics.printf('You lose =(',
        --     0, VIRTUAL_HEIGHT / 2 - 80, VIRTUAL_WIDTH, 'center')
    elseif gameState == GameState.DONE then
        -- UI messages
        drawAlertBox('You WIN! =)', 'Press ENTER to reset.')
    end

    -- show the score before ball is rendered so it can move over the text
    displayHP()

    player1:render()
    for _, powerUp in ipairs(activePowerUps) do
        powerUp:render()
    end

    for _, ball in ipairs(activeBalls) do
        ball:render()
    end

    -- display FPS for debugging; simply comment out to remove
    -- displayFPS()

    -- end our drawing to push
    push:finish()
end

--[[
    Limits the ball's speed to ballMaxSpeed.
]]
function limitBallSpeed()
    local ball = getPrimaryBall()
    local speed = math.sqrt(ball.dx ^ 2 + ball.dy ^ 2)
    if speed > ballMaxSpeed then
        ball.dx = (ball.dx / speed) * ballMaxSpeed
        ball.dy = (ball.dy / speed) * ballMaxSpeed
    end
end

--[[
    Simple function for rendering the scores.
]]
function displayHP()
    -- draw fancy box around HP display (inner area: x=10 to x=50, y=15 to y=27)
    drawFancyBox(5, 10, 55, 32)

    -- HP text and hearts - centered vertically, equal horizontal margins
    love.graphics.setColor(1, 0.3, 0.3, 1)
    love.graphics.setFont(smallFont)
    love.graphics.print('HP', 14, 17)

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print(string.rep('x', HP), 31, 17)
end

--[[
    Renders the current FPS.
]]
function displayFPS()
    -- simple FPS display across all states
    love.graphics.setFont(smallFont)
    love.graphics.setColor(0, 255 / 255, 0, 255 / 255)
    love.graphics.print('FPS: ' .. tostring(love.timer.getFPS()), 10, 10)
    love.graphics.setColor(255, 255, 255, 255)
end

--[[
    Renders a fancy debug box in the top-right corner with useful info.
]]
function displayDebugBox()
    local boxWidth = 80
    local boxHeight = 50
    local x1 = VIRTUAL_WIDTH - boxWidth - 5
    local y1 = 5
    local x2 = VIRTUAL_WIDTH - 5
    local y2 = boxHeight

    -- save current color
    local old_r, old_g, old_b, old_a = love.graphics.getColor()

    -- draw filled semi-transparent black background
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle('fill', x1, y1, boxWidth, boxHeight)

    -- draw white border with fancy offset
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle('line', x1 + 3, y1 + 3, boxWidth - 6, boxHeight - 6)

    -- draw debug text
    love.graphics.setFont(smallFont)
    love.graphics.setColor(0, 255 / 255, 0, 255 / 255)
    love.graphics.print('FPS: ' .. tostring(love.timer.getFPS()), x1 + 8, y1 + 8)
    love.graphics.setColor(255 / 255, 255 / 255, 0, 255 / 255)
    love.graphics.print('State: ' .. gameState, x1 + 8, y1 + 20)
    love.graphics.setColor(0 / 255, 200 / 255, 255 / 255, 255 / 255)
    local ball = getPrimaryBall()
    love.graphics.print('Ball: ' .. string.format('%.0f,%.0f', ball.x, ball.y), x1 + 8, y1 + 32)

    -- restore color
    love.graphics.setColor(old_r, old_g, old_b, old_a)
end

--[[
    Draws an alert box with a title and subtitle centered on screen.
]]
function drawAlertBox(title, subtitle)
    -- draw fancy alert box
    drawFancyBox(10, VIRTUAL_HEIGHT / 2 - 90, VIRTUAL_WIDTH - 10, VIRTUAL_HEIGHT / 2 + 30)

    -- draw title and subtitle text
    love.graphics.setFont(largeFont)
    love.graphics.printf(title, 0, VIRTUAL_HEIGHT / 2 - 60, VIRTUAL_WIDTH, 'center')
    love.graphics.setFont(smallFont)
    love.graphics.printf(subtitle, 0, VIRTUAL_HEIGHT / 2, VIRTUAL_WIDTH, 'center')
end

function drawDemoBox()
    drawFancyBox(84, VIRTUAL_HEIGHT / 2 - 68, VIRTUAL_WIDTH - 88, VIRTUAL_HEIGHT / 2 - 38)

    love.graphics.setFont(largeFont)
    love.graphics.printf("DEMO", 0, VIRTUAL_HEIGHT / 2 - 60, VIRTUAL_WIDTH, 'center')
end

--[[
    Draws a fancy box with black fill and white border at specified coordinates.
    x1, y1: top-left corner
    x2, y2: bottom-right corner
]]
function drawFancyBox(x1, y1, x2, y2)
    -- save current color
    old_r, old_g, old_b, old_a = love.graphics.getColor()

    -- calculate dimensions
    local width = x2 - x1
    local height = y2 - y1

    -- draw filled black background
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.rectangle('fill', x1, y1, width, height)

    -- draw white border (offset by 5 pixels)
    love.graphics.setColor(old_r, old_g, old_b, old_a)
    love.graphics.rectangle('line', x1 + 2, y1 + 2, width - 4, height - 4)
end

function createBall(x, y, dx, dy)
    local ball = Ball(x or VIRTUAL_WIDTH / 2 - 2, y or VIRTUAL_HEIGHT - 26, 4, 4)
    ball.dx = dx or 0
    ball.dy = dy or 0
    return ball
end

function resetBalls()
    activeBalls = {createBall()}
end

function getPrimaryBall()
    if #activeBalls == 0 then
        resetBalls()
    end

    return activeBalls[1]
end

function bounceBallOffPaddle(ball)
    local currentSpeed = math.sqrt(ball.dx ^ 2 + ball.dy ^ 2)
    if currentSpeed == 0 then
        currentSpeed = 200
    end

    local hitPoint = (ball.x - player1.x) / player1.width
    hitPoint = math.max(0, math.min(1, hitPoint))

    local angle = (hitPoint - 0.5) * 2 * (math.pi / 3)
    ball.dx = currentSpeed * math.sin(angle)
    ball.dy = -currentSpeed * math.cos(angle)
    ball.y = player1.y - ball.height - 1

    local speed = math.sqrt(ball.dx ^ 2 + ball.dy ^ 2)
    if speed > ballMaxSpeed then
        ball.dx = (ball.dx / speed) * ballMaxSpeed
        ball.dy = (ball.dy / speed) * ballMaxSpeed
    end
end

function maybeSpawnPowerUp(brick)
    if math.random() > POWERUP_DROP_CHANCE then
        return
    end

    local roll = math.random(3)
    local kind = 'widen'

    if roll == 2 then
        kind = 'fork'
    elseif roll == 3 then
        kind = 'hp'
    end

    table.insert(activePowerUps, PowerUp(
        brick.x + brick.width / 2 - 6,
        brick.y + brick.height / 2 - 6,
        kind
    ))
end

function applyPowerUp(kind)
    if kind == 'widen' then
        player1:setWidth(math.min(player1.width + PADDLE_WIDEN_AMOUNT, player1.baseWidth + PADDLE_WIDEN_AMOUNT * 2))
    elseif kind == 'fork' then
        local sourceBall = activeBalls[1]

        if sourceBall == nil then
            sourceBall = createBall(player1.x + player1.width / 2 - 2, player1.y - 12, 80, -200)
            table.insert(activeBalls, sourceBall)
        end

        local forkDX = sourceBall.dx
        if math.abs(forkDX) < 30 then
            forkDX = 80
        end

        local forkBall = createBall(sourceBall.x, sourceBall.y, -forkDX, sourceBall.dy)
        table.insert(activeBalls, forkBall)
    elseif kind == 'hp' then
        HP = math.min(MAX_HP, HP + 1)
    end
end

function isWallCleared()
    for _, row in ipairs(testWall.rows) do
        for _, brick in ipairs(row.bricks) do
            if brick.alive then
                return false
            end
        end
    end

    return true
end

function advanceStageState()
    activePowerUps = {}

    if gameState == GameState.STAGE_1 then
        currentStage = currentStage + 1
        gameState = GameState.STAGE_1_PASSED
    elseif gameState == GameState.STAGE_2 then
        currentStage = currentStage + 1
        gameState = GameState.STAGE_2_PASSED
    elseif gameState == GameState.STAGE_3 then
        gameState = GameState.DONE
    end
end
