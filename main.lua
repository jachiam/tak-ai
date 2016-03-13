require 'tak_game'

function love.load()
  WindowSize = {love.graphics.getDimensions()} --WS[1]=width, WS[2]=height
  boardsize = 5 -- FIXME this shouldn't be hard-coded
  TAK = tak:__init(boardsize)

  math.randomseed( os.time() ) -- Don't call math.random() more than 1x/sec

  -- strings representing pieces and tiles
  -- TODO: pictures instead
  WTile = "      \n[  W  ]\n      "
  BTile = "      \n[  B  ]\n      "
  WWall = "  __  \n | W | \n  __  "
  BWall = "  __  \n | B | \n  __  "
  WCaps = "  /\\  \n  |WW| \n  __  "
  BCaps = "  /\\  \n  |BB| \n  __  "

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
    --local height = tak.board:size(3)
    --STACK HEIGHT COMING SOON
    --for h=1,height do
        for team=1,2 do
          for piece=1,3 do
            --FIXME remember to fix the [1] below when adding stack height
            if tak.board[i][j][1][team][piece] ~= 0 then
              love.graphics.print(Pieces[team][piece], WindowSize[1]*(i/boardsize), WindowSize[2]*(j/boardsize))
            else
              love.graphics.print('__'..i..','..j..'__', WindowSize[1]*(i/boardsize), WindowSize[2]*(j/boardsize))
            end
          end
        end
    --end
    end
  end
end
