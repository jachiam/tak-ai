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


local function sign(x)
	if x == math.abs(x) then
		return 1
	end
	return -1
end

function debug_value_of_node(node,maxplayeris)
	local start_time = os.clock()
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



--------------------------------------------
-- AT4: "AlphaTak Experimental"

function score_function_AT4(node,player,maxplayeris)
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

		end
	end

	return stack_mul*stacks_strength + 2.5*island_strength + 3*node.player_flats[player] - node.player_pieces[player] - 2*node.player_caps[player] + 2*(node.island_max_dims[player]+is_player_turn)^1.2 + 0.5*node.island_len_sums[player]^1.05
end

function value_of_node4(node,maxplayeris)
	local p1_score = score_function_AT4(node,1,maxplayeris)
	local p2_score = score_function_AT4(node,2,maxplayeris)
	local score = p1_score - p2_score + (torch.uniform() - 0.5)
	if maxplayeris == 2 then
		score = -score
	end
	return score 
end


function normalized_value_of_node4(node,maxplayeris)
	local start_time = os.clock()
	local v = value_of_node4(node,maxplayeris)
	v = (sign(v)*(math.log(1+math.abs(v))/math.log(401)) + 1)/2
	value_of_node_time = value_of_node_time + (os.clock() - start_time)
	return v
end



--------------------------------------------
-- AT-freestyle: "AlphaTak Genetic"

function feature_vector_ATg(node,player,maxplayeris,as_table)

	-- winner?
	local player_has_won = 0
	if node.winner==player then player_has_won = 1 end

	-- island strength
	local island_strength = 0
	for j=1,#node.island_sums[player] do
		island_strength = island_strength + (node.island_sums[player][j])^1.2
	end

	local function control(x)
		if x==nil then return false end
		return x[player][1] == 1 or x[player][2] == 1 or x[player][3] == 1
	end

	local is_player_turn
	if player == node:get_player() then
		is_player_turn = 1
	else
		is_player_turn = 0
	end

	local explored = {}
	local function get_liberties(i)
		local liberties = 0
		if node.has_left[i] and not(explored[i-1]) then
			liberties = liberties + node.empty_squares[i-1]
			explored[i-1] = true
		end
		if node.has_down[i] and not(explored[i-node.size]) then
			liberties = liberties + node.empty_squares[i-node.size]
			explored[i-node.size] = true
		end
		if node.has_right[i] and not(explored[i+1]) then
			liberties = liberties + node.empty_squares[i+1]
			explored[i+1] = true
		end
		if node.has_up[i] and not(explored[i+node.size]) then
			liberties = liberties + node.empty_squares[i+node.size]
			explored[i+node.size] = true
		end
		return liberties
	end


	local function rough_influence_measure(i)
		local enemy_flats = 0
		local enemy_blocks = 0
		local enemy_caps = 0
		local self_flats = 0
		local self_blocks = 0
		local self_caps = 0
		if node.has_left[i] then
			enemy_flats = enemy_flats + node.board_top[i-1][3-player][1]
			enemy_blocks = enemy_blocks + node.board_top[i-1][3-player][2] + node.board_top[i-1][3-player][3]
			enemy_caps = enemy_caps + node.board_top[i-1][3-player][3]
			self_flats = self_flats + node.board_top[i-1][player][1]
			self_blocks = self_blocks + node.board_top[i-1][player][2] + node.board_top[i-1][player][3]
			self_caps = self_caps + node.board_top[i-1][player][3]
		end
		if node.has_down[i] then
			enemy_flats = enemy_flats + node.board_top[i-node.size][3-player][1]
			enemy_blocks = enemy_blocks + node.board_top[i-node.size][3-player][2] + node.board_top[i-node.size][3-player][3]
			enemy_caps = enemy_caps + node.board_top[i-node.size][3-player][3]
			self_flats = self_flats + node.board_top[i-node.size][player][1]
			self_blocks = self_blocks + node.board_top[i-node.size][player][2] + node.board_top[i-node.size][player][3]
			self_caps = self_caps + node.board_top[i-node.size][player][3]
		end
		if node.has_right[i] then
			enemy_flats = enemy_flats + node.board_top[i+1][3-player][1]
			enemy_blocks = enemy_blocks + node.board_top[i+1][3-player][2] + node.board_top[i+1][3-player][3]
			enemy_caps = enemy_caps + node.board_top[i+1][3-player][3]
			self_flats = self_flats + node.board_top[i+1][player][1]
			self_blocks = self_blocks + node.board_top[i+1][player][2] + node.board_top[i+1][player][3]
			self_caps = self_caps + node.board_top[i+1][player][3]
		end
		if node.has_up[i] then
			enemy_flats = enemy_flats + node.board_top[i+node.size][3-player][1]
			enemy_blocks = enemy_blocks + node.board_top[i+node.size][3-player][2] + node.board_top[i+node.size][3-player][3]
			enemy_caps = enemy_caps + node.board_top[i+node.size][3-player][3]
			self_flats = self_flats + node.board_top[i+node.size][player][1]
			self_blocks = self_blocks + node.board_top[i+node.size][player][2] + node.board_top[i+node.size][player][3]
			self_caps = self_caps + node.board_top[i+node.size][player][3]
		end
		return enemy_flats, enemy_blocks, enemy_caps, self_flats, self_blocks, self_caps
	end

	local stacks_strength = 0
	local sign = 1
	local l, total_liberties = 0, 0
	for i=1,node.board_size do
		l = 0
		if control(node.board_top[i]) then
			l = get_liberties(i)
			total_liberties = total_liberties + l
		end
		if control(node.board_top[i]) and node.heights[i] > 1 then
			local stack_strength = 0
			local reserves = 0
			local captives = 0

			for k=1, node.heights[i] do
				reserves =  reserves + node.board[i][k][player][1] 
				captives =  captives + node.board[i][k][3-player][1]
			end

			-- stack material value
			stack_strength = reserves - 0.5*captives

			local ef, eb, ec, sf, sb, sc = rough_influence_measure(i)

			local walltop, captop = 0,0
			if node.top_walls[i] then walltop = 1 end
			if node.board_top[i][player][3] == 1 then captop = 1 end

			-- stack tactical value
				-- bonus for being surrounded by liberties, own flats or cap
				-- penalty for being surrounded by enemy flats
				-- stronger penalty for being surrounded by enemy walls or cap, proportional to captives
			stack_strength = stack_strength + l + 1.5*(sf + sc) 
							- (1.5-is_player_turn)*ef 
							- (3-is_player_turn)*(eb+ec)*captives*(1-captop-walltop)
									
			if stack_strength > 0 then sign = 1 else sign = -1 end
			stacks_strength = stacks_strength + sign*(math.abs(stack_strength)^1.05)
		end
	end

	if as_table then
		return    {player_has_won, stacks_strength, total_liberties, island_strength, 
			  stacks_strength^2, total_liberties^2, island_strength^2, 
			  node.island_max_dims[player], node.island_len_sums[player], node.player_flats[player], 
			  node.island_max_dims[player]^2, node.island_len_sums[player]^2, node.player_flats[player]^2, 
			  node.player_pieces[player], node.player_caps[player], is_player_turn}
	else
		return    player_has_won, stacks_strength, total_liberties, island_strength, 
			  stacks_strength^2, total_liberties^2, island_strength^2, 
			  node.island_max_dims[player], node.island_len_sums[player], node.player_flats[player], 
			  node.island_max_dims[player]^2, node.island_len_sums[player]^2, node.player_flats[player]^2, 
			  node.player_pieces[player], node.player_caps[player], is_player_turn
	end
