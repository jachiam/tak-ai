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
local pause = {}

-- setup keyboard input --
-- placeholder text for input field (global)
instructions = 'ENTER BOARD SIZE:'
ups = 0
input = ''
log = {'','','','','','',''}
user = 'HUMAN'
opponent = 'TAKAI'
foes = { TAKAI = 1, TAKEI = 2, TAKARLO = 3 }
pausemenu = "TAK A.I. - NOT EVEN GOD CAN SAVE YOU NOW \n\n" ..
    "[esc]: close menu // [esc] (in game): exit game\n" ..
    "> export [filename]: save game to filename.ptn\n" ..
    "> import [filename]: load game from filename.ptn\n" ..
    "> new: start new game\n" ..
    "> undo: undo last move\n" ..
    "> name [username]: set your name\n" ..
    "> level [1-3]: set AI level\n" ..
    "> fs: toggle fullscreen"

-- window graphics settings
flags = {msaa = 4}

game_inprogress = false
-- allow for held-keys to repeat input (mostly for backspaces)
love.keyboard.setKeyRepeat(true)

function love.textinput(t)
  input = input .. t
  print(input)
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
  drawSidebar(WindowSize[1]/3)
  drawConsole()

  love.graphics.setColor(255,255,255)
  local intro = "Choose a board size (3-8) \n" ..
    "and pick a team \n" ..
    "to begin play."
  love.graphics.printf(intro,WindowSize[1]/2,WindowSize[2]/2,250,'center')
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
      input = input:lower() -- :lower() converts to lower-case
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

function drawSidebar(abs_wid)
  love.graphics.setColor(11,11,11)
  love.graphics.rectangle('fill',0,0,abs_wid,WindowSize[2])
  local logo = love.graphics.newImage('img/logo.png')
  local width = logo:getWidth()
  local height = logo:getHeight()
  if not abs_wid then
    abs_wid = width
  end
  local ratio = abs_wid/width
  love.graphics.setColor(255,255,255)
  love.graphics.draw(logo,5,5,0,ratio,ratio)
  slogan = "PTN to move\n" ..
    "'help' to list commands\n" ..
    "[esc] to quit"
  love.graphics.printf(slogan,0,height,250,'center',0)
end


--[[

  BOARD GAMESTATE

    As above, each of these methods is a LOVE method that is unique
      to this specific state

]]--

function board:enter(_,continue)
  game_inprogress = true
  input = ''
  user = 'HUMAN'
  AI_LEVEL = 3
  if continue then
    return
  else
    t = tak.new(boardsize)
  end
end

