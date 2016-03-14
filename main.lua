require 'tak_game'
utf8 = require('utf8')

function love.load()
  -- setup graphics
	love.graphics.setBackgroundColor(200,200,200)
  love.window.setMode(0,0) --defaults to size of desktop
  WindowSize = {love.graphics.getDimensions()} --WS[1]=width, WS[2]=height
  love.graphics.print('Please enter board size:')
  -- strings representing pieces and tiles
  -- TODO: pictures instead
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

  --setup keyboard input
  love.keyboard.setKeyRepeat(true)
  input = 'MAKE YOUR MOVE:'

  -- setup game
  boardsize = 5
  TAK = tak:__init(boardsize)

  math.randomseed( os.time() ) -- Don't call math.random() more than 1x/sec
  tak:generate_random_game(50)

  -- table of board positions
  PosTable = {}

end

function love.update(dt)
	-- if game_over then
	-- 	return
	-- end
end

function love.keypressed(key)
	if key == 'escape' then
    love.event.quit()
  end

  -- taken from love wiki: [[
  if key == "backspace" then
       -- get the byte offset to the last UTF-8 character in the string.
       local byteoffset = utf8.offset(input, -1)

       if byteoffset then
           -- remove the last UTF-8 character.
           -- string.sub operates on bytes rather than UTF-8 characters, so we couldn't do string.sub(text, 1, -2).
           input = string.sub(input, 1, byteoffset - 1)
       end
   end
   -- ]]
end

function love.draw()
  -- draw the board
  local recWid = WindowSize[1]/boardsize
  local recHgt = WindowSize[2]/boardsize
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
      local maxStack = 10 -- FIXME: not actual stack maximum
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
  drawTextBox()
end

function drawTextBox()
  love.graphics.setColor(255,255,255)
  textBoxCorner = {WindowSize[1]/3, WindowSize[2]*18/20}
  textBoxWidth = WindowSize[1]/3
  textBoxHeight = WindowSize[2]/20
  love.graphics.rectangle('fill',textBoxCorner[1],textBoxCorner[2],textBoxWidth,textBoxHeight)
  love.graphics.setColor(0,0,0)
  love.graphics.printf(input,textBoxCorner[1]+5,textBoxCorner[2]+5,1000,'left',0,2,2)
end

function love.textinput(t)
  input = input .. t
end
