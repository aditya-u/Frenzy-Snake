local curses = require("curses")
local sleep = require("socket").sleep
local math = require("math")
local Window = curses.initscr()

local TWidth, THeight = curses.cols(), curses.lines()
local MWidth, MHeight = TWidth, THeight-1

local TickTime = 0.1
local StartTime = os.time()

local snakeBody = {}
local SnakeDirection = 1
local colorTable = {42, 43, 41, 45, 44, 46, 47}
local SnakeColor = 1

local initialApples = 6 
local Apples = {}
local ApplesD = {
    {"❂", colorTable[math.random(1,7)], colorTable[math.random(1,7)]},
    {"❂", colorTable[math.random(1,7)], colorTable[math.random(1,7)]},
    {"❂", colorTable[math.random(1,7)], colorTable[math.random(1,7)]},
    {"❂", colorTable[math.random(1,7)], colorTable[math.random(1,7)]},
    {"❂", colorTable[math.random(1,7)], colorTable[math.random(1,7)]},
    {"❂", colorTable[math.random(1,7)], colorTable[math.random(1,7)]},
    {"❂", colorTable[math.random(1,7)], colorTable[math.random(1,7)]},
    {"❂", colorTable[math.random(1,7)], colorTable[math.random(1,7)]}     
}

local stat = false 

local ANSI_interface = {}

do
    function ANSI_interface.saveCursorPosition()
        io.write("\27[s") 
    end

    function ANSI_interface.restoreCursorPosition() 
        io.write("\27[u") 
    end

    function ANSI_interface.clearScreen() 
        io.write("\27[2J") 
    end

    function ANSI_interface.clearLine() 
        io.write("\27[K") 
    end
    
    local cursorPos = "\27[%d;%dH"
    function ANSI_interface.setCursorPos(x, y)
        io.write(string.format(cursorPos, y, x))
    end

    local cursorUp = "\27[%dA"
    function ANSI_interface.moveCursorUp(distance)
        io.write(string.format(cursorUp, distance or 1))
    end

    local cursorDown = "\27[%dB"
    function ANSI_interface.moveCursorDown(distance)
        io.write(string.format(cursorDown, distance or 1))
    end
    
    local cursorRight = "\27[%dC"
    function ANSI_interface.moveCursorRight(distance)
        io.write(string.format(cursorRight, distance or 1))
    end
    
    local cursorLeft = "\27[%dD"
    function ANSI_interface.moveCursorLeft(distance)
        io.write(string.format(cursorLeft, distance or 1))
    end

    local graphicsMode = "\27[%sm"
    function ANSI_interface.setGraphicsMode(...)
        local modes = {...}
        for i,j in pairs(modes) do modes[i] = tostring(j) end
        io.write(string.format(graphicsMode, table.concat(modes, ";")))
    end

    local displayMode = "\27[=%dh"
    function ANSI_interface.setMode(mode)
        io.write(string.format(displayMode, mode))
    end

    local resetMode = "\27[=%dl"
    function ANSI_interface.SetResetMode(mode)
        io.write(string.format(resetMode, mode))
    end

    local keyboardStrings = "\27[%sm"
    function ANSI_interface.setKeyboardString(...)
        local keys = {...}
        for i,j in pairs(keys) do keys[i] = tostring(j) end
        io.write(string.format(keyboardStrings, table.concat(keys, ";")))
    end
end

local function DirectionToVector(direction)
    if direction == 0 then return 0, -1
    elseif direction == 1 then return 1, 0
    elseif direction == 2 then return 0, 1
    elseif direction == 3 then return -1, 0
    else return 0,0 end
end

local function DrawBackground()
    ANSI_interface.setCursorPos(1, 1)
    ANSI_interface.setGraphicsMode(0, 1, stat and 31 or 30, 40)

    local lineString = string.rep(".", MWidth)

    for y=1, MHeight do
        ANSI_interface.setCursorPos(0, y)
        io.write(lineString)
    end
end


local function DrawSnake()
    ANSI_interface.setGraphicsMode(0, 1, colorTable[SnakeColor])

    for k, piece in pairs(snakeBody) do
        ANSI_interface.setCursorPos(piece[1], piece[2])
        io.write(" ")
    end
end

local function DrawApples()
    for id, Fruit in pairs(Apples) do
        ANSI_interface.setCursorPos(Fruit[1], Fruit[2])
        local fType = Fruit[3]
        local fInfo = ApplesD[fType]
        ANSI_interface.setGraphicsMode(1, fInfo[2], fInfo[3])
        io.write(fInfo[1])
    end
end

