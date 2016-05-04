--[[ 
-----------------------------------
NOTES ON THE CONTENTS OF THIS FILE:
-----------------------------------

Contained here are the value functions for TakAI. There are, at present, two.

The first one is extremely slow because of tensor operations. It will take more than 50% of the time in the search. At depth 3, it takes ~5 seconds; at depth 4, it takes ~45 seconds; at higher depths it's prohibitively expensive.

Go figure: matrix overhead is bad. Learn something new every day.

AT1 is a completely deterministic formula that awards points polynomially in island bulk, penalizes walls, and checks for a few easy wins as a substitute for looking further ahead.

The second one is much faster, but is currently still being actively developed. This is AT2.

AT2 is a slightly stochastic formula, where the output varies randomly by something like a third of the value of a top flat. It rewards players for having flats on top of the board, and gives them some additional strength for connected regions of stones. 

More interesting variants to come.

]]


require 'tak_game'

value_of_node_time = 0

----------------------------------------------------------
--	OLD TAK-AI UTILITY AND VALUE FUNCTIONS		--
----------------------------------------------------------

function check_wins_in_one(node,empty,top,player)
	local your_flats = top[{{},{},player,1}]:sum()
	local their_flats = top[{{},{},3 - player, 1}]:sum()
	local your_flat_wins
	if torch.any(empty) and node.player_pieces[player] == 1 and your_flats >= their_flats then
		your_flat_wins = 1
	else
		your_flat_wins = 0
	end
	local you, you_x, you_y, empty_x, empty_y, e_x_1, e_y_1
	local your_x_wins, your_y_wins
	you = top[{{},{},player,1}] + top[{{},{},player,3}]
	you_x = you:sum(1):squeeze()
	you_y = you:sum(2):squeeze()
	empty_x = empty:sum(1):squeeze()
	empty_y = empty:sum(2):squeeze()
	e_x_1 = torch.eq(empty_x,1)
	e_y_1 = torch.eq(empty_y,1)
	your_x_wins = torch.eq(you_x:add(empty_x):cmul(e_x_1),node.size):sum()
	your_y_wins = torch.eq(you_y:add(empty_y):cmul(e_y_1),node.size):sum()
	return your_x_wins + your_y_wins + your_flat_wins
end


-- heuristic score function for a player in tak
-- this one kinda sucks
function score_function_AT1(node,empty,top,player)

	-- what if it's over?
	if node:is_terminal() then
		if node.winner == player then
			return 1e8 - node.ply
		else
			return 0
		end
	end

	local strength = 0

	-- check if you have the ability to win in one move,
	-- by the most obvious methods (road across col or row, flat win)
	your_wins = check_wins_in_one(node,empty,top,player)

	-- if it is your turn and you can win in one move, very good!
	if your_wins > 0 and node:get_player() == player then
		return 1e8 - node.ply - 1
	else
		-- if you can threaten more than one win at once, very strong.
		strength = strength + your_wins^6
	end

	-- heuristic strength evaluation:
	-- bulky islands (contiguous regions of pieces you control) are powerful,
	-- stacks are good too (but not quite as good). 
	-- encapsulates adage, 'place if you can, move if you must.'
	-- also, walls are somewhat weak; they should only be deployed as necessary.

	local island_sums = node.island_sums[player]
	for i=1,#island_sums do
		strength = strength + island_sums[i]^4.2
	end

	-- wall penalty
	local top_walls = top[{{},{},player,2}]

	strength = strength - (top_walls:sum())^3

	return strength
end

-- heuristic symmetric value function for tak, values between -1e8 and 1e8
function value_of_node(node,maxplayeris,get_player_score)
	local empty, top = node:get_empty_squares()
	empty = torch.ByteTensor(empty)
	top = torch.ByteTensor(top)
	local p1_score = get_player_score(node,empty,top,1)
	local p2_score = get_player_score(node,empty,top,2)
	local score = p1_score - p2_score
	if maxplayeris == 2 then
		score = -score
	end
	return score
end

-- normalized heuristic symmetric value function for tak, values between 0 and 1 (0: always lose, 1: always win)
function normalized_value_of_node(node,maxplayeris)
	local start_time = os.clock()
	local function sign(x)
		if x == math.abs(x) then
			return 1
		else
			return -1
		end
	end
	local v = value_of_node(node,maxplayeris,score_function_AT1)
	--return (sign(v)*(math.log(1+math.abs(v))/math.log(1e8)) + 1)/2
	v = (sign(v)*(math.log(1+math.abs(v))/math.log(1e8)) + 1)/2
	value_of_node_time = value_of_node_time + (os.clock() - start_time)
	return v
end




function score_function_AT2(node,top,player)
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
		strength = strength + (node.island_sums[player][j])^1.8
	end

	return 3*node.player_flats[player] + node.player_pieces[3-player] - 0.01*node.player_caps[player] + (torch.uniform() - 0.5)
end


function value_of_node2(node,maxplayeris)
	local p1_score = score_function_AT2(node,top,1)
	local p2_score = score_function_AT2(node,top,2)
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
