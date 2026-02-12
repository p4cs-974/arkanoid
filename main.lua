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

-- our Ball class, which isn't much different than a Paddle structure-wise
-- but which will mechanically function very differently
require 'Ball'

-- size of our actual window
WINDOW_WIDTH = 750
WINDOW_HEIGHT = 1000

-- size we're trying to emulate with push
VIRTUAL_WIDTH = 225
VIRTUAL_HEIGHT = 300

-- paddle movement speed
PADDLE_SPEED = 200

--[[
    Called just once at the beginning of the game; used to set up
    game objects, variables, etc. and prepare the game world.
]]
function love.load()
    -- set love's default filter to "nearest-neighbor", which essentially
    -- means there will be no filtering of pixels (blurriness), which is
    -- important for a nice crisp, 2D look
    love.graphics.setDefaultFilter('nearest', 'nearest')

    -- set the title of our application window
    love.window.setTitle('Pong')

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
        ['wall_hit'] = love.audio.newSource('sounds/wall_hit.wav', 'static')
    }

    -- initialize our virtual resolution, which will be rendered within our
    -- actual window no matter its dimensions
    push:setupScreen(VIRTUAL_WIDTH, VIRTUAL_HEIGHT, WINDOW_WIDTH, WINDOW_HEIGHT, {
        fullscreen = false,
        resizable = true,
        vsync = true,
        canvas = false
    })

    -- initialize our player paddles; make them global so that they can be
    -- detected by other functions and modules
    player1 = Paddle(VIRTUAL_WIDTH / 2 - 13, VIRTUAL_HEIGHT - 20, 26, 5)

    -- place a ball in the middle of the screen
    ball = Ball(VIRTUAL_WIDTH / 2 - 2, VIRTUAL_HEIGHT - 26, 4, 4)

    -- initialize score variable
    HP = 3

    -- the state of our game; can be any of the following:
    -- 1. 'start' (the beginning of the game, before first serve)
    -- 2. 'serve' (waiting on a key press to serve the ball)
    -- 3. 'play' (the ball is in play, bouncing between paddles)
    -- 4. 'done' (the game is over, with a victor, ready for restart)
    gameState = 'start'
end

--[[
    Called whenever we change the dimensions of our window, as by dragging
    out its bottom corner, for example. In this case, we only need to worry
    about calling out to `push` to handle the resizing. Takes in a `w` and
    `h` variable representing width and height, respectively.
]]
function love.resize(w, h)
    push:resize(w, h)
end

--[[
    Called every frame, passing in `dt` since the last frame. `dt`
    is short for `deltaTime` and is measured in seconds. Multiplying
    this by any changes we wish to make in our game will allow our
    game to perform consistently across all hardware; otherwise, any
    changes we make will be applied as fast as possible and will vary
    across system hardware.
]]
function love.update(dt)
    if gameState == 'serve' then
        -- before switching to play, initialize ball's velocity
        ball.dy = -100
        ball.dx = math.random(-100, 100)
    elseif gameState == 'play' then
        if love.keyboard.isDown('a') then
            player1.dx = -PADDLE_SPEED
        elseif love.keyboard.isDown('d') then
            player1.dx = PADDLE_SPEED
        else
            player1.dx = 0
        end
        player1:update(dt)
        -- detect ball collision with paddles, reversing dx if true and
        -- slightly increasing it, then altering the dy based on the position
        -- at which it collided, then playing a sound effect
        if ball:collides(player1) then
            -- Calculate current speed before modifying
            local currentSpeed = math.sqrt(ball.dx ^ 2 + ball.dy ^ 2)

            ball.dy = -ball.dy
            ball.y = player1.y - 5

            ball.dx = ((ball.x - player1.x)) * 20

            -- Normalize to maintain constant speed
            local newSpeed = math.sqrt(ball.dx ^ 2 + ball.dy ^ 2)
            ball.dx = (ball.dx / newSpeed) * currentSpeed
            ball.dy = (ball.dy / newSpeed) * currentSpeed

            sounds['paddle_hit']:play()
        end


        -- detect upper and lower screen boundary collision, playing a sound
        -- effect and reversing dy if true
        if ball.y <= 0 then
            ball.y = 0
            ball.dy = -ball.dy
            sounds['wall_hit']:play()
        end

        -- -4 to account for the ball's size
        if ball.y >= VIRTUAL_HEIGHT - 4 then
            HP = HP - 1
            sounds['score']:play()

            if HP == 0 then
                gameState = 'over'
            else
                gameState = 'serve'
                ball:reset()
                player1:reset()
            end
        end

        -- if we reach the left edge of the screen, reset the ball
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
    end

    --
    -- paddles can move no matter what state we're in
    --
    -- player 1




    -- update our ball based on its DX and DY only if we're in play state;
    -- scale the velocity by dt so movement is framerate-independent
    if gameState == 'play' then
        ball:update(dt)
    end
