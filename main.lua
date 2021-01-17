local map
local flag
local fonts
local numbers
local bombColours
local placedFlags, targetFlags
local currentScreen
local bombCountPercentage = 0.02
local mouse1Debounce = false
local bombMarkDebounce = false
local camPos = {0, 0}

local function drawNumber(num, x, y)
    love.graphics.draw(
        numbers.img,
        numbers[num],
        x, y
    )
end

local function drawSquare(x, y)
    local square = map[x][y]
    local xPos = x*50 - camPos[1]
    local yPos = y*50 - camPos[2]

    local colorMul = ((x+y)%2==0) and 1.2 or 1.1

    if square.explored then
        love.graphics.setColor(0.6*colorMul, 0.6*colorMul, 0.4*colorMul, 1)
    else
        love.graphics.setColor(0.2*colorMul, 0.6*colorMul, 0.2*colorMul, 1)
    end
    love.graphics.rectangle("fill", xPos, yPos, 50, 50)

    local canShowBombCount = false
    if square.explored then
        love.graphics.setColor(0.3, 0.5, 0.3, 1)
        local xmvalid = x-1 >= 0
        local xpvalid = x+1 <= #map
        local ymvalid = y-1 >= 0
        local ypvalid = y+1 <= #map[x]

        canShowBombCount = xmvalid or xpvalid or ymvalid or ypvalid

        if xmvalid and not map[x-1][y].explored then
            love.graphics.rectangle("fill", xPos, yPos, 5, 50)
        end
        if xpvalid and not map[x+1][y].explored then
            love.graphics.rectangle("fill", xPos+45, yPos, 5, 50)
        end
        if ymvalid and not map[x][y-1].explored then
            love.graphics.rectangle("fill", xPos, yPos, 50, 5)
        end
        if ypvalid and not map[x][y+1].explored then
            love.graphics.rectangle("fill", xPos, yPos+45, 50, 5)
        end

        if xmvalid and ymvalid and not map[x-1][y-1].explored then
            love.graphics.rectangle("fill", xPos, yPos, 5, 5)
        end
        if xmvalid and ypvalid and not map[x-1][y+1].explored then
            love.graphics.rectangle("fill", xPos, yPos+45, 5, 5)
        end
        if xpvalid and ymvalid and not map[x+1][y-1].explored then
            love.graphics.rectangle("fill", xPos+45, yPos, 5, 5)
        end
        if xpvalid and ypvalid and not map[x+1][y+1].explored then
            love.graphics.rectangle("fill", xPos+45, yPos+45, 5, 5)
        end
    end

    if square.bombMarked then
        love.graphics.setColor(1, 0, 0, 1)
        love.graphics.draw(flag, xPos, yPos)

    elseif canShowBombCount and square.neighbourBombCount > 0 then
        local numColour = bombColours[square.neighbourBombCount]
        love.graphics.setColor(numColour[1], numColour[2], numColour[3], numColour[4])
        drawNumber(
            square.neighbourBombCount,
            xPos, yPos
        )
    end
end


