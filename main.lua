require 'tak_game'

function love.load()
  success = love.window.setMode(0,0) --defaults to size of desktop
  WindowSize = {love.graphics.getDimensions()} --WS[1]=width, WS[2]=height
  boardsize = 5 -- FIXME this shouldn't be hard-coded
  TAK = tak:__init(boardsize)

  math.randomseed( os.time() ) -- Don't call math.random() more than 1x/sec

  -- strings representing pieces and tiles
  -- TODO: pictures instead
  WTile = "img/wtile.png"
  BTile = "img/btile.png"
  WWall = "img/wwall.png"
  BWall = "img/bwall.png"
  WCaps = "img/wcaps.png"
  BCaps = "img/bcaps.png"
  -- for drawing board
  WHRatio = 0.7

  Pieces = {{WTile, WWall, WCaps},
            {BTile, BWall, BCaps}}
end

function love.draw()

  --[[ draw the board
  for i=1,boardsize do

  end ]]--

  -- loop over EVERY ONE of the FIVE DIMENSIONS
  -- [vortex noises]
  for i=1,boardsize do
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

      love.graphics.rectangle('fill', recX, recY, recWid, recHgt)
      --local height = tak.board:size(3)
      --STACK HEIGHT COMING SOON
      --for h=1,height do
          for team=1,2 do
            for piece=1,3 do
              --FIXME remember to fix the [1] below when adding stack height
              if tak.board[i][j][1][team][piece] ~= 0 then
                love.graphics.print(Pieces[team][piece], WindowSize[1]*(i/boardsize)-(i*0.5/boardsize), WindowSize[2]*(j/boardsize))
              else
                -- not really an 'else'. we don't need to draw nothingness
              end
            end
          end
        --end
    end
  end
end
