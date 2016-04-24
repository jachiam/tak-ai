-- remaking GUI
-- TODO: sassy comments

-- deps
local TAK_AI = require('tak_AI')
local LIB_AI = require('lib_AI')
mm = minimax_AI.new(3,normalized_value_of_node, true)

local TAK = require('tak_game')
local suit = require('suit') -- GUI
local utf8 = require('utf8') -- for text input
-- text input
-- -- display string in textbox
local input = {text = ""}
-- -- display username
local user = 'HUMAN'
-- -- placeholder in textbox 
local instructions = ''
-- -- command history
local log = {'Click in the box', 'below to type.'}
local ups = 0
-- -- board sizes
local boardsize = { value=5, min=3, max=8 }
-- -- 
local teamcb = { text = "Black" }
local teamcw = { text = "White", checked = true }
local opponent = 'TAKAI'
local foes = { TAKAI = 1, TAKEI = 2, TAKARLO = 3 }
local pausemenu = {
  " TAK A.I. - NOT EVEN GOD CAN SAVE YOU NOW.",
  "         [esc]: close this menu",
  "'quit': exit game",
  "'export [filename]': save to filename.ptn",
  "'import [filename]': load from filename.ptn",
  "'new': start new game",
  "'undo': undo your last move",
  "'name [username]': set your name",
  "'level [1-3]': set AI level",
  "'fs': toggle fullscreen"
}
local LOGROWS = 0
local leftop_flags = {align="left", valign="top"}
local PLAYERTURN = true
local AI_LEVEL = 3
local GPTN_ROWS = {}

-- window graphics settings
local flags = {msaa = 4}
-- allow for held-keys to repeat input (mostly for backspaces)
love.keyboard.setKeyRepeat(true)


-- images --
logo     = love.graphics.newImage("img/logo.png")
takaicon = love.graphics.newImage("img/takai.png")
WTile    = love.graphics.newImage("img/wflat.png")
BTile    = love.graphics.newImage("img/bflat.png")
WWall    = love.graphics.newImage("img/wwall.png")
BWall    = love.graphics.newImage("img/bwall.png")
WCaps    = love.graphics.newImage("img/wcaps.png")
BCaps    = love.graphics.newImage("img/bcaps.png")
Pieces   = {
  {WTile, WWall, WCaps},
  {BTile, BWall, BCaps}
}

-- generate some assets (below)
function love.load()
    -- snd = generateClickySound()
    -- normal, hovered, active = generateImageButton()
    GameFont = love.graphics.newFont("DTM-Mono.otf",15)
    MMFont = love.graphics.newFont("DTM-Mono.otf",20)
    love.graphics.setFont(MMFont)
    WIDTH, HEIGHT = love.graphics.getWidth(), love.graphics.getHeight()
    print(WIDTH, HEIGHT)
    love.window.setMode(WIDTH,HEIGHT,flags)
    LOGROWS = math.floor(love.graphics.getHeight()/(5*GameFont:getHeight()))
end


function love.update(dt)
  if not t then 
    dm() 
  else
    if not PLAYERTURN and t.win_type == 'NA' then 
      makeAIMove(mm)
    elseif t.win_type ~= 'NA' then
      local winrar = ''
      if t.winner == 1 then 
        if teamcb.checked then
          winrar = opponent .. " WINS"
        else
          winrar = "YOU WIN" 
        end
      elseif t.winner == 2 then
        if teamcw.checked then
          winrar = opponent .. " WINS"
        else
          winrar = "YOU WIN"
        end
      else
        winrar = "DRAW"
      end
      instructions = "GAME OVER: " .. winrar .. "\n" ..
                     "Type 'new' to play again!\n" ..
                     "Hit 'Save' to save this game!"
      if not autosaved then 
        export()
        autosaved = true
      end
    end
  end
end

function love.draw()
  if t then 
    drawLogo()
    GPTN = t:game_to_ptn()
    dg() 
  else
    drawLogo(true)
  end
  suit.draw()
end


