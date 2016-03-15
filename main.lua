--[[

  "Y'ALL READY FOR THIS?"

  TAK: THE GAME: THE UNNECESSARILY AWFUL GUI:
    THE EXTENSION OF THE NOT-PARTICULARLY-FUNNY RUNNING GAG:
      THE DOWNFALL OF HUMANITY:
        THE FIRMWARE UPDATE:
          GENISYS

  GUI FOR JOSH ACHIAM'S SELF-PLAYING, HUMAN-SLAYING TAK ARTIFICIAL INTELLIGENCE
    WRITTEN BY TOBIAS MERKLE
      PRODUCED BY SEVERAL THOUSAND GALLONS OF COFFEE
        SPECIAL THANKS TO THE LOVE TEAM AND THE #LOVE IRC CHANNEL
          SHOUT OUT TO JOSEFNPAT, YOU THE REAL MVP

]]--

require 'tak_game'
utf8 = require('utf8') -- for text input
Gamestate = require('hump.gamestate') -- for switching between menu and board
Timer = require('hump.timer') -- ?
math.randomseed( os.time() )
local rando = math.random() -- Don't call math.random() more than 1x/sec

-- initialize game states
local board = {}
local menu = {}
local over = {}

-- setup keyboard input --
-- placeholder text for input field (global)
instructions = 'ENTER BOARD SIZE:'
input = ''
-- allow for held-keys to repeat input (mostly for backspaces)
love.keyboard.setKeyRepeat(true)
function love.textinput(t)
  input = input .. t
end


--[[

  MENU GAMESTATE

    Each :method is actually a LOVE method (eg. draw, update, etc.)

]]--
function menu:draw()
  setupGraphics()
  drawTextBox()
end

function menu:update(dt)
  Timer.update(dt)
end

function menu:keyreleased(key, code)
  if key == 'return' then
    input = tonumber(input)
    if input ~= nil and input >= 2 and input <= 10 then
      boardsize = input
      Gamestate.switch(board)
    else
      input = ''
      instructions = 'PLEASE ENTER A VALID SIZE (2-10):'
      Gamestate.switch(menu)
    end
  end

  if key = 'escape' then
    love.event.quit()
  end
end


--[[

  BOARD GAMESTATE

    As above, each of these methods is a LOVE method that is unique
      to this specific state

]]--

function board:draw()
  TAK = tak:__init(boardsize)

  -- draw the board
  local recWid = WindowSize[1]/boardsize
  local recHgt = WindowSize[2]/boardsize
  -- table of board positions
  PosTable = {}
  for i=1,boardsize do
    PosTable[i] = {}
    for j=1,boardsize do
      -- color the space
      local thisSpaceColor = {}
      if i % 2 == 0 then
        if j % 2 == 0 then
          -- [0,0] [2,2] etc
          thisSpaceColor = {111,111,111}
        else
          -- [0,1] [0,3] etc
          thisSpaceColor = {175,175,175}
        end
      else
        if j % 2 == 0 then
          -- [1,0] [1,2] etc
          thisSpaceColor = {175,175,175}
        else
          -- [1,1] [1,3] etc
          thisSpaceColor = {111,111,111}
        end
      end
      love.graphics.setColor(thisSpaceColor)
      local recX = (i-1)*WindowSize[1]/(1.15*boardsize)+WindowSize[1]/20
      local recY = (j-1)*WindowSize[2]/(1.15*boardsize)+WindowSize[2]/20

      PosTable[i][j] = {recX+recWid/5, recY+recHgt/5}

      love.graphics.rectangle('fill', recX, recY, recWid, recHgt)
    end
  end

  -- 2. draw pieces on board
  love.graphics.setColor(255,255,255) -- to correctly display images
  for i=1,boardsize do
    for j=1, boardsize do
      local maxStack = 41
      for h=1,maxStack do
        for team=1,2 do
          for piece=1,3 do
            if tak.board[i][j][h][team][piece] ~= 0 then
              local img = Pieces[team][piece]
              local imgHgt = img:getHeight()
              local imgWid = img:getWidth()
              local xpos = PosTable[i][j][1]
              local ypos = PosTable[i][j][2]+10
              if piece == 3 then
                xpos = xpos+imgWid/6
                ypos = ypos-imgHgt/4
              elseif piece == 2 then
                ypos = ypos-imgHgt/4
              else
                -- it's a normal piece.
              end
              -- adjust for height of stack
              ypos = ypos-(10*h)
              imgScaleFactor = recHgt/recWid + WHRatio/boardsize
              -- params: image, x,y position, radians, x,y scaling factors
              love.graphics.draw(img,xpos,ypos,0,imgScaleFactor,imgScaleFactor)
            else
              -- there is no piece of this type here.
            end
          end
        end
      end
    end
  end

  instructions = 'MAKE YOUR MOVE:'
  drawTextBox()
end

function board:keyreleased(key)
  -- taken from love wiki: code for interpreting backspaces
  if key == "backspace" then
    -- get the byte offset to the last UTF-8 character in the string.
    local byteoffset = utf8.offset(input, -1)

    if byteoffset then
      -- remove the last UTF-8 character.
      -- string.sub operates on bytes rather than UTF-8 characters, so we couldn't do string.sub(text, 1, -2).
      input = string.sub(input, 1, byteoffset - 1)
    end
  end

  if key == 'escape' then
    love.event.quit()
  end

  if key == 'return' then
    move = input
    if tak.is_move_valid(move) then
      tak.make_move(move)
    else
      move = nil
      input = 'ENTER A VALID MOVE:'
    end
  end

end

function board:update()
  if tak.winner ~= nil then
    Gamestate.switch(over,tak.winner)
  end


end

--[[

  STATE-AGNOSTIC FUNCTIONS
    ALT. TITLE 'OMNIFUNCTIONALS'

]]

function drawTextBox()
  love.graphics.setColor(255,255,255)
  textBoxCorner = {WindowSize[1]/3, WindowSize[2]*18/20}
  textBoxWidth = WindowSize[1]/3
  textBoxHeight = WindowSize[2]/20
  love.graphics.rectangle('fill',textBoxCorner[1],textBoxCorner[2],textBoxWidth,textBoxHeight)
  local textToDraw
  if input ~= '' then
    love.graphics.setColor(0,0,0)
    textToDraw = input
  else
    love.graphics.setColor(88,88,88)
    textToDraw = instructions
  end
  love.graphics.printf(textToDraw,textBoxCorner[1]+5,textBoxCorner[2]+5,1000,'left',0,2,2)
end

function setupGraphics()
  -- window dimensions
  love.graphics.setBackgroundColor(200,200,200)
  -- love.window.setMode(1100,750) --defaults to size of desktop
  WindowSize = {love.graphics.getDimensions()} --WS[1]=width, WS[2]=height

  -- images representing pieces and tiles
  WTile = love.graphics.newImage("img/wtile.png")
  BTile = love.graphics.newImage("img/btile.png")
  WWall = love.graphics.newImage("img/wwall.png")
  BWall = love.graphics.newImage("img/bwall.png")
  WCaps = love.graphics.newImage("img/wcaps.png")
  BCaps = love.graphics.newImage("img/bcaps.png")

  -- for drawing board
  WHRatio = WindowSize[2]/WindowSize[1]
  Pieces = {{WTile, WWall, WCaps},
    {BTile, BWall, BCaps}}
end


--[[

  THE FINAL COUNTDOWN:
    The function that starts the game itself

]]--

function love.load()
  Gamestate.registerEvents()
  Gamestate.switch(menu)
end
