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

-- TODO Goature tut

local TAK = require('tak_game')
local TAI = require ('tak_tree_AI')
local utf8 = require('utf8') -- for text input
local Gamestate = require('hump.gamestate') -- for switching between menu and board

-- initialize gamestates
local menu = {}
local board = {}
local over = {}

-- setup keyboard input --
-- placeholder text for input field (global)
instructions = 'ENTER BOARD SIZE:'
input = ''
log = {}
-- allow for held-keys to repeat input (mostly for backspaces)
love.keyboard.setKeyRepeat(true)

function love.textinput(t)
  input = input .. t
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
  drawLogo(WindowSize[1]/3)
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
        else
          player_team = 1
          player_turn = true
        end
        Gamestate.switch(board)
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

function drawLogo(abs_wid)
  local logo = love.graphics.newImage('img/logo.png')
  local width = logo:getWidth()
  local height = logo:getHeight()
  if not abs_wid then
    abs_wid = width
  end
  local ratio = abs_wid/width
  love.graphics.setColor(255,255,255)
  love.graphics.draw(logo,0,0,0,ratio,ratio)
  slogan = "PTN to move\n" --[[""'help' to list commands\n"]] .. "[esc] to quit"
  love.graphics.printf(slogan,0,height,250,'center',0)
end


--[[

  BOARD GAMESTATE

    As above, each of these methods is a LOVE method that is unique
      to this specific state

]]--

function board:enter()
  input = ''
  AI_LEVEL = 3
  t = tak.new(boardsize)
end

function board:draw()
  -- love.graphics.clear()

  drawLogo(WindowSize[1]/3)
  drawBoard()
  drawPieces()
  drawTextBox()
end

function drawBoard()
  -- ht/wd of each tile
  recSize = 0.75*WindowSize[2]/boardsize
  origin = {(WindowSize[1]*0.95)-(boardsize*recSize),WindowSize[2]/20}

  -- table of board positions
  PosTable = {}
  local cols = {1,2,3,4,5,6,7,8}
  local rows = {'a','b','c','d','e','f','g','h'}
  switch = false
  for i=1,boardsize do
    PosTable[i] = {}
    for j=1,boardsize do
      -- color the space
      local thisSpaceColor = {}
      if switch then
        thisSpaceColor = {111,111,111}
      else
        thisSpaceColor = {222,222,222}
      end

      switch = not switch

      love.graphics.setColor(thisSpaceColor)

      local recX = (i-1)*recSize+origin[1]
      local recY = (j-1)*recSize+origin[2]

      -- save the position of the rectangle for image renders
      PosTable[i][j] = {recX, recY}
      love.graphics.rectangle('fill', recX, recY, recSize, recSize)
      love.graphics.setColor(0,0,0)
      local sq = rows[i] .. cols[boardsize+1-j]
      love.graphics.print(sq, recX, recY)
    end
    if boardsize % 2 == 0 then
      switch = not switch
    end
  end
  boarddrawn = true
end

function drawPieces()
  empty_square = torch.zeros(2,3):float()
  for i=1,boardsize do
    for j=1, boardsize do
      local maxStack = 41 -- TODO
      for h=1,maxStack do
        local p = t.board[i][boardsize+1-j][h]
        if p ~= nil and p:sum() == 0 then -- TODO
          break
        end
        for team=1,2 do
          for piece=1,3 do
            xpos = PosTable[i][j][1]
            ypos = PosTable[i][j][2]
            -- check if piece at this position
            if p[team][piece] ~= 0 then
              local img = Pieces[team][piece]
              local imgHgt = img:getHeight()
              local imgWid = img:getWidth()
              if piece == 3 then
                -- capstone. place in center
                xpos = xpos + recSize/2
              elseif piece == 2 then
                xpos = xpos + recSize/8
              else
                -- it's a normal piece.
                -- -- center piece on tile:
                xpos = xpos + recSize/10 -- TODO Gamestate.recWid/Hgt
                ypos = ypos + recSize/4
              end
              -- pad on top, and adjust for height of stack
              ypos = ypos + recSize/3 - (10*h)

              --[[ determine image scaling factor.
                    we want displayed image height ==
                    90% of tile height, as a rule.
                    However, we should err on the
                    side of smaller. ]]
              imgHgtScaleFactor = 0.75/(imgHgt/recSize)
              imgWidScaleFactor = 0.75/(imgWid/recSize)

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

function menu:keypressed(key)
  if key == 'backspace' then
    backspace(key)
  end
end

function board:keypressed(key)
  if key == 'backspace' then
    backspace(key)
  end
end

function board:keyreleased(key)
  if key == 'escape' then
    love.event.quit()
  end

  if key == 'return' then
    table.insert(log,input)
    move = input
    if move == '' or move == nil then
      return
    end
    if t:accept_user_ptn(move) then
      player_turn = false
    else
      interpret(input)
    end
    input = ''
  end
end

function interpret(command)
  local tinput = {}
  for word in string.gmatch(command, "%a+") do
    table.insert(tinput,word)
    print(word)
  end

  print (tinput)
  for k,v in pairs(tinput) do
    print (k)
    print (v)
    print ('--')
  end

  cli_parse(tinput)
end

function cli_parse(cmdtable)
  cmd = cmdtable[1]
  if cmd == 'fs' or cmd == 'fullscreen' then
    if not fs then
      love.graphics.setMode(0,0)
      winDims = love.graphics.getDimensions()
      love.graphics.setMode(winDims[1],winDims[2])
      fs = true
    else
      love.graphics.setMode(WindowSize[1],WindowSize[2])
      fs = false
    end
  elseif cmd == 'export' then
    -- TODO write to file
  elseif cmd == 'import' then
    -- TODO import game from file
  elseif cmd == 'name' or cmd == 'user' then
    -- TODO set username
    print ('user is now known as ' .. cmdtable[2])
    print ('** WARN: DIDN\'T ACTUALLY**')
  elseif cmd == 'opp' then
    -- TODO set opponent
    print ('opponent has been set to ' .. cmdtable[2])
    print ('** WARN: DIDN\'T ACTUALLY**')
    t:reset()
  elseif cmd == 'level' then
    local lv = cmdtable[2]
    if tonumber(lv) ~= nil then
      print ('AI has been set to level ' .. cmdtable[2])
      AI_LEVEL = cmdtable[2]
      t:reset()
    end
  elseif cmd == 'new' then
    t:reset()
  elseif cmd == 'undo' then
    t:undo()
  elseif cmd == 'resign' then
    -- TODO resign
  elseif cmd == 'quit' or cmd == 'exit' then
    love.event.quit()
  end
end

function board:update(dt)
  if t.win_type ~= 'NA' then
    Gamestate.switch(over,t.winner)
  end

  if not player_turn then
    instructions = 'AI IS THINKING...'
    board:draw()
    love.graphics.present()
    AI_move(t,AI_LEVEL,true)
    player_turn = true
  else
    instructions = 'MAKE YOUR MOVE:'
  end
end


--[[

  STATE-AGNOSTIC FUNCTIONS
    ALT. TITLE 'OMNIFUNCTIONALS'

]]--

function drawTextBox(bg,text,ph)
  -- check for custom colors
  if bg == nil then
    bg = {22,22,22}
  end
  if txt_color == nil then
    txt_color = {255,255,255}
  end
  if ph == nil then
    ph = {88,88,88}
  end

  love.graphics.setColor(bg)
  textBoxCorner = {0,WindowSize[2]*4/5}
  textBoxWidth = WindowSize[1]/3
  textBoxHeight = WindowSize[2]/5
  love.graphics.rectangle('fill',textBoxCorner[1],textBoxCorner[2],textBoxWidth,textBoxHeight+5)
  love.graphics.setColor(111,111,111)
  love.graphics.rectangle('line',textBoxCorner[1],textBoxCorner[2],textBoxWidth,textBoxHeight)
  local textToDraw
  if input ~= '' then
    love.graphics.setColor(txt_color)
    textToDraw = '> ' .. input .. '_'
  else
    love.graphics.setColor(ph)
    textToDraw = '! ' .. instructions
  end

  -- draw last 5 lines of log
  for l=1,5 do
    -- love.graphics.printf(log[#log-l])
  end
  love.graphics.printf(textToDraw,textBoxCorner[1]+5,WindowSize[2]-15,textBoxWidth-5,'left',0)
end

function setupGraphics()
  -- window dimensions
  love.graphics.setBackgroundColor(11,11,11)
  WindowSize = {love.graphics.getDimensions()} --WS[1]=width, WS[2]=height
  -- if not fs then
  --   love.window.setMode(0,0)
  --   local w,h = love.graphics.getDimensions()
  --   love.window.setMode(w,h)
  -- end
  fs = true

  -- images representing pieces and flats
  -- TODO: color tint
  WTile = love.graphics.newImage("img/wflat.png")
  BTile = love.graphics.newImage("img/bflat.png")
  WWall = love.graphics.newImage("img/wwall.png")
  BWall = love.graphics.newImage("img/bwall.png")
  WCaps = love.graphics.newImage("img/wcaps.png")
  BCaps = love.graphics.newImage("img/bcaps.png")
  Pieces = {{WTile, WWall, WCaps},
            {BTile, BWall, BCaps}}

  -- for drawing board
  WHRatio = WindowSize[2]/WindowSize[1]
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
