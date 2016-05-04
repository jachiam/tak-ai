require 'tak_AI_utils2'
require 'lib_AI'

------------------------------
-- TAKAI : A MINIMAX TAK AI --
------------------------------

function make_takai(depth,debug)
	return minimax_AI.new(depth,normalized_value_of_node,debug)
end

function make_takai_01(depth,debug)
	return minimax_AI.new(depth,normalized_value_of_node2,debug)
end

function make_takarlo_00(time,debug)
	return async_flat_mc_AI.new(time,true,default_rollout_policy.new(), 
				false,10,nil,4,{'tak_game','tak_AI_utils'},debug)
end

function make_takarlo_01(time,debug)
	return async_flat_mc_AI.new(time,true,
				epsilon_greedy_policy.new(0.5,normalized_value_of_node), 
				true,8,normalized_value_of_node,4,{'tak_game','tak_AI_utils'},debug)
end


-----------------------------------
-- FIGHT IT ON THE COMMAND LINE! --
-----------------------------------

function fight_takai(node,AI1,AI2)
	while not(node:is_terminal()) do
		AI1:move(node)
		print(node:print_tak_board(true))
		if node:is_terminal() then break end
		AI2:move(node)
		print(node:print_tak_board(true))
	end
end

