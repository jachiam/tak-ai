-- This script is used by the AlphaTakBot wrapper to run games on PlayTak.com! 

require 'tak_AI'

game = tak.new(tonumber(arg[2]))
takai = make_takarlo_01(15,true) --make_takai(3,true)

if arg[1] == 'True' then
	AI_vs_AI(game,takai,human)
else
	AI_vs_AI(game,human,takai)
end

print 'Game over'

local f = torch.DiskFile('interesting games/takai_playtak.txt','rw')
f:seekEnd()
f:writeString('----NEWGAME----\n\n' .. game:game_to_ptn() .. '\n\n')
if (arg[1]=='True' and game.winner == 1) or (arg[1]=='False' and game.winner==2) then
	f:writeString('---WIN---\n\n\n')
elseif game.winner ~= 0 then
	f:writeString('---LOSS---\n\n\n')
else
	f:writeString('---DRAW---\n\n\n')
end
f:close()
