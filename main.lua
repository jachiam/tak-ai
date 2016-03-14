require 'tak_game'

function love.load()
  success = love.window.setMode(0,0) --defaults to size of desktop
  WindowSize = {love.graphics.getDimensions()} --WS[1]=width, WS[2]=height
  boardsize = 5 -- FIXME this shouldn't be hard-coded
  TAK = tak:__init(boardsize)

  math.randomseed( os.time() ) -- Don't call math.random() more than 1x/sec
  tak:generate_random_game(50)

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
  -- table of board positions
  PosTable = {}

  Pieces = {{WTile, WWall, WCaps},
            {BTile, BWall, BCaps}}
end

function love.draw()
  -- draw the board
  for i=1,boardsize do
    PosTable[i] = {}
    for j=1,boardsize do
      -- color the space
      local thisSpaceColor = {}
      if i % 2 == 0 then
        if j % 2 == 0 then
          -- [0,0] [2,2] etc
          thisSpaceColor = {35,33,33}
        else
          -- [0,1] [0,3] etc
          thisSpaceColor = {225,222,222}
        end
      else
        if j % 2 == 0 then
          -- [1,0] [1,2] etc
          thisSpaceColor = {225,222,222}
        else
          -- [1,1] [1,3] etc
          thisSpaceColor = {35,33,33}
        end
      end
      love.graphics.setColor(thisSpaceColor)
      local recX = 10+i*WindowSize[1]/boardsize * WHRatio
      local recY = 10+j*WindowSize[2]/boardsize * WHRatio
      local recWid = WindowSize[1]/boardsize * WHRatio
      local recHgt = WindowSize[2]/boardsize * WHRatio

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
                xpos = xpos+imgWid/5
                ypos = ypos-imgHgt/4
              elseif piece == 2 then
                ypos = ypos-imgHgt/4
              else
                -- it's a normal piece.
              end
              -- adjust for height of stack
              ypos = ypos-(10*h)
              -- params: image, x,y position, radians, x,y scaling factors
              love.graphics.draw(img,xpos,ypos,0,WHRatio*0.8, WHRatio*0.8)
            else
              -- there is no piece of this type here.
            end
          end
        end
      end
    end
  end
end
