-- This script is used by the AlphaTakBot wrapper to run games on PlayTak.com! 

require 'tak_AI'

print(arg[3])

board_size = tonumber(arg[2])
game = tak.new(board_size)
if board_size < 5 then depth = 6 end
if board_size ==5 then depth = 5 end
if board_size >= 6 then depth = 4 end
takai = make_takai_05(depth,true)

if arg[1] == 'True' then
	AI_vs_AI(game,takai,human)
else
	AI_vs_AI(game,human,takai)
end

local f = torch.DiskFile('interesting games/takai_playtak3.txt','rw')
f:seekEnd()
f:writeString('----NEWGAME----\n')
if arg[1]=='True' then
	f:writeString('bot is white\n')
else
	f:writeString('bot is black\n')
end
f:writeString('opponent is ' .. arg[3] .. '\n\n')
f:writeString(game:game_to_ptn() .. '\n\n')
if (arg[1]=='True' and game.winner == 1) or (arg[1]=='False' and game.winner==2) then
	f:writeString('---WIN---\n\n\n')
elseif game.winner ~= 0 then
	f:writeString('---LOSS---\n\n\n')
else
	f:writeString('---DRAW---\n\n\n')
end
f:close()

print 'Game over!'