function dm()
  if love.graphics.getFont() ~= MMFont then love.graphics.setFont(MMFont) end

  instructions = "Welcome. Please start a new game."
  -- draw cutesy weeabo grafics
  suit.layout:reset(WIDTH/2,logo:getHeight()*1.5)
  suit.Label("takai, n.: \n\ttall, high; \n\tthe best.", 
    leftop_flags, 
    suit.layout:row(WIDTH/2,HEIGHT/2, 10,10))
  -- draw main menu
  suit.layout:reset(WIDTH/3,HEIGHT*3/5, 1,1)
  -- -- draw mm buttons
  suit.layout:push(suit.layout:row(WIDTH/3,1))
    sizLab = suit.Label("Size:", suit.layout:col(WIDTH/8,30))
    sizBrd = suit.Slider(boardsize, suit.layout:col())
    suit.Label(math.floor(boardsize.value), suit.layout:col())
  suit.layout:pop()
  suit.layout:padding(10,10)
  sizTLb = suit.Label("Team:", suit.layout:row(WIDTH/3,30))
  sizTmb = suit.Checkbox(teamcb, suit.layout:row())
  sizTmw = suit.Checkbox(teamcw, suit.layout:row())

  if teamcb.checked then teamcw.checked = false end
  if teamcw.checked then teamcb.checked = false end

  startGameButt = suit.Button("Play Tak!", suit.layout:row())

  if startGameButt.hit then
    print("GAEM STERT!",teamcb.checked,teamcw.checked,boardsize.value)
    if not teamcb then PLAYERTURN = false end
    t = tak.new(tonumber(math.floor(boardsize.value)) or 5)
    instructions = "Excellent. Enter your commands in the box below.\n" ..
                   "Make moves with Portable Tak Notation.\n" ..
                   "Click or type `Help' for more commands."
    autosaved = nil
  end
end



function dg( )
  if love.graphics.getFont() ~= GameFont then love.graphics.setFont(GameFont) end
  drawBoard()
  drawPieces()
  drawConsole()
end



function drawBoard()
  -- ht/wd of each tile
  local bs = t.size
  recSize = 0.8*HEIGHT/bs
  origin = {(WIDTH*0.95)-(bs*recSize),logo:getHeight()}

  -- table of board positions
  PosTable = {}
  local cols = {1,2,3,4,5,6,7,8}
  local rows = {'a','b','c','d','e','f','g','h'}
  switch = false
  for i=1,bs do
    PosTable[i] = {}
    for j=1,bs do
      -- color the space
      local thisSpaceColor = {}
      if switch then
        thisSpaceColor = {85,65,65}
      else
        thisSpaceColor = {175,155,155}
      end

      switch = not switch

      love.graphics.setColor(thisSpaceColor)

      local recX = (i-1)*recSize+origin[1]
      local recY = (j-1)*recSize+origin[2]
      -- save the position of the rectangle for image renders
      PosTable[i][j] = {recX, recY}
      love.graphics.rectangle('fill', recX, recY, recSize, recSize)
      love.graphics.setColor(0,0,0)
      local sq = rows[i] .. cols[bs+1-j]
      love.graphics.print(sq, recX, recY)
    end
    if bs % 2 == 0 then
      switch = not switch
    end
  end
end



function drawPieces()
  local empty_square = torch.zeros(2,3):float()
  for i=1,t.size do
    for j=1, t.size do
      local maxStack = 41 -- TODO
      for h=1,maxStack do
        local p = t.board[i][t.size+1-j][h]
        if p and p:sum() == 0 then -- TODO
          break
        end
        for team=1,2 do
          for piece=1,3 do
            local xpos,ypos = PosTable[i][j][1], PosTable[i][j][2]
            -- check if piece at this position
            if p[team][piece] ~= 0 then
              local img = Pieces[team][piece]
              local imgHgt,imgWid = img:getHeight(), img:getWidth()

              --[[ determine image scaling factor.
                    we want displayed image height ==
                    90% of tile height, as a rule.
                    However, we should err on the
                    side of smaller. ]]
              imgHgtScaleFactor = 0.6/(imgHgt/recSize)
              imgWidScaleFactor = 0.6/(imgWid/recSize)

              imgScaleFactor = math.min(imgHgtScaleFactor,
                                        imgWidScaleFactor)
              
              imgHgt,imgWid = imgHgt*imgHgtScaleFactor, imgWid*imgWidScaleFactor
              -- pad on x
              xpos = xpos + centerPiece(imgWid,recSize)
              -- if black stone, pad x to make reading stacks easier
              if team == 2 then xpos = xpos + imgWid/10 end
              -- if flatstone, pad on y
              if piece == 1 then ypos = ypos + 2*centerPiece(imgHgt,recSize) end
              -- adjust for height of stack 
              ypos = ypos - (imgHgt/10*h)

              love.graphics.setColor(220,220,220) -- to correctly display color
              -- params: image, x,y position, radians, x,y scaling factors
              love.graphics.draw(img,xpos,ypos,0,imgScaleFactor,imgScaleFactor)
              if piece == 1 then 
                love.graphics.setColor(0,0,0)
                love.graphics.rectangle('line',xpos,ypos,imgHgt,imgWid)
              end
            else
              -- no pieces of that kind here
            end
          end
        end
      end
    end
  end