end

function generate_new_value_function(params)

	--[[local function score_function_ATg(node,player,maxplayeris)
		local v = feature_vector_ATg(node,player,maxplayeris)
		if v[1] == 1 then return 9999 - node.ply end
		local score = 0
		for j=2,#v do
			score = score + params[j-1]*v[j]
		end
		return score
	end]]

	local function score_function_ATg(node,player,maxplayeris)
		local pw, st, tl, is, st2, tl2, is2,
			md, ls, pf, md2, ls2, pf2,
			pp, pc, it = feature_vector_ATg(node,player,maxplayeris)
		if pw==1 then return 9999 - node.ply end
		return    params[1]*st 
			+ params[2]*tl
			+ params[3]*is
			+ params[4]*st2
			+ params[5]*tl2
			+ params[6]*is2
			+ params[7]*md
			+ params[8]*ls
			+ params[9]*pf
			+ params[10]*md2
			+ params[11]*ls2
			+ params[12]*pf2
			+ params[13]*pp
			+ params[14]*pc
			+ params[15]*it
	end

	local function value_of_node_g(node,maxplayeris)
		local p1_score = score_function_ATg(node,1,maxplayeris)
		local p2_score = score_function_ATg(node,2,maxplayeris)
		local score = p1_score - p2_score + (torch.uniform() - 0.5)
		if maxplayeris == 2 then
			score = -score
		end
		return score 
	end

	return value_of_node_g

end