local function explore(x, y)
    if (map[x][y].neighbourBombCount == 0) and (not map[x][y].explored) and (not map[x][y].bombMarked) then
        map[x][y].explored = true

        for x2 = math.max(x-1, 0), math.min(x+1, #map) do
            for y2 = math.max(y-1, 0), math.min(y+1, #map[x2]) do
                explore(x2, y2)
            end
        end

    end

    if not map[x][y].bombMarked then
        map[x][y].explored = true
        
        if map[x][y].bomb then
            currentScreen = "lose"
        end
    end
end

local function generateMap(sizeX, sizeY, bombCount, exploreFirstCell)
    camPos = {0, 0}
    map = {}
    -- Initial setup
    for x = 0, sizeX-1 do
        map[x] = {}

        for y = 0, sizeY-1 do
            map[x][y] = {
                bomb = false,
                explored = false,
                bombMarked = false,
                neighbourBombCount = 0
            }
        end
    end

    -- Second pass to add bombs
    local placedBombCount = 0
    local targetBombCount = bombCount
    placedFlags = 0
    targetFlags = math.ceil(targetBombCount)

    repeat
        local x = love.math.random(0, #map)
        local y = love.math.random(0, #map[x])

        if not map[x][y].bomb then
            map[x][y].bomb = true
            placedBombCount = placedBombCount + 1
        end
    until placedBombCount >= targetBombCount

    -- Third pass for neighbourBombCount
    for x = 0, sizeX-1 do
        for y = 0, sizeY-1 do
            local count = 0
            
            for x2 = math.max(x-1, 0), math.min(x+1, sizeX-1) do
                for y2 = math.max(y-1, 0), math.min(y+1, sizeY-1) do
                    if map[x2][y2].bomb then
                        count = count + 1
                    end
                end
            end

            map[x][y].neighbourBombCount = math.min(count, 8) -- If 9 bombs are next to eachother, it might count up to 9.
        end
    end

    if exploreFirstCell then
        -- Start with unexplored region
        local explored = false
        repeat
            local x = love.math.random(0, #map)
            local y = love.math.random(0, #map[x])

            if map[x][y].neighbourBombCount == 0 then
                explore(x, y)
                explored = true
            end
        until explored
    end
end

local function hasWon()
    local nonExplored = 0
    for x = 0, #map do
        for y = 0, #map[x] do
            if not map[x][y].explored then
                nonExplored = nonExplored + 1
            end
        end
    end

    return nonExplored == targetFlags
end

local function deepPrint(t, d)
    d = d or 0
    local s = string.rep(" ", d)
    for i, v in pairs(t) do
        if type(v) == "table" then
            deepPrint(v, d+1)
        else
            print(s .. "[" ..  tostring(i) .. "]: " .. tostring(v))
        end
    end
end

local function save()
    -- X Y neighbourBombCount bomb explored bombMarked
    -- bomb = false,
    -- explored = false,
    -- bombMarked = false,
    -- neighbourBombCount = 0

    local curData = string.char(#map[1])
    for x = 0, #map do
        for y = 0, #map[x] do
            local sqr = map[x][y]
            local num1 =
                (sqr.neighbourBombCount * 2^3) +
                (sqr.bomb and 2^2 or 0) +
                (sqr.explored and 2^1 or 0) +
                (sqr.bombMarked and 2^0 or 0)

            local char1 = string.char(num1)

            curData = curData .. char1
        end
    end

    love.filesystem.write("save", curData)
end

local function load()
    local data = love.filesystem.read("save")
    local len = string.len(data)
    map = {}
    local x, y = 0, 0
    local sizeY = string.byte(data, 1)
    for i = 2, len do
        local num1 = string.byte(data, i)

        local bombMarked = num1%2
        num1 = (num1 - bombMarked)/2
        local explored = num1%2
        num1 = (num1 - explored)/2
        local bomb = num1%2
        num1 = (num1 - bomb)/2
        local neighbourBombCount = num1


        map[x] = map[x] or {}
        map[x][y] = {
            bombMarked =         bombMarked == 1,
            explored =           explored == 1,
            bomb =               bomb == 1,
            neighbourBombCount = neighbourBombCount
        }

        y = y + 1
        if y > sizeY then
            y = 0
            x = x + 1
        end
    end
end




function love.load()
    currentScreen = "main menu"
    numbers = {
        img = love.graphics.newImage("numbers.png")
    }
    for i = 1, 8 do
        numbers[i] = love.graphics.newQuad((i-1)*50, 0, 50, 50, numbers.img:getDimensions())
    end

    bombColours = {
        [1] = {0, 0, 1, 1},
        [2] = {0, 0, 1, 1},
        [3] = {1, 1, 0, 1},
        [4] = {1, 1, 0, 1},
        [5] = {1, 0, 0, 1},
        [6] = {1, 0, 0, 1},
        [7] = {0.5, 0, 0.5, 1},
        [8] = {0.5, 0, 0.5, 1}
    }
    flag = love.graphics.newImage("flag.png")

    fonts = {}
    setmetatable(
        fonts, {
            __index = function(self, key)
                fonts[key] = love.graphics.newFont(key)
                return fonts[key]
            end
        }
    )

    generateMap(16, 12, 0, false)
end



function love.update(dt)
    local mouseX, mouseY = love.mouse.getX(), love.mouse.getY()
    local scrnWidth = love.graphics.getWidth()
    local scrnHeight = love.graphics.getHeight()

    if currentScreen == "game" then
        local gridX, gridY = math.floor((mouseX + camPos[1])/50), math.floor((mouseY + camPos[2])/50)

        if love.keyboard.isDown("a") then
            camPos[1] = camPos[1] - 50*dt * 5
        end
        if love.keyboard.isDown("d") then
            camPos[1] = camPos[1] + 50*dt * 5
        end
        if love.keyboard.isDown("w") then
            camPos[2] = camPos[2] - 50*dt * 5
        end
        if love.keyboard.isDown("s") and not love.keyboard.isDown("lctrl") then
            camPos[2] = camPos[2] + 50*dt * 5
        end
        camPos[1] = math.max(camPos[1], 0)
        camPos[2] = math.max(camPos[2], 0)

        camPos[1] = math.min(camPos[1], #map*50 - scrnWidth +50)
        camPos[2] = math.min(camPos[2], #map[1]*50 - scrnHeight +50)

        if love.mouse.isDown(1) then
            if not mouse1Debounce then
                mouse1Debounce = true
                explore(gridX, gridY)
            end
        else
            mouse1Debounce = false
        end
        if love.mouse.isDown(2) then
            if not bombMarkDebounce then
                bombMarkDebounce = true

                if not map[gridX][gridY].explored then
                    map[gridX][gridY].bombMarked = not map[gridX][gridY].bombMarked

                    if map[gridX][gridY].bombMarked then
                        placedFlags = placedFlags + 1
                    else
                        placedFlags = placedFlags - 1
                    end
                end
            end
        else
            bombMarkDebounce = false
        end

        if hasWon() then
            currentScreen = "win"
        end
    elseif currentScreen == "lose" then
        if love.mouse.isDown(1) then
            if not mouse1Debounce then
                mouse1Debounce = true

                if (mouseX > (scrnWidth *0.5 -100)) and (mouseX < (scrnWidth *0.5 +100)) then
                    if (mouseY > scrnHeight*0.5 -150 +255) and (mouseY < scrnHeight*0.5 -150 +270) then
                        generateMap(16, 12, 0, false)
                        currentScreen = "newGame"

                    elseif (mouseY > scrnHeight*0.5 -150 +275) and (mouseY < scrnHeight*0.5 -150 +290) then
                        currentScreen = "main menu"
                    end
                end
            end
        else
            mouse1Debounce = false
        end
    elseif currentScreen == "win" then
        if love.mouse.isDown(1) then
            if not mouse1Debounce then
                mouse1Debounce = true

                if (mouseX > (scrnWidth *0.5 -100)) and (mouseX < (scrnWidth *0.5 +100)) then
                    if (mouseY > scrnHeight*0.5 -150 +255) and (mouseY < scrnHeight*0.5 -150 +270) then
                        generateMap(16, 12, 0, false)
                        currentScreen = "newGame"

                    elseif (mouseY > scrnHeight*0.5 -150 +275) and (mouseY < scrnHeight*0.5 -150 +290) then
                        currentScreen = "main menu"
                    end
                end
            end
        else
            mouse1Debounce = false
        end
    elseif currentScreen == "main menu" then
        if love.mouse.isDown(1) then
            if not mouse1Debounce then
                mouse1Debounce = true

                if (mouseX > (scrnWidth *0.5 -100)) and (mouseX < (scrnWidth *0.5 +100)) then
                    if (mouseY > 150) and (mouseY < 175) then
                        -- generateMap(16, 12, (16*12) * 0.05, true)
                        currentScreen = "newGame"

                    elseif (mouseY > 180) and (mouseY < 205) then

                    elseif (mouseY > scrnHeight-180) and (mouseY < scrnHeight-150) then
                        love.event.quit()
                    end
                end
            end
        else
            mouse1Debounce = false
        end
    
    elseif currentScreen == "newGame" then
        if love.mouse.isDown(1) then
            if (mouseX > (scrnWidth *0.5 -100)) and (mouseX < (scrnWidth *0.5 +100)) then
                if (mouseY > scrnHeight*0.5 -150 +80) and (mouseY < scrnHeight*0.5 -150 +90) then
                    local i = math.min(math.max((mouseX - (scrnWidth *0.5 -90))/180, 0), 1)
                    bombCountPercentage = i*0.3
                end
            end

            if not mouse1Debounce then
            
                if (mouseY > scrnHeight*0.5 +150 -25) and (mouseY < scrnHeight*0.5 +150 -10) then
                    if (mouseX > (scrnWidth *0.5 -30)) and (mouseX < (scrnWidth *0.5 +30)) then
                        generateMap(25, 25, (16*12) * bombCountPercentage, true)
                        currentScreen = "game"
                    end
                end
            end
            mouse1Debounce = true
        else
            mouse1Debounce = false
        end
    end
end

function love.keypressed(key)
    if key == "escape" then
        currentScreen = "main menu"
        generateMap(16, 12, 0, false)
    end

    if key == "s" then
        if love.keyboard.isDown("lctrl") then
            save()
        end
    elseif key == "l" then
        if love.keyboard.isDown("lctrl") then
            load()
            currentScreen = "game"
        end

    end
end


function love.draw()
    if currentScreen == "game" then
        for x = 0, #map do
            for y = 0, #map[x] do
                drawSquare(x, y)
            end
        end
    elseif currentScreen == "lose" then
        for x = 0, #map do
            for y = 0, #map[x] do
                drawSquare(x, y)
            end
        end

        local scrnWidth = love.graphics.getWidth()
        local scrnHeight = love.graphics.getHeight()

        love.graphics.setColor(0, 0, 0, 0.4)
        love.graphics.rectangle("fill", 0, 0, scrnWidth, scrnHeight)

        love.graphics.setColor(0.1, 0.4, 0.1)
        love.graphics.rectangle(
            "fill",
            scrnWidth *0.5 -100,
            scrnHeight*0.5 -150,
            200, 300
        )

        love.graphics.setColor(1, 0.25, 0.25, 1)
        love.graphics.setFont(fonts[35])
        love.graphics.printf(
            "You lost",
            scrnWidth *0.5 -100,
            scrnHeight*0.5 -150 +5,
            200,
            "center"
        )

        love.graphics.setColor(1,1,1,1)
        love.graphics.setFont(fonts[15])
        love.graphics.printf(
            "Flags placed",
            scrnWidth *0.5 -100 +5,
            scrnHeight*0.5 -110 +10,
            100,
            "left"
        )
        love.graphics.printf(
            ("%s/%s"):format(placedFlags, targetFlags),
            scrnWidth *0.5 -100 +105,
            scrnHeight*0.5 -110 +10,
            100,
            "center"
        )
        
        love.graphics.printf(
            ("Restart"):format(placedFlags, targetFlags),
            scrnWidth *0.5 -100,
            scrnHeight*0.5 -150 +255,
            200,
            "center"
        )
        love.graphics.printf(
            ("Main menu"):format(placedFlags, targetFlags),
            scrnWidth *0.5 -100,
            scrnHeight*0.5 -150 +275,
            200,
            "center"
        )

    
    elseif currentScreen == "win" then
        for x = 0, #map do
            for y = 0, #map[x] do
                drawSquare(x, y)
            end
        end

        local scrnWidth = love.graphics.getWidth()
        local scrnHeight = love.graphics.getHeight()

        love.graphics.setColor(0, 0, 0, 0.4)
        love.graphics.rectangle("fill", 0, 0, scrnWidth, scrnHeight)

        love.graphics.setColor(0.1, 0.4, 0.1)
        love.graphics.rectangle(
            "fill",
            scrnWidth *0.5 -100,
            scrnHeight*0.5 -150,
            200, 300
        )

        love.graphics.setColor(0.25, 1, 0.25, 1)
        love.graphics.setFont(fonts[35])
        love.graphics.printf(
            "You won",
            scrnWidth *0.5 -100,
            scrnHeight*0.5 -150 +5,
            200,
            "center"
        )

        love.graphics.setColor(1,1,1,1)
        love.graphics.setFont(fonts[15])
        love.graphics.printf(
            ("Restart"):format(placedFlags, targetFlags),
            scrnWidth *0.5 -100,
            scrnHeight*0.5 -150 +255,
            200,
            "center"
        )
        love.graphics.printf(
            ("Main menu"):format(placedFlags, targetFlags),
            scrnWidth *0.5 -100,
            scrnHeight*0.5 -150 +275,
            200,
            "center"
        )

    elseif currentScreen == "main menu" then
        for x = 0, #map do
            for y = 0, #map[x] do
                drawSquare(x, y)
            end
        end
        local scrnWidth = love.graphics.getWidth()
        local scrnHeight = love.graphics.getHeight()

        love.graphics.setColor(0, 0, 0, 0.4)
        love.graphics.rectangle("fill", 0, 0, scrnWidth, scrnHeight)

        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.setFont(fonts[50])
        love.graphics.printf(
            "Mine sweeper",
            0,
            50,
            800,
            "center"
        )
        
        love.graphics.setFont(fonts[25])
        love.graphics.printf(
            "Play",
            0,
            150,
            800,
            "center"
        )
        love.graphics.printf(
            "Settings",
            0,
            180,
            800,
            "center"
        )
        love.graphics.printf(
            "Exit",
            0,
            scrnHeight -180,
            800,
            "center"
        )

    elseif currentScreen == "newGame" then
        for x = 0, #map do
            for y = 0, #map[x] do
                drawSquare(x, y)
            end
        end

        local scrnWidth = love.graphics.getWidth()
        local scrnHeight = love.graphics.getHeight()

        love.graphics.setColor(0, 0, 0, 0.4)
        love.graphics.rectangle("fill", 0, 0, scrnWidth, scrnHeight)

        love.graphics.setColor(0.1, 0.4, 0.1)
        love.graphics.rectangle(
            "fill",
            scrnWidth *0.5 -100,
            scrnHeight*0.5 -150,
            200, 300
        )

        love.graphics.setColor(1, 1, 1, 1)     
        love.graphics.setFont(fonts[35])
        love.graphics.printf(
            "New game",
            0,
            scrnHeight*0.5 -150 +5,
            scrnWidth,
            "center"
        )

        love.graphics.setFont(fonts[15])
        love.graphics.printf(
            "Bomb percentage:",
            0,
            scrnHeight*0.5 -150 +60,
            scrnWidth,
            "center"
        )

        love.graphics.setColor(1, 0.8, 0.5, 1)
        love.graphics.rectangle("fill", scrnWidth*0.5-90, scrnHeight*0.5 -150 +80, 180, 10)
        love.graphics.setColor(0.5, 1, 0.3, 1)
        love.graphics.rectangle("fill", scrnWidth*0.5-90, scrnHeight*0.5 -150 +80, 180*bombCountPercentage/0.3, 10)


        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.printf(
            "Play",
            0,
            scrnHeight*0.5 +150 -25,
            scrnWidth,
            "center"
        )
    end
end