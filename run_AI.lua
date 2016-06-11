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

print 'Game over!'
