require 'tak_game'
require 'math'

-- nodes are tak games

function node_is_terminal(node)
	return not(node.win_type == 'NA')
end

function check_wins_in_one(node,player)
	local empty, top = node:get_empty_squares()	-- empty_squares also gives board_top, convenience hack
	local your_flats = top[{{},{},player,1}]:sum()
	local their_flats = top[{{},{},3 - player, 1}]:sum()
	if torch.any(empty) and node.player_pieces[player] == 1 and your_flats >= their_flats then
		your_flat_wins = 1
	else
		your_flat_wins = 0
	end
	empty = empty:float()
	local you, them, you_x, you_y, empty_x, empty_y, e_x_1, e_y_1
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

function get_player_score(node,player)

	-- what if it's over?
	if node_is_terminal(node) then
		if node.winner == player then
			return 1e8 - 5*node.ply
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
		return 1e8
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
					captives = stack[{{},opponent,1}]:sum()
					stack_strength = reserves^2.2 + captives^1.2
					one_below = (stack[{node.heights[{i,j}]-1,player,{}}]:sum() == 1)
					cap = (stack[{node.heights[{i,j}],player,3}] == 1)
					if one_below and cap then
						-- hard-capped stacks are super strong
						stack_strength = stack_strength*3
					end
					table.insert(stack_strengths,stack_strength)
					stack_strength_contrib = stack_strength_contrib + stack_strength
				end
			end
		end
	end

	strength = strength + stack_strength_contrib

	strength = strength - (top_walls:sum())^3

	return strength, islands, island_strengths, stacks, stack_strengths
end

function value_of_node(node,maximizingPlayer,maxplayeris)
	local p1_score = get_player_score(node,1)
	local p2_score = get_player_score(node,2)
	local score = p1_score - p2_score
	if maxplayeris == 2 then
		score = -score
	end
	return score
end

function children_of_node(node)
	local legal = node.legal_moves_by_ply[#node.legal_moves_by_ply][2]
	-- slightly hacky lua black magic to reduce number of table rehashes, saves some time
	local children = {nil,nil,nil,nil,nil}
	for i=1,#legal do
		local copy = node:clone()
		copy:make_move_by_ptn(legal[i])
		table.insert(children,copy)
	end
	return children, legal
end

function alphabeta(node,depth,alpha,beta,maximizingPlayer,maxplayeris)
	if depth == 0 or node_is_terminal(node) then
		return value_of_node(node,maximizingPlayer,maxplayeris), nil, nil, nil, 1
	end

	local children, legal = children_of_node(node)
	local best_action = 0
	local v = 0
	local a,b = alpha,beta

	local moves_considered = {}
	local num_leaves = 0

	if maximizingPlayer then
		v = -1e9
		for i=1,#children do
			val, _, _, _, nl = alphabeta(children[i],depth- 1, a, b, false, maxplayeris)
			table.insert(moves_considered,{legal[i],val})
			num_leaves = num_leaves + nl
			if val > v then
				best_action = i
				v = val
			end
			a = math.max(a,v)
			if b <= a then
				break
			end
		end
	else
		v = 1e9
		for i=1,#children do
			val, _, _, _, nl = alphabeta(children[i],depth- 1, a, b, true, maxplayeris)
			table.insert(moves_considered,{legal[i],val})
			num_leaves = num_leaves + nl
			if val < v then
				best_action = i
				v = val
			end
			b = math.min(b,v)
			if b <= a then
				break
			end
		end
	end

	return v, legal[best_action], legal, moves_considered, num_leaves
end

function generate_game_by_alphabeta(node,levelp1,levelp2,num_moves,debug)
	for i=1,num_moves do
		if node.game_over then
			break
		end
		local player = node:get_player()
		if player == 1 then
			depth = levelp1
		else
			depth = levelp2
		end
		AI_move(node,depth,debug)

		if debug then
			print ''
			print(node:game_to_ptn())
			print ''
		end
	end
end

function AI_move(node,AI_level,debug)
	v, ptn, _, mc, nl = alphabeta(node,AI_level,-1e9,1e9,true,node:get_player())
	if debug then
		print('AI move: ' .. ptn .. ', Value: ' .. v .. ', Num Leaves: ' .. nl)
	end
	node:make_move_by_ptn(ptn)
	return mc
end

function against_AI(node,AI_level,debug)
	level = AI_level or 2
	all_moves_considered_by_ply = {}
	while node.win_type == 'NA' do
		if debug then
			print(node:game_to_ptn())
			print ''
		end
		ptn = io.read()
		if ptn == 'quit' then
			break
		end
		valid = node:accept_user_ptn(ptn)
		if valid and not(node.game_over) then	-- if user move is valid and executes and didn't end the game
			mc = AI_move(node,AI_level,debug)
			all_moves_considered_by_ply[node.ply] = mc	-- prior to ply, these moves were considered
		end
	end
	print('Game Over: ' .. node.outstr)
	return mc
end
