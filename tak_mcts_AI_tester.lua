
--local lanes = require "lanes".configure()
local lanes = require("lanes").configure()
require 'tak_mcts_AI'

t:play_game_from_ptn(data('game.txt'))

function test_of_sims(node,time)

	local function simtask(ptn_game)
		local game = tak.new(3,true):play_game_from_ptn(ptn_game,true)
		return game--:game_to_ptn()--'yo'--simulate_game(game):game_to_ptn()
	end

	print 'hey'

	local f = lanes.gen("*",{required={"torch","tak_game"--[[,"tak_mcts_AI"]]}}, simtask)

	local a = f(node:game_to_ptn())
	local b = f(node:game_to_ptn())

	print(a[1],b[1])
end
