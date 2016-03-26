local utf8 = require 'utf8'
require 'tak_game'
require 'tak_tree_AI'

-- Configuration
function love.conf(t)
	t.title = "AlphaTak presents Tak-AI" -- The title of the window the game is in (string)
	t.version = "0.10.1"         -- The LÖVE version this game was made for (string)
	t.window.width = 600        -- we want our game to be long and thin.
	t.window.height = 800

	-- For Windows debugging
	t.console = true
end

function love.load()
	love.keyboard.setKeyRepeat( true )
	text0 = "Type away! -- "
	text = ''
	printx = 50
	printy = 50
	game = tak.new(4)
end
 
function love.textinput(t)
	if string.len(text) <=8 then
		text = text .. t
	end
end

function love.keypressed(key)
	if key == "backspace" then
		-- get the byte offset to the last UTF-8 character in the string.
		local byteoffset = utf8.offset(text, -1)
 
		if byteoffset then
			-- remove the last UTF-8 character.
			-- string.sub operates on bytes rather than UTF-8 characters, so we couldn't do string.sub(text, 1, -2).
			text = string.sub(text, 1, byteoffset - 1)
		end
	elseif key == "return" then
		game:accept_user_ptn(text)
		text = ''
	end
end

function love.mousepressed(x, y, button, istouch)
	if button == 1 then -- the primary button
		printx = x
		printy = y
		if in_button(x,y) then
			text0 = "hey woah nice job man!"
		end
	end
end

function in_button(x,y)
	return x <= 250 and x >= 200 and y<= 350 and y>= 300
end

function love.draw()
	love.graphics.print(game:game_to_ptn(), 400, 300)
	love.graphics.printf(text0,0,0,60)
	love.graphics.printf(text,0, 30, 80)--love.graphics.getWidth())
	love.graphics.print("tak tak tak " .. printx .. " " .. printy,printx,printy)
end
