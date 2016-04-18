--require 'tak_test_suite'
require 'math'
require 'torch'
require 'nn'

--local mcts = {}

softmax = nn.SoftMax()

function selection_policy(node,get_children)

	local function sign(x)
		if x == math.abs(x) then
			return 1
		else
			return -1
		end
	end

	local legal = node.legal_moves_by_ply[#node.legal_moves_by_ply]
	local policy = legal[3]:clone():fill(0)--:fill(-1e10)
	local values = legal[3]:clone():fill(0)
	local children = {}
	local player = node:get_player()
	for i=1,legal[3]:nElement() do
		if legal[3][i] == 1 then
			local child = node:clone()
			child:make_move_by_idx(i)
			if get_children then table.insert(children,child) end
			values[i] = value_of_node(child,true,player)
			policy[i] = sign(values[i]) * math.log(1 + math.abs(values[i]))
		end
	end
	policy[torch.ne(legal[3],0)] = softmax:forward(policy[torch.ne(legal[3],0)]):clone()
	return policy, children, legal, values
end

function rollout_policy(node,get_children)
	local legal = node.legal_moves_by_ply[#node.legal_moves_by_ply]
	return legal[3]:clone()
end

function sample_on_policy(p)
	return torch.multinomial(p,1)[1]
end

function simulate_game(node,smart,epsilon,noclone)
	local sim
	if noclone then
		sim = node
	else
		sim = node:clone()
	end
	local eps = epsilon or 0.5
	local p, a
	while not(sim.game_over) do
		if smart and torch.uniform() > eps then
			AI_move(sim,1,false)
		else
			p = rollout_policy(sim)
			a = sample_on_policy(p)
			sim:make_move_by_idx(a)
		end
	end
	return sim
end

function partial_playout_game(node,smart,epsilon,noclone,k)
	local sim
	if noclone then
		sim = node
	else
		sim = node:clone()
	end
	local eps = epsilon or 0.5
	local p, a, i
	for i=1,k do
		if smart and torch.uniform() > eps then
			AI_move(sim,1,false)
		else
			p = rollout_policy(sim)
			a = sample_on_policy(p)
			sim:make_move_by_idx(a)
		end
	end
	return sim
end

---------------------------------------------
-- FOR USE IN THE ASYNC ACTION VALUE FUNCTION
--
function means(av,nv)
	local visited = torch.gt(nv,0)
	local mean_av = torch.zeros(nv:size())
	mean_av[visited] = torch.cdiv(av[visited],nv[visited])
	mean_av[torch.eq(nv,0)] = -1e10
	return mean_av, visited
end

function UCB_action(av,nv,legal_moves,check,losing_moves)
	if nv:sum() == 0 then
		return torch.multinomial(legal_moves:double(),1)[1]
	end
	local mean_av = means(av,nv)
	local UCB_term = torch.zeros(nv:size())
	UCB_term[legal_moves] = 2*math.log(nv:sum()) + 1e-16
	UCB_term[legal_moves] = UCB_term[legal_moves]:cdiv(nv[legal_moves])
	UCB_term[legal_moves]:sqrt()
	local av = mean_av + UCB_term
	if check then
		av[torch.eq(losing_moves,1)] = -1e10
	end
	local _, a = torch.max(av,1)
	return a[1]
end

function select_and_playout_move(node,av,nv,legal_moves,check,winning_moves,losing_moves,smart,partial,k)
	local copy = node:clone()
	local a = UCB_action(av,nv,legal_moves,check,losing_moves)
	local player = copy:get_player()
	
	local v, sim
	local runflag = false
	local guarantee_win = false
	local guarantee_lose = false

	if nv[a] == 0 and check then
		local copy2 = copy:clone()	-- ugly, I know, but fast clones don't support undo.
		if copy2:make_move_by_idx(a) then
			v = alphabeta(copy2,1,-1e9,1e9,false,player)
			if v > 9e7 then
				guarantee_win = true
			elseif v < -9e7 then
				guarantee_lose = true
			end
		end
	end
	-- if this move doesn't have a guarantee, start simulating games starting at it.
	v = 0
	local guarantee = winning_moves[a] == 1 or losing_moves[a] == 1 or guarantee_win or guarantee_lose
	if not(guarantee) then
		if copy:make_move_by_idx(a) then
			if not(partial) then
				sim = simulate_game(copy,smart,nil,true)
				if sim.winner == player then
					v = 1
				elseif sim.winner == 0 then
					v = 0.5
				else
					v = 0
				end
			else
				sim = partial_playout_game(copy,smart,nil,true,k-1)
				v = approximate_value(sim,player)
			end
			runflag = true
		end
	end

	return runflag, a, v, guarantee_win, guarantee_lose
end

function approximate_value(node,player)
	local function sign(x)
		if x == math.abs(x) then
			return 1
		else
			return -1
		end
	end
	local v = value_of_node(node,player)
	return (sign(v)*(math.log(1+math.abs(v))/math.log(1e8)) + 1)/2
end
--
---------------------------------------------

-- if UCB flag is true, then this uses an upper confidence bound policy to select nodes to evaluate,
-- otherwise it uses a heuristic policy.
-- if smart flag is true, uses epsilon-greedy alpha-beta minimax (of depth 1) in rollout policy.
-- if check flag is true, checks using alpha-beta minimax (of depth 2) whether moves guarantee defeat/victory in 2.
function action_values(node,time,UCB,smart,check)
	local p, legal
	if not(UCB) then
		p,_,legal = selection_policy(node,true)
	else
		legal = node.legal_moves_by_ply[#node.legal_moves_by_ply]
	end
	local raw_action_values = torch.zeros(legal[3]:size())
	local action_values = torch.zeros(legal[3]:size())
	local num_visited = torch.zeros(legal[3]:size())
	local player = node:get_player()
	local legal_moves = legal[3]:byte()
	local losing_moves = num_visited:clone()
	local winning_moves = num_visited:clone()

	local function value(s)
		if s.winner == player then
			return 1
		elseif s.winner == 0 then
			return 0.5
		else
			return 0
		end
	end

	local function means(av,nv)
		local visited = torch.gt(nv,0)
		local mean_av = torch.zeros(nv:size())
		mean_av[visited] = torch.cdiv(av[visited],nv[visited])
		mean_av[torch.eq(nv,0)] = -1e10
		return mean_av, visited
	end

	local function UCB_action(av,nv)
		if nv:sum() == 0 then
			local p = torch.div(legal[3],legal[3]:sum())
			return torch.multinomial(p,1)[1]
		end
		local mean_av = means(av,nv)
		local UCB_term = torch.zeros(nv:size())
		UCB_term[legal_moves] = 2*math.log(nv:sum()) + 1e-16
		UCB_term[legal_moves] = UCB_term[legal_moves]:cdiv(nv[legal_moves])
		UCB_term[legal_moves]:sqrt()
		local av = mean_av + UCB_term
		if check then
			av[torch.eq(losing_moves,1)] = -1e10
		end
		local _, a = torch.max(av,1)
		return a[1]
	end

	local a, v, sim
	local start = os.time()
	while os.time() - start <= time do
		if not(UCB) then 
			a = sample_on_policy(p)
		else
			a = UCB_action(raw_action_values,num_visited)
		end
		-- check to see if this action guarantees a victory or defeat
		if num_visited[a] == 0 and check then
			if node:make_move_by_idx(a) then
				v = alphabeta(node,1,-1e9,1e9,false,player)
				if v > 9e7 then
					winning_moves[a] = 1
					raw_action_values[a] = 1
				elseif v < -9e7 then
					losing_moves[a] = 1
					raw_action_values[a] = 0
				end
				node:undo()
				num_visited[a] = num_visited[a] + 1
			end
		end
		-- if this move doesn't have a guarantee, start simulating games starting at it.
		if not(winning_moves[a] == 1 or losing_moves[a] == 1) then
			if node:make_move_by_idx(a) then
				sim = simulate_game(node,smart)
				node:undo()
				raw_action_values[a] = raw_action_values[a] + value(sim)
				num_visited[a] = num_visited[a] + 1
			end
		end
	end

	action_values = means(raw_action_values,num_visited)
	return action_values, num_visited, raw_action_values, winning_moves, losing_moves, p, legal
end


-- For benchmarking the multithreaded version
function action_values2(node,time,check,smart)
	local legal = node.legal_moves_by_ply[#node.legal_moves_by_ply]
	local raw_action_values = torch.zeros(legal[3]:size())
	local action_values = torch.zeros(legal[3]:size())
	local num_visited = torch.zeros(legal[3]:size())
	local player = node:get_player()
	local legal_moves = legal[3]:byte()
	local losing_moves = num_visited:clone()
	local winning_moves = num_visited:clone()

	local function value(s)
		if s.winner == player then
			return 1
		elseif s.winner == 0 then
			return 0.5
		else
			return 0
		end
	end

	local a, v, sim
	local start = os.time()
	local flag, a, s, gw, gl
	while os.time() - start <= time do
		flag, a, s, gw, gl = select_and_playout_move(node,
						raw_action_values:clone(),
						num_visited:clone(),
						legal_moves:clone(),
						check,
						winning_moves:clone(),
						losing_moves:clone(),
						smart)

		if gw then
			winning_moves[a] = 1
			raw_action_values[a] = 1
			num_visited[a] = 1
		elseif gl then
			losing_moves[a] = 1
			raw_action_values[a] = 0
			num_visited[a] = 1
		elseif flag then
			raw_action_values[a] = raw_action_values[a] + value(s)
			num_visited[a] = num_visited[a] + 1
		end
	end

	action_values = means(raw_action_values,num_visited)
	return action_values, num_visited, raw_action_values, winning_moves, losing_moves, legal
end



function flat_monte_carlo_move(node,time,debug,UCB,smart,check)
	if node.game_over then
		if debug then print 'Game is over.' end
		return false
	end
	local start_time = os.time()
	local av, nv, rav, wm, lm = action_values(node,time,UCB,smart,check)
	local _, a = torch.max(av,1)
	node:make_move_by_idx(a[1])
	local elapsed_time = os.time() - start_time
	if debug then
		print('MC move: ' .. node.move2ptn[a[1]] .. ', Value: ' .. av[a[1]] .. ', Num Simulations: ' .. nv:sum() .. ', Time Elapsed: ' .. elapsed_time)
	end
	return av, nv, rav, wm, lm
end

--return mcts
