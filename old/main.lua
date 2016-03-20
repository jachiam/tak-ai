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

local loveframes = require('LoveFrames')
local ENM = require('move_enumerator')
local TAK = require('tak_game')
local TAI = require ('tak_tree_AI')
local TTS = require('tak_test_suite')
local utf8 = require('utf8') -- for text input
local Gamestate = require('hump.gamestate') -- for switching between menu and board

-- initialize gamestates
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
  loveframes.textinput(t)
end

function love.draw()
  loveframes.draw()
end

function love.update()
  loveframes.update()
end

function love.keypressed(key)
  loveframes.keypressed(key)
end

function love.keyreleased(key)
  loveframes.keyreleased(key)
end

function love.mousepressed(x,y,button)
  loveframes.mousepressed(x,y,button)
end

function love.mousereleased(x,y,button)
  loveframes.mousereleased(x,y,button)
end

--[[

  MENU GAMESTATE

    Each :method is actually a LOVE method (eg. draw, update, etc.)

]]--
function menu:enter()
  teamselect = false
end

function menu:draw()
  setupGraphics()
  drawTextBox()
  drawLogo()
end

function menu:keyreleased(key, code)
  if key == 'backspace' then
    backspace(key)
  end

  if key == 'return' then
    if not teamselect then
      input = tonumber(input)
      if input ~= nil and input >= 3 and input <= 10 then
        boardsize, input = input, ''
        teamselect = true
        instructions = 'SELECT TEAM (B/W):'
      else
        input = ''
        instructions = 'PLEASE ENTER A VALID SIZE (3-10):'
        Gamestate.switch(menu)
      end
    else
      input = input:lower()
      if input == 'b' or input == 'w' then
        if input == 'b' then
          player_team = 2
          Gamestate.switch(board)
        else
          player_team = 1
          player_turn = true
          Gamestate.switch(board)
        end
      else
        input = ''
        instructions = 'ENTER VALID TEAM (B/W):'
      end
    end
  end

  if key == 'escape' then
    love.event.quit()
  end
end

function drawLogo()
  local image = loveframes.Create("image", menu)
  image:SetImage("img/logo.png")
end


--[[

  BOARD GAMESTATE

    As above, each of these methods is a LOVE method that is unique
      to this specific state

]]--

function board:enter()
  input = ''
  t = tak.new(boardsize)
end

function board:draw()
  love.graphics.clear()

  drawTextBox()
  drawBoard()
  drawPieces()
end

function drawBoard()
  -- ht/wd of each tile
  recWid = WindowSize[1]/boardsize
  recHgt = WindowSize[2]/boardsize

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

      -- save the position of the rectangle for image renders
      PosTable[i][j] = {recX, recY}
      love.graphics.rectangle('fill', recX, recY, recWid, recHgt)
    end
  end
  boarddrawn = true
end

function drawPieces()
  empty_square = torch.zeros(2,3):float()
  for i=1,boardsize do
    for j=1, boardsize do
      local maxStack = 41
      for h=1,maxStack do
        if t.board[i][j][h] ~= nil
        and t.board[i][j][h]:sum() == 0 then
          break
        end
        for team=1,2 do
          for piece=1,3 do
            local nopieces = 0
            xpos = PosTable[i][j][1]
            ypos = PosTable[i][j][2]
            -- check if piece at this position
            if t.board[i][j][h][team][piece] ~= 0 then
              local img = Pieces[team][piece]
              local imgHgt = img:getHeight()
              local imgWid = img:getWidth()
              if piece == 3 then
                -- capstone. place in center
                xpos = xpos + recWid/2 - imgWid/2
                ypos = ypos - recWid/3
              elseif piece == 2 then
                ypos = ypos-imgHgt/4
              else
                -- it's a normal piece.
                -- -- center piece on tile:
                xpos = xpos + recWid/10
                ypos = ypos + recHgt/10
              end
              -- adjust for height of stack
              ypos = ypos-(10*h)

              --[[ determine image scaling factor.
                    we want displayed image height ==
                    90% of tile height, as a rule.
                    However, we should err on the
                    side of smaller. ]]

              imgHgtScaleFactor = 0.75/(imgHgt/recHgt)
              imgWidScaleFactor = 0.75/(imgWid/recWid)

              imgScaleFactor = math.min(imgHgtScaleFactor,
                                        imgWidScaleFactor)

              love.graphics.setColor(255,255,255) -- to correctly display color

              -- params: image, x,y position, radians, x,y scaling factors
              love.graphics.draw(img,xpos,ypos,0,imgScaleFactor,imgScaleFactor)
            else
              -- no pieces of that kind here
            end
          end
        end
      end
    end
  end
end

function findLegalSpots(player)

end

function drawButton(x,y,stroke,fill)
  if x == nil or y == nil then
    return
  elseif stroke == nil or fill == nil then
    local stroke = {0,0,0}
    local fill = {0,100,200}
  end

  love.graphics.setColor(fill)
  love.graphics.rectangle('fill',x,y,20,10)
  love.graphics.setColor(stroke)
  love.graphics.rectangle('line',x,y,20,10)
