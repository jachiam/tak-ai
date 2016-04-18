-- remaking GUI
-- TODO: sassy comments

-- deps
local TAK = require('tak_game')
local TAI = require ('tak_tree_AI')
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
local log = {''}
local ups = 0
-- -- board sizes
local boardsize = { value=5, min=3, max=8}
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
  if not t then dm() end
end

function love.draw()
  drawLogo()
  if t and t.win_type == 'NA' then 
  	GPTN = t:game_to_ptn()
  	dg() 
  end
  suit.draw()
end


function dm()
	instructions = "Welcome. Please start a new game."
 	-- draw main menu
 	suit.layout:reset(WIDTH/3,HEIGHT/4, 10,10)
 	-- MM_W, MM_H = WIDTH*3/5, HEIGHT/2
 	-- -- draw mm buttons
 	sizLab = suit.Label("Board Size:", suit.layout:row(WIDTH/3,20))
 	sizBrd = suit.Slider(boardsize, suit.layout:row())
  suit.Label(math.floor(boardsize.value), suit.layout:row())
 	sizTLb = suit.Label("Team:", suit.layout:row(WIDTH/3,20))
 	sizTmb = suit.Checkbox(teamcb, suit.layout:row())
 	sizTmw = suit.Checkbox(teamcw, suit.layout:row())

 	if teamcb.checked then teamcw.checked = false end
 	if teamcw.checked then teamcb.checked = false end

 	startGameButt = suit.Button("Sttart Gaem!", suit.layout:row())

 	if startGameButt.hit then
 		print("GAEM STERT!",teamcb.checked,teamcw.checked,boardsize.value)
 		t = tak.new(tonumber(boardsize.value) or 5)
    instructions = "Excellent. Enter your commands in the box below.\n" ..
                   "Make moves with Portable Tak Notation."
 	end
end



function dg( )
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
              imgHgtScaleFactor = 0.75/(imgHgt/recSize)
              imgWidScaleFactor = 0.75/(imgWid/recSize)

              imgScaleFactor = math.min(imgHgtScaleFactor,
                                        imgWidScaleFactor)
              
              imgHgt,imgWid = imgHgt*imgHgtScaleFactor, imgWid*imgWidScaleFactor
              -- pad on top & side, and adjust for height of stack & scaled size
              xpos = xpos + centerPiece(imgWid,recSize)
              ypos = ypos + centerPiece(imgHgt,recSize) - (imgHgt/25*h)

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





function drawConsole()
	local conwid = logo:getHeight()
  -- first, draw the log
  suit.layout:reset(30,conwid+30, 5,5)
  gamerec = suit.Label(GPTN, leftop_flags, suit.layout:row(WIDTH/4,HEIGHT/3.2))
  local logrows = getLogRows(LOGROWS)
  shell_shell = suit.Label(logrows, leftop_flags, suit.layout:row())
  console = suit.Input(input, {id = "console"}, suit.layout:row(WIDTH/4,20))
  suit.layout:push(suit.layout:row())
  	suit.layout:padding(5)
  	suit.Button("Back", suit.layout:col(conwid/1.1,HEIGHT/21))
  	suit.Button("Next", suit.layout:col())
  suit.layout:pop()
  -- if this text is submitted, add it to the log and interpret the move
  if console.submitted then
    table.insert(log,input.text)
    interpret(input.text)
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
end


function drawLogo()
	local max_wid = WIDTH/3
	local w,h = logo:getWidth(), logo:getHeight()
	local ratio = max_wid/w
  love.graphics.setColor(255,255,255)
	love.graphics.draw(logo,  5,5,  0,  ratio,ratio)
	w,h = w*ratio, h*ratio
	love.graphics.printf(instructions,w,15,WIDTH-w,'left',0)
end


function interpret(command)
  local tinput = {}
  print("command received:")
  for word in string.gmatch(command, "%g+") do
    table.insert(tinput,word)
    print(word)
  end

  if not t:accept_user_ptn(tinput[1]) then cli_parse(tinput) end
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
    local dt = (cmdtable[2] or os.date("%H:%M:%S")) .. ".txt"
    file = io.open(dt,"a+")
    io.output(file)
    local game_ptn = t:game_to_ptn()
    io.write(game_ptn)
    io.close(file)
    instructions = "Game exported to " .. dt .. ".txt"
  elseif cmd == 'import' then
    -- TODO
    -- io.close(file)
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
      instructions = 'AI has been set to level ' .. cmdtable[2]
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
    -- Gamestate.switch(pause,true)
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