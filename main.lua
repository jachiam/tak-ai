-- remaking GUI
-- TODO: sassy comments

-- deps
local TAK = require('tak_game')
local TAI = require ('tak_tree_AI')
local suit = require('suit') -- GUI
local utf8 = require('utf8') -- for text input

-- gamestates
local menu = {}
local game = {}
local pause= {}

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

	-- origin x,y , padding z,a
    suit.layout:reset(30,logo:getHeight()+30, 5,5)

 	-- draw console 
 	-- -- first, draw the log
 	logrows = getLogRows(LOGROWS)
 	shell_shell = suit.Button(logrows, {align="left",valign="top"}, suit.layout:row(WIDTH/4,HEIGHT/2))
 	-- suit.layout:push(suit.layout:row())
	console = suit.Input(input, {id = "console"}, suit.layout:row(WIDTH/4,15))
	-- suit.layout:pop()
 	-- -- if this text is submitted, add it to the log and interpret the move
 	if console.submitted then
 		table.insert(log,input.text)
 		interpret(input.text)
 		input.text = ""
 	end

 	-- draw main menu
 	suit.layout:reset(WIDTH/3,HEIGHT/4, 10,10)
 	mm = suit.Label("TESTIN' SHIT, DAWG", suit.layout:row(WIDTH/3,HEIGHT/3))
    -- -- if the button was entered, play a sound
    -- if state.entered then love.audio.play(snd) end

    -- -- if the button was pressed, take damage
    -- if state.hit then print("Butt!") end

    -- -- put an input box below the button
    -- -- the cell of the input box has the same size as the cell above
    -- -- if the input cell is submitted, print the text
    -- if suit.Input(input, suit.layout:row()).submitted then
    --     print(input.text)
    -- end

    -- -- put a button below the input box
    -- -- the width of the cell will be the same as above, the height will be 40 px
    -- if suit.Button("Hover?", suit.layout:row(nil,40)).hovered then
    --     -- if the button is hovered, show two other buttons
    --     -- this will shift all other ui elements down

    --     -- put a button below the previous button
    --     -- the cell height will be 30 px
    --     -- the label of the button will be aligned top left
    --     suit.Button("You can see", {align='left', valign='top'}, suit.layout:row(nil,30))

    --     -- put a button below the previous button
    --     -- the cell size will be the same as the one above
    --     -- the label will be aligned bottom right
    --     suit.Button("...but you can't touch!", {align='right', valign='bottom'},
    --                                            suit.layout:row())
    -- end

    -- -- put a checkbox below the button
    -- -- the size will be the same as above
    -- -- (NOTE: height depends on whether "Hover?" is hovered)
    -- -- the label "Check?" will be aligned right
    -- suit.Checkbox(chk, {align='right'}, suit.layout:row())

    -- -- put a nested layout
    -- -- the size of the cell will be as big as the cell above or as big as the
    -- -- nested content, whichever is bigger
    -- suit.layout:push(suit.layout:row())

    --     -- change cell padding to 3 pixels in either direction
    --     suit.layout:padding(3)

    --     -- put a slider in the cell
    --     -- the inner cell will be 160 px wide and 20 px high
    --     suit.Slider(slider, suit.layout:col(160, 20))

    --     -- put a label that shows the slider value to the right of the slider
    --     -- the width of the label will be 40 px
    --     suit.Label(("%.02f"):format(slider.value), suit.layout:col(40))

    -- -- close the nested layout
    -- suit.layout:pop()

    -- -- put an image button below the nested cell
    -- -- the size of the cell will be 200 by 100 px,
    -- --      but the image may be bigger or smaller
    -- -- the button shows the image `normal' when the mouse is outside the image
    -- --      or above a transparent pixel
    -- -- the button shows the image `hovered` if the mouse is above an opaque pixel
    -- --      of the image `normal'
    -- -- the button shows the image `active` if the mouse is above an opaque pixel
    -- --      of the image `normal' and the mouse button is pressed
    -- suit.ImageButton(normal, {hovered = hovered, active = active}, suit.layout:row(200,100))

    -- -- if the checkbox is checked, display a precomputed layout
    -- if chk.checked then
    --     -- the precomputed layout will be 3 rows below each other
    --     -- the origin of the layout will be at (400,100)
    --     -- the minimal height of the layout will be 300 px
    --     rows = suit.layout:rows{pos = {400,100}, min_height = 300,
    --         {200, 30},    -- the first cell will measure 200 by 30 px
    --         {30, 'fill'}, -- the second cell will be 30 px wide and fill the
    --                       -- remaining vertical space between the other cells
    --         {200, 30},    -- the third cell will be 200 by 30 px
    --     }

    --     -- the first cell will contain a witty label
    --     -- the label will be aligned left
    --     -- the font of the label will be smaller than the usual font
    --     suit.Label("You uncovered the secret!", {align="left", font = smallerFont},
    --                                             rows.cell(1))

    --     -- the third cell will contain a label that shows the value of the slider
    --     suit.Label(slider.value, {align='left'}, rows.cell(3))

    --     -- the second cell will show a slider
    --     -- the slider will operate on the same data as the first slider
    --     -- the slider will be vertical instead of horizontal
    --     -- the id of the slider will be 'slider two'. this is necessary, because
    --     --     the two sliders should not both react to UI events
    --     suit.Slider(slider, {vertical = true, id = 'slider two'}, rows.cell(2))
    -- end
end

function love.draw()
	drawLogo()
    -- draw the gui
    suit.draw()
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
			print (#log, #log-max, i, log[i])
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