end

--[[
    A callback that processes key strokes as they happen, just the once.
    Does not account for keys that are held down, which is handled by a
    separate function (`love.keyboard.isDown`). Useful for when we want
    things to happen right away, just once, like when we want to quit.
]]
function love.keypressed(key)
    -- `key` will be whatever key this callback detected as pressed
    if key == 'escape' then
        -- the function LÖVE2D uses to quit the application
        love.event.quit()
        -- if we press enter during either the start or serve phase, it should
        -- transition to the next appropriate state
    elseif key == 'enter' or key == 'return' then
        if gameState == 'start' then
            gameState = 'serve'
        elseif gameState == 'serve' then
            gameState = 'play'
        elseif gameState == 'done' or gameState == 'over' then
            -- game is simply in a restart phase here
            gameState = 'start'

            ball:reset()
            player1:reset()

            -- reset score to 0
            HP = 3
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

    -- render different things depending on which part of the game we're in
    if gameState == 'start' then
        -- UI messages
        love.graphics.setFont(smallFont)
        love.graphics.printf('Welcome to Arkanoid!', 0, VIRTUAL_HEIGHT / 2 - 80, VIRTUAL_WIDTH, 'center')
        love.graphics.setFont(smallFont)
        love.graphics.printf('Press ENTER to begin!', 0, VIRTUAL_HEIGHT / 2 + 20, VIRTUAL_WIDTH, 'center')
    elseif gameState == 'serve' then
        love.graphics.setFont(smallFont)
        love.graphics.printf('Press ENTER to launch the ball.',
            0, VIRTUAL_HEIGHT / 2 - 80, VIRTUAL_WIDTH, 'center')
    elseif gameState == 'play' then
        -- no UI messages to display in play
    elseif gameState == 'over' then
        love.graphics.setFont(largeFont)
        love.graphics.printf('You lose =(',
            0, VIRTUAL_HEIGHT / 2 - 80, VIRTUAL_WIDTH, 'center')
    elseif gameState == 'done' then
        -- UI messages
        love.graphics.setFont(largeFont)
        love.graphics.printf('You win =)',
            0, VIRTUAL_HEIGHT / 2 - 80, VIRTUAL_WIDTH, 'center')
        love.graphics.setFont(smallFont)
        love.graphics.printf('Press Enter to restart!', 0, VIRTUAL_HEIGHT / 2 + 20, VIRTUAL_WIDTH, 'center')
    end

    -- show the score before ball is rendered so it can move over the text
    displayHP()

    player1:render()
    ball:render()

    -- display FPS for debugging; simply comment out to remove
    -- displayFPS()

    -- end our drawing to push
    push:finish()
end

--[[
    Simple function for rendering the scores.
]]
function displayHP()
    -- score display
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.rectangle('fill', 25, 15, 22, 10)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(smallFont)
    love.graphics.printf(string.rep('x', HP), 30, 16, 65, "left")
    love.graphics.setFont(smallFont)
    love.graphics.printf('HP', 10, 16, 13, "right")
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