local function DrawInfoBar()
    ANSI_interface.setGraphicsMode(0, 1, 33, 40)
    ANSI_interface.setCursorPos(1, MHeight+1)
    io.write("Insight: ")
    ANSI_interface.setGraphicsMode(37)
    io.write(#snakeBody)
    ANSI_interface.setGraphicsMode(0, 1, 33, 40)
    ANSI_interface.setCursorPos(30, MHeight+1)
    io.write("Perception: ")
    ANSI_interface.setGraphicsMode(37)
    io.write(1-TickTime)
    local time = tostring(math.floor((stat or os.time()) - StartTime)).."s"
    local timestr = "Time: "
    ANSI_interface.setCursorPos(MWidth - (#timestr + #time), MHeight+1)
    ANSI_interface.setGraphicsMode(33)
    io.write(timestr)
    ANSI_interface.setGraphicsMode(37)
    io.write(time)
end

local function DrawGameOver()
    if not stat then return end

    local GameOver = {
    "                    ",
    "  ****************  ",
    "    CANNIBALISED    ",
    "  ****************  ",
    "                    "}

    ANSI_interface.setGraphicsMode(0, 1, 31, 40)
    ANSI_interface.setCursorPos(math.floor((TWidth-string.len(GameOver[1]))/2), math.floor((THeight-#GameOver)/2))
    for k, line in ipairs(GameOver) do
        ANSI_interface.saveCursorPosition()
        io.write(line)
        ANSI_interface.restoreCursorPosition()
        ANSI_interface.moveCursorDown(1)
    end
end

local function RenderGame()
    ANSI_interface.setGraphicsMode(0, 37, 40)
    ANSI_interface.clearScreen()
    DrawBackground()
    DrawSnake()
    DrawApples()
    DrawInfoBar()
    DrawGameOver()
    io.flush()
end

local function NewFruit()
    while true do
        local FruitX, FruitY = math.random(1, MWidth), math.random(1, MHeight)

        local continue = true

        for id, Fruit in pairs(Apples) do
            if Fruit[1] == FruitX and Fruit[2] == FruitY then
                continue = false
                break
            end
        end

        if continue then

            for id, Piece in pairs(snakeBody) do
                if Piece[1] == FruitX and Piece[2] == FruitY then
                    continue = false
                    break
                end
            end
        end

        if continue then

            Apples[#Apples + 1] = {FruitX, FruitY, math.random(1, #ApplesD)}
            break
        end
    end
end

local function MoveSnake()
    local mx, my = DirectionToVector(SnakeDirection)

    local HeadX, HeadY = snakeBody[1][1], snakeBody[1][2]
    HeadX, HeadY = (HeadX + mx -1)%MWidth +1, (HeadY + my-1)%MHeight +1

    local extend = false

    for id, Fruit in pairs(Apples) do
        if HeadX == Fruit[1] and HeadY == Fruit[2] then
            extend = true
            table.remove(Apples, id)
            TickTime = TickTime-0.001
            if #snakeBody%10==0
            then
            SnakeColor = SnakeColor+1
            end
            break
        end
    end

    table.insert(snakeBody, 1, {HeadX, HeadY})
    if not extend then snakeBody[#snakeBody] = nil else
        NewFruit() 
    end

    for i=2, #snakeBody do
        local PieceX, PieceY = snakeBody[i][1], snakeBody[i][2]
        if HeadX == PieceX and HeadY == PieceY then
            stat = os.time()
            break
        end
    end
end

local function CheckInput()
    while true do
        local input = Window:getch()
        if not input then break end

        if input == 27 then
            if Window:getch() == 91 then 
                local char = Window:getch()
                if char and char <= 255 then
                    char = string.char(char)

                    if char == "A" and SnakeDirection ~= 2 then 
                        SnakeDirection = 0
                        break
                    elseif char == "B" and SnakeDirection ~= 0 then
                        SnakeDirection = 2
                        break
                    elseif char == "C" and SnakeDirection ~= 3 then
                        SnakeDirection = 1
                        break
                    elseif char == "D" and SnakeDirection ~= 1 then
                        SnakeDirection = 3
                        break
                    end
                end
            end
        end
    end
end

local function RunGame()
    math.randomseed(os.time())
    ANSI_interface.setCursorPos(0, 0)
    curses.curs_set(0)
    curses.cbreak(true)
    curses.echo(false)
    assert(Window:nodelay(true), "Failed to make getch() non-blocking")

    local HeadX, HeadY = math.floor(TWidth/2), math.floor(THeight/2)
    snakeBody[1] = {HeadX, HeadY}
    snakeBody[2] = {HeadX-1, HeadY}
    snakeBody[3] = {HeadX-2, HeadY}
    snakeBody[4] = {HeadX-3, HeadY}
    snakeBody[5] = {HeadX-4, HeadY}

    for i=1, initialApples do NewFruit() end

    while true do
        CheckInput()
        if not stat then MoveSnake() end
        RenderGame()

        sleep((SnakeDirection == 0 or SnakeDirection == 2) and TickTime*2 or TickTime)
    end

    ANSI_interface.setCursorPos(0, THeight+1)
end

RunGame()

ANSI_interface.setGraphicsMode(0, 37)
