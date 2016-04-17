-- remaking GUI
-- TODO: sassy comments

-- deps
local TAK = require('tak_game')
local TAI = require ('tak_tree_AI')
local suit = require('suit') -- GUI
local utf8 = require('utf8') -- for text input

-- gamestates
local menu = suit.new()
local game = suit.new()
local paus = suit.new()
local STATE = "menu"

-- text input
-- -- display string in textbox
local input = {text = " "}
-- -- display username
local user = 'HUMAN'
-- -- placeholder in textbox 
local instructions = 'ENTER BOARD SIZE:'
-- -- command history
local log = {''}
local ups = 0
-- -- board sizes
local boardsize = {text = "5"}
-- -- 
local teamcb = { text = "Black" }
local teamcw = { text = "White", checked = true }
local opponent = 'TAKAI'
local foes = { TAKAI = 1, TAKEI = 2, TAKARLO = 3 }
local pausemenu = "TAK A.I. - NOT EVEN GOD CAN SAVE YOU NOW \n\n" ..
    "           [esc]: close this menu\n" ..
    "> quit: exit game\n" ..
    "> export [filename]: save game to filename.ptn\n" ..
    "> import [filename]: load game from filename.ptn\n" ..
    "> new: start new game\n" ..
    "> undo: undo last move\n" ..
    "> name [username]: set your name\n" ..
    "> level [1-3]: set AI level\n" ..
    "> fs: toggle fullscreen"
local LOGROWS = math.floor(love.graphics.getHeight()/(2*17))
local leftop_flags = {align="left", valign="top"}


-- window graphics settings
-- local flags = {msaa = 4}
-- allow for held-keys to repeat input (mostly for backspaces)
love.keyboard.setKeyRepeat(true)


-- images --
logo   = love.graphics.newImage("img/logo.png")
WTile  = love.graphics.newImage("img/wflat.png")
BTile  = love.graphics.newImage("img/bflat.png")
WWall  = love.graphics.newImage("img/wwall.png")
BWall  = love.graphics.newImage("img/bwall.png")
WCaps  = love.graphics.newImage("img/wcaps.png")
BCaps  = love.graphics.newImage("img/bcaps.png")
Pieces = {
	{WTile, WWall, WCaps},
	{BTile, BWall, BCaps}
}

-- generate some assets (below)
function love.load()
    -- snd = generateClickySound()
    -- normal, hovered, active = generateImageButton()
    smallerFont = love.graphics.newFont(14)
    WIDTH, HEIGHT = love.graphics.getWidth(), love.graphics.getHeight()
    print(WIDTH, HEIGHT)
end


function love.update(dt)
	if STATE == "menu" then dm()
	elseif STATE == "game" then dg()
	elseif STATE == "paus" then dp()
	end
end

function love.draw()
	drawLogo()
    -- draw the gui
    if STATE == "menu" then menu:draw() 
    elseif STATE == "game" then game:draw() 
    elseif STATE == "paus" then paus:draw() 
	else print("wtf?", STATE) end
end


function dm()
	-- origin x,y , padding z,a
 	-- draw main menu
 	menu.layout:reset(WIDTH/3,HEIGHT/4, 10,10)
 	-- MM_W, MM_H = WIDTH*3/5, HEIGHT/2
 	-- -- draw mm buttons
 	sizLab = menu:Label("Board Size:", leftop_flags, menu.layout:row(WIDTH/8,20))
 	sizBrd = menu:Input(boardsize, menu.layout:row())
 	sizTLb = menu:Label("Team:", leftop_flags, menu.layout:row(WIDTH/8,20))
 	sizTmb = menu:Checkbox(teamcb, menu.layout:row())
 	sizTmw = menu:Checkbox(teamcw, menu.layout:row())

 	if teamcb.checked then teamcw.checked = false end
 	if teamcw.checked then teamcb.checked = false end

 	startGameButt = menu:Button("Sttart Gaem!", menu.layout:row())

 	if startGameButt.hit then
 		print("GAEM STERT!",teamcb.checked,teamcw.checked,boardsize.text)
 		t = tak.new(tonumber(boardsize.text) or 5)
 		STATE = "game"
 	end
end



function dg( )
	drawBoard()
  print("PIECES")
  drawConsole()
end



function drawBoard()
  -- ht/wd of each tile
  local bs = t.size
  print(bs)
  recSize = 0.75*HEIGHT/bs
  origin = {(WIDTH*0.95)-(bs*recSize),HEIGHT/20}
  print(origin[1],origin[2],bs,recSize)

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
      local sq = rows[i] .. cols[bs+1-j]
      love.graphics.print(sq, recX, recY)
    end
    if bs % 2 == 0 then
      switch = not switch
    end
  end
end



function drawConsole()
  -- first, draw the log
  game.layout:reset(30,logo:getHeight()+30, 5,5)
  logrows = getLogRows(LOGROWS)
  shell_shell = game:Label(logrows, leftop_flags, game.layout:row(WIDTH/4,HEIGHT/2))
  console = game:Input(input, {id = "console"}, game.layout:row(WIDTH/4,15))
  -- if this text is submitted, add it to the log and interpret the move
  if console.submitted then
    table.insert(log,input.text)
    interpret(input.text)
    input.text = ""
  end
end




function love.textinput(t)
    -- forward text input to SUIT
    suit.textinput(t)
end

function love.keypressed(key)
    -- forward keypressed to SUIT
    suit.keypressed(key)
end


function drawLogo()
	local max_wid = WIDTH/3
	local w,h = logo:getWidth(), logo:getHeight()
	local ratio = max_wid/w
  	love.graphics.setColor(255,255,255)
	love.graphics.draw(logo,  5,5,  0,  ratio,ratio)
	w,h = w*ratio, h*ratio
	slogan = "PTN to move\n" ..
	"'help' to list commands\n" ..
	"'quit' to quit"
	love.graphics.printf(slogan,5,h+15,250,'center',0)
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



function getLogRows(max)
	local l = ""
	for i=math.max(#log-max,1),math.max(max,#log) do
		if log[i] == nil then 
			break 
		end
		l = l .. log[i] .. '\n'
	end
	return l
end



-- generate assets (see love.load)
function generateClickySound()
    local snd = love.sound.newSoundData(512, 44100, 16, 1)
    for i = 0,snd:getSampleCount()-1 do
        local t = i / 44100
        local s = i / snd:getSampleCount()
        snd:setSample(i, 
            (.7*(2*love.math.random()-1) 
                + .3*math.sin(t*9000*math.pi)) 
                * (1-s)^1.2 * .3)
    end
    return love.audio.newSource(snd)
end

function generateImageButton()
    local metaballs = function(t, r,g,b)
        return function(x,y)
            local px, py = 2*(x/200-.5), 2*(y/100-.5)
            local d1 = math.exp(-((px-.6)^2 + (py-.1)^2))
            local d2 = math.exp(-((px+.7)^2 + (py+.1)^2) * 2)
            local d = (d1 + d2)/2
            if d > t then
                return r,g,b, 255 * ((d-t) / (1-t))^.2
            end
            return 0,0,0,0
        end
    end

    local normal, hovered, active = love.image.newImageData(200,100), 
        love.image.newImageData(200,100), 
        love.image.newImageData(200,100)
    normal:mapPixel(metaballs(.48, 188,188,188))
    hovered:mapPixel(metaballs(.46, 50,153,187))
    active:mapPixel(metaballs(.43, 255,153,0))

    return love.graphics.newImage(normal), 
        love.graphics.newImage(hovered), 
        love.graphics.newImage(active)
end