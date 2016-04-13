require 'tak_game'

--------------------------------------------------
--		TAK-AI UTILITY FUNCTIONS	--
--------------------------------------------------

function check_wins_in_one(node,player)
	local empty, top = node:get_empty_squares()	-- empty_squares also gives board_top, convenience hack
	local your_flats = top[{{},{},player,1}]:sum()
	local their_flats = top[{{},{},3 - player, 1}]:sum()
	local your_flat_wins
	if torch.any(empty) and node.player_pieces[player] == 1 and your_flats >= their_flats then
		your_flat_wins = 1
	else
		your_flat_wins = 0
	end
	empty = empty:float()
	local you, you_x, you_y, empty_x, empty_y, e_x_1, e_y_1
	local your_x_wins, your_y_wins
	you = top[{{},{},player,1}] + top[{{},{},player,3}]
	you_x = you:sum(1):squeeze()
	you_y = you:sum(2):squeeze()
	empty_x = empty:sum(1):squeeze()
	empty_y = empty:sum(2):squeeze()
	e_x_1 = torch.eq(empty_x,1):float()
	e_y_1 = torch.eq(empty_y,1):float()
	your_x_wins = torch.eq(torch.add(you_x,empty_x):cmul(e_x_1),node.size):sum()
	your_y_wins = torch.eq(torch.add(you_y,empty_y):cmul(e_y_1),node.size):sum()
	return your_x_wins + your_y_wins + your_flat_wins
end


-- heuristic score function for a player in tak
-- made by trial and error, with a spoonful of magic
function get_player_score(node,player)

	-- what if it's over?
	if node:is_terminal() then
		if node.winner == player then
			return 1e8 - node.ply
		else
			return 0
		end
	end

	local strength = 0
	local opponent = 3 - player

	-- check if you have the ability to win in one move,
	-- by the most obvious methods (road across col or row, flat win)
	your_wins = check_wins_in_one(node,player)

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
	islands = node.islands[player]

	island_strengths = torch.zeros(#islands)
	for i=1,#islands do
		island_strengths[i] = (islands[i]:sum())^4.2
		strength = strength + island_strengths[i]
	end

	local stacks = {}
	local stack_strengths = {}
	local stack_strength_contrib = 0
	for i=1,node.size do
		for j=1,node.size do
			h = node.heights[{i,j}]
			if h > 0 then
				if node.board[{i,j,h,player}]:sum() > 1 then
					stack = node.board[{i,j}]
					table.insert(stacks,stack)
					reserves = stack[{{},player,1}]:sum()
					--captives = stack[{{},opponent,1}]:sum()
					stack_strength = reserves^2.2 --+ captives^1.2
					one_below = (stack[{node.heights[{i,j}]-1,player,{}}]:sum() == 1)
					cap = (stack[{node.heights[{i,j}],player,3}] == 1)
					if one_below and cap then
						-- hard-capped stacks are strong
						stack_strength = stack_strength*1.2
					end
					table.insert(stack_strengths,stack_strength)
					stack_strength_contrib = stack_strength_contrib + stack_strength
				end
			end
		end
	end

	strength = strength + stack_strength_contrib
	strength = strength - (top_walls:sum())^3

	return strength
end

-- heuristic symmetric value function for tak, values between -1e8 and 1e8
function value_of_node(node,maxplayeris)
	local p1_score = get_player_score(node,1)
	local p2_score = get_player_score(node,2)
	local score = p1_score - p2_score
	if maxplayeris == 2 then
		score = -score
	end
	return score
end

-- normalized heuristic symmetric value function for tak, values between 0 and 1 (0: always lose, 1: always win)
function normalized_value_of_node(node,maxplayeris)
	local function sign(x)
		if x == math.abs(x) then
			return 1
		else
			return -1
		end
	end
	local v = value_of_node(node,maxplayeris)
	return (sign(v)*(math.log(1+math.abs(v))/math.log(1e8)) + 1)/2
end