function board:draw()
  -- love.graphics.clear()

  drawSidebar(WindowSize[1]/3)
  drawBoard()
  drawPieces()
  drawConsole()
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
                xpos = xpos + recSize/4
              elseif piece == 2 then
                xpos = xpos + recSize/8
              else
                -- it's a normal piece.
                -- center piece on tile:
                xpos = xpos + recSize/10 -- TODO Gamestate.recWid/Hgt
                ypos = ypos + recSize/6
              end
              -- pad on top, and adjust for height of stack
              ypos = ypos + recSize/3 - (imgHgt/25*h)

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

  if key == 'up' then
    if ups < #log then
      ups = ups + 1
      input = log[#log+1-ups]
    else
      ups = 0
      input = ''
    end
  end

  if key == 'down' then
    if ups > 0 then
      ups = ups - 1
      input = log[#log+1-ups]
    end
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
    ups = 0
    input = ''
  end
end

function interpret(command)
  local tinput = {}
  for word in string.gmatch(command, "%a+") do
    table.insert(tinput,word)
    print(word)
  end

  cli_parse(tinput)
end

function cli_parse(cmdtable)
  cmd = cmdtable[1]
  if cmd == 'fs' or cmd == 'fullscreen' then
    if not fs then
      love.graphics.setMode(0,0,flags)
      local w,h = love.graphics.getWidth(), love.graphics.getHeight()
      love.graphics.setMode(w,h,flags)
      fs = true
    else
      love.graphics.setMode(WindowSize[1],WindowSize[2],flags)
      fs = false
    end
  elseif cmd == 'export' then
    -- TODO write to file
  elseif cmd == 'import' then
    -- TODO import game from file
  elseif cmd == 'name' or cmd == 'user' then
    -- TODO set username
    user = cmdtable[2]
    print ('user is now known as ' .. cmdtable[2])
  elseif cmd == 'opp' then
    local s = "opponent not recognized"
    if cmdtable[2] ~= nil
    and foes[cmdtable[2]:upper()] ~= nil then
      s = 'opponent has been set to ' .. cmdtable[2]
      opponent = cmdtable[2]:upper()
    end
    table.insert(log, s)
    print(s)
  elseif cmd == 'level' then
    local lv = cmdtable[2]
    if tonumber(lv) ~= nil then
      print ('AI has been set to level ' .. cmdtable[2])
      AI_LEVEL = cmdtable[2]+2
    end
  elseif cmd == 'new' or cmd == 'reset' then
    t:reset()
    -- if cmdtable[2] ~= nil
    -- and tonumber(cmdtable[2]) ~= nil
    -- and (5 - tonumber(cmdtable[2]) < 3) then
    --   boardsize = cmdtable[2]
    --   Gamestate.switch(board)
    -- end
  elseif cmd == 'undo' or cmd == 'oops' then
    t:undo()
    t:undo()
  elseif cmd == 'resign' or cmd == 'dammit' then
    -- TODO resign
  elseif cmd == 'quit' or cmd == 'exit' or cmd == 'logout' or cmd == 'bye' then
    love.event.quit()
  elseif cmd == 'help' or cmd == '?' or cmd == 'list' then
    Gamestate.switch(pause,true)
  elseif cmd == 'win' then
    instructions = 'Nice try.'
  elseif cmd == 'ai' then
    AI_move(t,AI_LEVEL,true)
  end
end

function board:update(dt)
  if input == nil then
    input = ''
  end

  if t.win_type ~= 'NA' then
    input = ''
    instructions = t.outstr
  end

  if not player_turn and t.win_type == 'NA' then
    instructions = opponent .. ' IS THINKING...'
    board:draw()
    love.graphics.present()
    AI_move(t,AI_LEVEL,true)
    player_turn = true
  elseif player_turn and t.win_type ~= 'NA' then
    pausemenu = opponent .. ' WINS!'
    Gamestate.switch(pause)
  elseif not player_turn and t.win_type ~= 'NA' then
    pausemenu = user .. ' WINS!'
    Gamestate.switch(pause)
  else
    instructions = 'MAKE YOUR MOVE:'
  end
end


--[[

  STATE-AGNOSTIC FUNCTIONS
    ALT. TITLE 'OMNIFUNCTIONALS'

]]--

function drawConsole(bg,text,ph)
  -- check for custom colors
  local bg = bg
  local txt_color = text
  local ph = ph

  if bg == nil then
    bg = {22,22,22}
  end
  if txt_color == nil then
    txt_color = {255,255,255}
  end
  if ph == nil then
    ph = {88,88,88}
  end

  if not player_turn and game_inprogress then
    bg = {50,50,100}
    txt_color= {0,0,0}
    ph = {230,230,230}
  end

  love.graphics.setColor(bg)
  consoleCorner = {0,WindowSize[2]*4/5}
  consoleWidth = WindowSize[1]/3
  consoleHeight = WindowSize[2]/5
  love.graphics.rectangle('fill',consoleCorner[1],consoleCorner[2],consoleWidth,consoleHeight+5)
  love.graphics.setColor(111,111,111)
  love.graphics.rectangle('line',consoleCorner[1],consoleCorner[2],consoleWidth,consoleHeight)

  -- draw last 5 lines of log
  love.graphics.setColor(ph)
  for l=1,7 do
    log_str = '' .. log[#log+1-l]
    love.graphics.printf(log_str,consoleCorner[1]+5,WindowSize[2]-15*(l+1),consoleWidth-5,'left',0)
  end

  local textToDraw
  if input ~= '' then
    love.graphics.setColor(txt_color)
    textToDraw = user .. '> ' .. input .. '_'
  else
    love.graphics.setColor(ph)
    textToDraw = '! ' .. instructions
  end

  -- draw CLI
  love.graphics.printf(textToDraw,consoleCorner[1]+5,WindowSize[2]-15,consoleWidth-5,'left',0)

  -- finally, draw the PTN display
  if consoleWidth ~= nil and consoleHeight ~= nil then
    drawPTN(consoleWidth,consoleHeight,WindowSize[2]*1/3)
  end
end

function drawPTN(ptn_w,ptn_h,ptn_y) 
  love.graphics.setColor(22,22,22)
  local total_h = WindowSize[1]/3
  local visible_lines = total_h / 15
  visible_lines = 3
  love.graphics.setColor(77,77,77)
  love.graphics.rectangle('fill',0,ptn_y,ptn_w,total_h)
  love.graphics.setColor(200,200,200)
  love.graphics.rectangle('line',0,ptn_y,ptn_w,total_h)

  if t ~= nil then
    ptnt = t:game_to_ptn(true)
    ptnlines = {} 

    local step = 1
    for l=1,visible_lines,2 do
      local line = ptnt[l]
      if ptnt[l+1] ~= nil then
        line = line .. ' ' .. ptnt[l+1]
      end
      if line ~= nil then
        line = step .. '. ' .. line
      else
        line = ''
      end
      love.graphics.print(line, 5, ptn_y+15*(step))
      step = step + 1
    end
  end
  drawGameViewerButtons(ptn_w,total_h,ptn_y)
end

function drawGameViewerButtons(ptn_w,ptn_h,ptn_y)
  gvby = ptn_y+ptn_h*18/20
  gvbw = ptn_w/2
  gvbh = ptn_h/10
  love.graphics.setColor(200,200,200)
  love.graphics.rectangle('fill',0,gvby,gvbw,gvbh)
  love.graphics.rectangle('fill',gvbw,gvby,gvbw,gvbh)
  love.graphics.setColor(77,77,77)
  love.graphics.rectangle('line',0,gvby,gvbw,gvbh)
  love.graphics.rectangle('line',gvbw,gvby,gvbw,gvbh)
  love.graphics.setColor(0,0,0)
  love.graphics.print("Back" ,gvbw/3,gvby+gvbh/3)
  love.graphics.print("Next",gvbw+gvbw/3,gvby+gvbh/3)
end

function board:mousepressed(x,y,b)
  if b ~= 1 then
    return
  end

  if x < gvbw and y > gvby and y < (gvby + gvbh) then
    -- back button
    print('back')
  end

  if x > gvbw and x < 2*gvbw and y > gvby and y < (gvby + gvbh) then
    -- next button
    print('next')
  end
end

function setupGraphics()
  -- window dimensions
  love.graphics.setBackgroundColor(11,11,11)
  WindowSize = {love.graphics.getWidth(), love.graphics.getHeight()} --WS[1]=width, WS[2]=height
  fs = false

  -- images representing pieces and flats
  -- TODO: color tint
  WTile = love.graphics.newImage("img/wflat.png")
  BTile = love.graphics.newImage("img/bflat.png")
  WWall = love.graphics.newImage("img/wwall.png")
  BWall = love.graphics.newImage("img/bwall.png")
  WCaps = love.graphics.newImage("img/wcaps.png")
  BCaps = love.graphics.newImage("img/bcaps.png")
  Pieces = {
    {WTile, WWall, WCaps},
    {BTile, BWall, BCaps}
  }
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

  PAUSE/GAME OVER MENU:
    What happens when the AI beats you

]]--

function pause:enter(gameover)
  if not gameover then 
    pausemenu = "TAK A.I. - NOT EVEN GOD CAN SAVE YOU NOW \n\n" ..
    "[esc]: quit\n" ..
    "> export [filename]: save game to filename.ptn\n" ..
    "> import [filename]: load game from filename.ptn\n" ..
    "> new: start new game\n" ..
    "> undo: undo last move\n" ..
    "> name [username]: set your name\n" ..
    "> level [1-3]: set AI level\n" ..
    "> fs: toggle fullscreen"
  end
end

function pause:draw()
  love.graphics.clear()
  love.graphics.setBackgroundColor(125,100,100)
  setupGraphics()
  drawBoard()
  drawPieces()

  local menuW, menuH = WindowSize[1]/2, WindowSize[2]/4
  love.graphics.setColor(0,0,0)
  love.graphics.rectangle('fill',menuW/2,menuH,menuW,menuH)
  love.graphics.setColor(230,200,200)
  love.graphics.print(pausemenu, menuW/2+5, menuH+5)
  love.graphics.rectangle('line',menuW/2,menuH,menuW,menuH)
end

function pause:keyreleased(key)
  if key == 'escape' then
    if t.win_type == 'NA' then
      Gamestate.switch(board,true)
    else 
      game_inprogress = false
      instructions = 'TO PLAY AGAIN, ENTER A BOARD SIZE'
      Gamestate.switch(menu)
    end
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