end





function drawConsole()
  local topPad = logo:getHeight()
  local conwid = WIDTH/4
  -- first, draw the log
  suit.layout:reset(30,topPad+30, 5,5)
  GPTN_ROWS = getGPTNRows(math.floor(1.5*LOGROWS))
  gamerec = suit.Label(GPTN_ROWS, leftop_flags, suit.layout:row(conwid,HEIGHT/3.2))
  local logrows = getLogRows(LOGROWS)
  shell_shell = suit.Label(logrows, leftop_flags, suit.layout:row())
  suit.layout:push(suit.layout:row(conwid,25))
    userLab = suit.Label(user, leftop_flags, suit.layout:col(conwid/2,20))
    console = suit.Input(input, {id = "console"}, suit.layout:col(conwid/2,20))
  suit.layout:pop()
  suit.layout:push(suit.layout:row())
    suit.layout:padding(5)
    saveBut = suit.Button("Save Game", suit.layout:col(conwid/2,HEIGHT/21))
    helpBut = suit.Button("Help", suit.layout:col())
    if saveBut.hit then export() end
    if helpBut.hit then drawHelpMenu = true end
    if drawHelpMenu then drawHelp() end
  suit.layout:pop()
  -- if this text is submitted, add it to the log and interpret the move
  if console.submitted then
    table.insert(log,input.text)
    interpret(input.text:lower())
    input.text = ""
  end
end




function centerPiece(pieceDimension, tileDimension)
  local diff = math.abs(pieceDimension-tileDimension)
  return diff/2
end




function love.textinput(t)
  -- forward text input to SUIT
  suit.textinput(t)
end

function love.keypressed(key)
  -- forward keypressed to SUIT
  suit.keypressed(key)
  if key == 'escape' and helpMenu then 
    helpMenu = nil 
    drawHelpMenu = false
  end
end





function drawHelp()
  suit.layout:reset(WIDTH/4,HEIGHT/4, 0,0)
  helpMenu = {}
  for l=1,#pausemenu do
    table.insert(helpMenu, 
      suit.Button(pausemenu[l], 
      {align='left', valign='center', font=GameFont}, 
      suit.layout:row(WIDTH/2,20)))
  end
  suit.layout:row()
  helpCloseBut = suit.Button("Close Menu", suit.layout:row(WIDTH/4,30))
  if helpCloseBut.hit then 
    helpMenu = nil
    drawHelpMenu = false
  end
  if suit.Button("Quit Game", suit.layout:col()).hit then love.event.quit() end
end




function drawLogo(menu)
  if menu then
    local max_wid = WIDTH/2
    local w,h = logo:getWidth(), logo:getHeight()
    local tw,th = takaicon:getWidth(),takaicon:getHeight()
    local ratio,ratio_l = max_wid/w, (w/3)/tw
    love.graphics.setColor(255,255,255)
    love.graphics.draw(logo,  WIDTH/4,5,  0,  ratio,ratio)
    love.graphics.printf(instructions,WIDTH/4,HEIGHT/2,WIDTH/2,'center',0)
    love.graphics.setColor(220,220,220)
    love.graphics.draw(takaicon, WIDTH/3-tw/3,h+15,   0,    ratio_l,ratio_l)
  else
    local max_wid = WIDTH/3
    local w,h = logo:getWidth(), logo:getHeight()
    local ratio = max_wid/w
    love.graphics.setColor(255,255,255)
    love.graphics.draw(logo,  5,5,  0,  ratio,ratio)
    w,h = w*ratio, h*ratio
    love.graphics.printf(instructions,w,15,WIDTH-w,'center',0)
  end