end

function board:keyreleased(key)
  if key == 'backspace' then
    backspace(key)
  end

  if key == 'escape' then
    love.event.quit()
  end

  if key == 'return' then
    move, input = input, ''
    if move == '' or move == nil then
      return
    end
    if player_move(move) then
      player_turn = false
    else
      move = nil
      input = ''
      instructions = 'ENTER A VALID MOVE:'
    end
  end

end

draw_duration = 2
time_elapsed = 0
function board:update(dt)
  if t.win_type ~= 'NA' then
    Gamestate.switch(over,t.winner)
  end

  if not player_turn then
    AI_move()
    player_turn = true
  else
    instructions = 'MAKE YOUR MOVE...'
  end

  if boarddrawn then
    drawPieces()
  end
end


--[[

  STATE-AGNOSTIC FUNCTIONS
    ALT. TITLE 'OMNIFUNCTIONALS'

]]--

function drawTeStBox ()
  local frame = loveframes.Create('frame')
  frame:SetName("Text Input")
  frame:SetSize(500, 90)

    local textinput = loveframes.Create("textinput", frame)
  textinput:SetPos(5, 30)
  textinput:SetWidth(490)
  textinput.OnEnter = function(object)
      if not textinput.multiline then
          object:Clear()
      end
  end
  textinput:SetFont(love.graphics.newFont(12))

  local togglebutton = loveframes.Create("button", frame)
  togglebutton:SetPos(5, 60)
  togglebutton:SetWidth(490)
  togglebutton:SetText("Toggle Multiline")
  togglebutton.OnClick = function(object)
      if textinput.multiline then
          frame:SetHeight(90)
          frame:Center()
          togglebutton:SetPos(5, 60)
          textinput:SetMultiline(false)
          textinput:SetHeight(25)
          textinput:SetText(input)
      else
          frame:SetHeight(365)
          frame:Center()
          togglebutton:SetPos(5, 335)
          textinput:SetMultiline(true)
          textinput:SetHeight(300)
          textinput:SetText(instructions)
      end
  end
end

function drawTextBox(bg,text,ph)
  -- check for custom colors
  if bg == nil then
    bg = {255,255,255}
  end
  if txt_color == nil then
    txt_color = {0,0,0}
  end
  if ph == nil then
    ph = {88,88,88}
  end

  love.graphics.setColor(bg)
  textBoxCorner = {WindowSize[1]/3, WindowSize[2]*18/20}
  textBoxWidth = WindowSize[1]/3
  textBoxHeight = WindowSize[2]/20
  love.graphics.rectangle('fill',textBoxCorner[1],textBoxCorner[2],textBoxWidth,textBoxHeight)
  local textToDraw
  if input ~= '' then
    love.graphics.setColor(txt_color)
    textToDraw = input
  else
    love.graphics.setColor(ph)
    textToDraw = instructions
  end
  love.graphics.printf(textToDraw,textBoxCorner[1]+5,textBoxCorner[2]+5,1000,'left',0,2,2)
end

function setupGraphics()
  -- window dimensions
  love.graphics.setBackgroundColor(200,200,200)
  WindowSize = {love.graphics.getDimensions()} --WS[1]=width, WS[2]=height
  if not fs then
    love.window.setMode(0,0)
    local w,h = love.graphics.getDimensions()
    love.window.setMode(w,h)
  end
  fs = true

  -- images representing pieces and flats
  WTile = love.graphics.newImage("img/wflat.png")
  BTile = love.graphics.newImage("img/bflat.png")
  WWall = love.graphics.newImage("img/wwall.png")
  BWall = love.graphics.newImage("img/bwall.png")
  WCaps = love.graphics.newImage("img/wcaps.png")
  BCaps = love.graphics.newImage("img/bcaps.png")

  -- for drawing board
  WHRatio = WindowSize[2]/WindowSize[1]
  Pieces = {{WTile, WWall, WCaps},
    {BTile, BWall, BCaps}}
end

function backspace(key)
-- taken from love wiki: code for interpreting backspaces
  -- get the byte offset to the last UTF-8 character in the string.
  local byteoffset = utf8.offset(input, -1)

  if byteoffset then
    -- remove the last UTF-8 character.
    -- string.sub operates on bytes rather than UTF-8 characters, so we couldn't do string.sub(text, 1, -2).
    input = string.sub(input, 1, byteoffset - 1)
  end
end


--[[

  GAME OVER MENU:
    What happens when the AI beats you

]]--

function over:draw()
  love.graphics.clear()
  love.graphics.setBackgroundColor(0,0,0)
  drawBoard()
  drawPieces()
  instructions = t.outstr
  drawTextBox({0,0,0},{255,255,255},{255,255,255})
end

function over:keyreleased(key)
  if key == 'escape' then
    love.event.quit()
  end
end


--[[

  THE FINAL COUNTDOWN:
    The function that starts the game itself

]]--

function love.load()
  Gamestate.registerEvents()
  Gamestate.switch(menu)
end

-- just in case:
math.randomseed( os.time() )
local rando = math.random() -- Don't call math.random() more than 1x/sec
