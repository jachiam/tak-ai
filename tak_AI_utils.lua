--[[ 
-----------------------------------
NOTES ON THE CONTENTS OF THIS FILE:
-----------------------------------

Contained here are the value functions for TakAI. There are, at present, two.

AT2 is a slightly stochastic formula, where the output varies randomly by something like a third of the value of a top flat. It rewards players for having flats on top of the board, and gives them some additional strength for connected regions of stones. 

AT3 is a variant on AT2 that takes into account some tactical considerations about stacks.

More interesting variants to come.

]]


require 'tak_game'

value_of_node_time = 0

----------------------------------------------------------
--	   TAK-AI UTILITY AND VALUE FUNCTIONS		--
----------------------------------------------------------


--------------------------------------------
-- AT0: Deterministic Debug Value Function

function score_function_AT0(node,player)
	-- what if it's over?
	if node:is_terminal() then
		if node.winner == player then
			return 400 - node.ply
		else
			return 0
		end
	end
	local strength = 0
	for j=1,#node.island_sums[player] do
		strength = strength + (node.island_sums[player][j])^1.1
	end

	return strength + 3*node.player_flats[player] + node.player_pieces[3-player] - 0.01*node.player_caps[player]
end


function value_of_node(node,maxplayeris)
	local p1_score = score_function_AT0(node,1)
	local p2_score = score_function_AT0(node,2)
	local score = p1_score - p2_score
	if maxplayeris == 2 then
		score = -score
	end
	return score 
end


function debug_value_of_node(node,maxplayeris)
	local start_time = os.clock()
	local function sign(x)
		if x == math.abs(x) then
			return 1
		else
			return -1
		end
	end
	local v = value_of_node(node,maxplayeris)
	v = (sign(v)*(math.log(1+math.abs(v))/math.log(401)) + 1)/2
	value_of_node_time = value_of_node_time + (os.clock() - start_time)
	return v
end




--------------------------------------------
-- AT2: "AlphaTak Classic"

function score_function_AT2(node,player)
	-- what if it's over?
	if node:is_terminal() then
		if node.winner == player then
			return 400 - node.ply
		else
			return 0
		end
	end
	local strength = 0
	for j=1,#node.island_sums[player] do
		strength = strength + (node.island_sums[player][j])^1.1
	end

	return strength + 3*node.player_flats[player] + node.player_pieces[3-player] - 0.01*node.player_caps[player] + 0.25*(torch.uniform() - 0.5)
end


function value_of_node2(node,maxplayeris)
	local p1_score = score_function_AT2(node,1)
	local p2_score = score_function_AT2(node,2)
	local score = p1_score - p2_score
	if maxplayeris == 2 then
		score = -score
	end
	return score 
end


function normalized_value_of_node2(node,maxplayeris)
	local start_time = os.clock()
	local function sign(x)
		if x == math.abs(x) then
			return 1
		else
			return -1
		end
	end
	local v = value_of_node2(node,maxplayeris)
	v = (sign(v)*(math.log(1+math.abs(v))/math.log(401)) + 1)/2
	value_of_node_time = value_of_node_time + (os.clock() - start_time)
	return v
end




--------------------------------------------
-- AT3: "AlphaTak Modern"