end



function interpret(command)
  local tinput = {}
  print("command received:")
  for word in string.gmatch(command, "%g+") do
    table.insert(tinput,word)
    print(word)
  end

  if tinput[1] and t:accept_user_ptn(tinput[1]) then 
    PLAYERTURN = false
  else
    cli_parse(tinput) 
  end
end



function cli_parse(cmdtable)
  cmd = cmdtable[1]
  if cmd == 'fs' or cmd == 'fullscreen' then
    if not fs then
      love.window.setMode(0,0,flags)
      WIDTH,HEIGHT = love.graphics.getWidth(), love.graphics.getHeight()
      love.window.setMode(WIDTH,HEIGHT,flags)
      -- TODO: redraw board, pieces, logo, etc
      fs = true
    else
      WIDTH,HEIGHT = 800,600
      love.window.setMode(800,600,flags)
      fs = false
    end
  elseif cmd == 'export' or cmd == 'save' then
    export(cmdtable[2])
    local dt = (cmdtable[2] or os.date("%H:%M:%S")) .. ".txt"
    file = io.open(dt,"a+")
    io.output(file)
    local game_ptn = t:game_to_ptn()
    io.write(game_ptn)
    io.close(file)
    instructions = "Game exported to " .. dt
  elseif cmd == 'import' or cmd == 'load' then
    -- TODO
    instructions = "Importing game is not supported yet. Sorry.\n" ..
                   "You can continue a saved game at playtak.com."
    -- io.close(file)
  elseif cmd == 'name' or cmd == 'user' then
    -- TODO set username
    user = cmdtable[2]
    instructions = 'user is now known as ' .. cmdtable[2]
  elseif cmd == 'opp' then
    local s = "opponent not recognized"
    if cmdtable[2] ~= nil
    and foes[cmdtable[2]:upper()] ~= nil then
      s = 'opponent has been set to ' .. cmdtable[2]
      opponent = cmdtable[2]:upper()
    end
    instructions = s
  elseif cmd == 'level' then
    local lv = tonumber(cmdtable[2]) or 4
    if lv<=3 and mm then
      mm.depth = lv
      instructions = 'AI has been set to level ' .. lv
    else
      instructions = 'Error: AI could not be set to level ' .. lv
    end
  elseif cmd == 'new' or cmd == 'reset' then
    export()
    t = nil
  elseif cmd == 'undo' or cmd == 'oops' then
    t:undo()
    t:undo()
  elseif cmd == 'resign' or cmd == 'dammit' then
    instructions = 'TakAI knows no mercy. Sorry.'
  elseif cmd == 'quit' or cmd == 'exit' or cmd == 'logout' or cmd == 'bye' then
    love.event.quit()
  elseif cmd == 'help' or cmd == '?' or cmd == 'list' then
    drawHelpMenu = true
    drawHelp()
  elseif cmd == 'win' then
    instructions = 'Nice try.'
  elseif cmd == 'ai' then
    makeAIMove(ai)
  end
end




function makeAIMove(ai)
  if ai and t then 
    instructions = opponent .. " is thinking..."
    love.graphics.clear()
    love.draw()
    love.graphics.present()
    ai:move(t)
    PLAYERTURN = not PLAYERTURN
    instructions = "Your move."
  end
end




function getLogRows(max)
  local l = ""
  for i=math.max(#log-max,1),math.max(max,#log) do
    if not log[i] then break end
    l = l .. log[i] .. '\n'
  end
  return l
end




function getGPTNRows(max)
  local o = ''
  local ln = ''
  local tp = t:game_to_ptn(true)
  for i=math.max(#tp-max,1),math.max(max,#tp) do
    if not tp[i] then break end
    ln = tp[i]
    if i%2 ~= 0 then
      ln = (i+1)/2 .. ". " .. ln
      o = o .. ln
    else
      o = o .. " " .. ln .. "\n"
    end
  end
  return o
end




function export(filename)
  local dt = (filename or 'Game_at_' .. os.date("%H:%M:%S")) .. ".txt"
  file = io.open(dt,"a+")
  io.output(file)
  local game_ptn = t:game_to_ptn()
  io.write(game_ptn)
  io.close(file)
  print("Game exported to " .. dt .. ".txt")
end




function import(filename)
  -- body
end