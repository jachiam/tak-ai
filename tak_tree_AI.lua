require 'tak_game'
require 'math'

-- nodes are tak games

function node_is_terminal(node)
	return not(node.win_type == 'NA')
end

function get_player_score(node,player)

	-- what if it's over?
	if node_is_terminal(node) then
		if node.winner == player then
			return 9999 - 5*node.ply
		elseif node.winner == 0 then
			return 0
		else
			return -9999
		end
	end

	islands = node.islands[player]

	strength = 0
	island_strengths = torch.zeros(#islands)
	for i=1,#islands do
		island_strengths[i] = (islands[i]:sum())^3.2
		strength = strength + island_strengths[i]
	end

	opponent = 3 - player
	stacks = {}
	stack_strengths = {}
	stack_strength_contrib = 0
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
						stack_strength = stack_strength*2
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
	p1_score = get_player_score(node,1)
	p2_score = get_player_score(node,2)
	score = p1_score - p2_score
	if maxplayeris == 2 then
		score = -score
	end
	return score
end

function children_of_node(node)
	legal = node.legal_moves_by_ply[#node.legal_moves_by_ply][2]
	children = {}
	for i=1,#legal do
		local copy = node:clone()
		copy:make_move_by_ptn(legal[i])
		table.insert(children,copy)
	end
	return children, legal
end

--TODO: figure out an implementation of MCTS to improve game speed
function alphabeta(node,depth,alpha,beta,maximizingPlayer,maxplayeris,mcts)
	if depth == 0 or node_is_terminal(node) then
		return value_of_node(node,maximizingPlayer,maxplayeris)
	end

	local children, legal = children_of_node(node)
	best_action = 0

	if maximizingPlayer then
		v = -1e9
		for i=1,#children do
			val = alphabeta(children[i],depth- 1, alpha, beta, false, maxplayeris,mcts)
			if val >= v then
				best_action = i
				v = val
			end
			alpha = math.max(alpha,v)
			if beta <= alpha then
				break
			end
		end
	else
		v = 1e9
		for i=1,#children do
			val = alphabeta(children[i],depth- 1, alpha, beta, true, maxplayeris,mcts)
			if val <= v then
				best_action = i
				v = val
			end
			beta = math.min(beta,v)
			if beta <= alpha then
				break
			end
		end
	end

	return v, legal[best_action]
end

function generate_game_by_alphabeta(node,levelp1,levelp2,num_moves,mcts,debug)
	for i=1,num_moves do
		if node.game_over then
			break
		end
		player = node:get_player()
		if player == 1 then
			depth = levelp1
		else
			depth = levelp2
		end
		print(depth)
		v, ptn = alphabeta(node,depth,-1e9,1e9,true,node:get_player(),mcts)
		node:make_move_by_ptn(ptn)
		print('Made move ' .. ptn)

		if debug then
			print ''
			print(node:game_to_ptn())
			print ''
		end
	end
end