function score_function_AT3(node,player,maxplayeris)
	-- what if it's over?
	if node:is_terminal() then
		if node.winner == player then
			return 400 - node.ply
		else
			return 0
		end
	end
	local island_strength = 0
	for j=1,#node.island_sums[player] do
		island_strength = island_strength + (node.island_sums[player][j])^1.2
	end

	local function control(x)
		if x==nil then return false end
		return x[player][1] == 1 or x[player][2] == 1 or x[player][3] == 1
	end

	local stack_mul, is_player_turn
	if player == node:get_player() then
		stack_mul = 0.75
		is_player_turn = 1
	else
		stack_mul = 0.5
		is_player_turn = 0
	end

	local function rough_influence_measure(i)
		local enemy_flats = 0
		local enemy_blocks = 0
		local enemy_caps = 0
		local self_flats = 0
		local self_blocks = 0
		if node.has_left[i] then
			enemy_flats = enemy_flats + node.board_top[i-1][3-player][1]
			enemy_blocks = enemy_blocks + node.board_top[i-1][3-player][2] + node.board_top[i-1][3-player][3]
			enemy_caps = enemy_caps + node.board_top[i-1][3-player][3]
			self_flats = self_flats + node.board_top[i-1][player][1]
			self_blocks = self_blocks + node.board_top[i-1][player][2] + node.board_top[i-1][player][3]
		end
		if node.has_down[i] then
			enemy_flats = enemy_flats + node.board_top[i-node.size][3-player][1]
			enemy_blocks = enemy_blocks + node.board_top[i-node.size][3-player][2] + node.board_top[i-node.size][3-player][3]
			enemy_caps = enemy_caps + node.board_top[i-node.size][3-player][3]
			self_flats = self_flats + node.board_top[i-node.size][player][1]
			self_blocks = self_blocks + node.board_top[i-node.size][player][2] + node.board_top[i-node.size][player][3]
		end
		if node.has_right[i] then
			enemy_flats = enemy_flats + node.board_top[i+1][3-player][1]
			enemy_blocks = enemy_blocks + node.board_top[i+1][3-player][2] + node.board_top[i+1][3-player][3]
			enemy_caps = enemy_caps + node.board_top[i+1][3-player][3]
			self_flats = self_flats + node.board_top[i+1][player][1]
			self_blocks = self_blocks + node.board_top[i+1][player][2] + node.board_top[i+1][player][3]
		end
		if node.has_up[i] then
			enemy_flats = enemy_flats + node.board_top[i+node.size][3-player][1]
			enemy_blocks = enemy_blocks + node.board_top[i+node.size][3-player][2] + node.board_top[i+node.size][3-player][3]
			enemy_caps = enemy_caps + node.board_top[i+node.size][3-player][3]
			self_flats = self_flats + node.board_top[i+node.size][player][1]
			self_blocks = self_blocks + node.board_top[i+node.size][player][2] + node.board_top[i+node.size][player][3]
		end
		return enemy_flats, enemy_blocks, enemy_caps, self_flats, self_blocks
	end

	local stacks_strength = 0
	local sign = 1
	local position_strength = 0
	for i=1,node.size*node.size do
		if control(node.board_top[i]) and node.heights[i] > 1 then
			local stack_strength = 0
			local reserves = 0
			local captives = 0

			for k=1, node.heights[i] do
				reserves =  reserves + node.board[i][k][player][1] 
				captives =  captives + node.board[i][k][3-player][1]
			end

			stack_strength = reserves - 0.5*captives

			local ef, eb, ec, sf, sb = rough_influence_measure(i)

			local walltop, captop = 0,0
			if node.top_walls[i] then walltop = 1 end
			if node.board_top[i][player][3] == 1 then captop = 1 end

			stack_strength = stack_strength - (1.5-is_player_turn)*ef*(1-captop)
							+ 1.5*sf
							+ 2*sb
							- (3-is_player_turn)*eb*(1+ captives/2)*(1-captop)
							- (3-is_player_turn)*ec*captives*(1-captop)
							- captives*captop
										
			if stack_strength > 0 then sign = 1 else sign = -1 end
			stacks_strength = stacks_strength + sign*(math.abs(stack_strength)^1.05)/(1+eb+sb)

			position_strength = position_strength - (math.abs((node.size+1)/2 - node.x[i]) + math.abs((node.size+1)/2 - node.y[i]))
		end
	end

	local position_mul = 0.2

	return -position_mul*math.sqrt(-position_strength) + stack_mul*stacks_strength + 2.5*island_strength + 3*node.player_flats[player] - node.player_pieces[player] - 2*node.player_caps[player]
end


function value_of_node3(node,maxplayeris)
	local p1_score = score_function_AT3(node,1,maxplayeris)
	local p2_score = score_function_AT3(node,2,maxplayeris)
	local score = p1_score - p2_score + (torch.uniform() - 0.5)
	if maxplayeris == 2 then
		score = -score
	end
	return score 
end


function normalized_value_of_node3(node,maxplayeris)
	local start_time = os.clock()
	local function sign(x)
		if x == math.abs(x) then
			return 1
		else
			return -1
		end
	end
	local v = value_of_node3(node,maxplayeris)
	v = (sign(v)*(math.log(1+math.abs(v))/math.log(401)) + 1)/2
	value_of_node_time = value_of_node_time + (os.clock() - start_time)
	return v
end
