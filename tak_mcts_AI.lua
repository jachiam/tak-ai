--require 'tak_test_suite'
require 'math'
require 'torch'
require 'nn'

--local mcts = {}

softmax = nn.SoftMax()

function selection_policy(node,get_children)

	local function sign(x)
		--return x * (1/math.abs(x))
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

function simulate_game(node,smart,epsilon)
	local sim = node:clone()
	local eps = epsilon or 0.1
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

-- if UCB flag is true, then this uses an upper confidence bound policy to select nodes to evaluate,
-- otherwise it uses a heuristic policy.
function action_values(node,time,UCB,smart)
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

	local function value(s)
		if s.winner == player then
			return 1
		elseif s.winner == 0 then
			return 0
		else
			return -1
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
		local _, a = torch.max(av,1)
		return a[1]
	end

	local a
	local start = os.time()
	while os.time() - start <= time do
		if not(UCB) then 
			a = sample_on_policy(p)
		else
			a = UCB_action(raw_action_values,num_visited)
		end
		if node:make_move_by_idx(a) then
			sim = simulate_game(node,smart)
			node:undo()
			raw_action_values[a] = raw_action_values[a] + value(sim)
			num_visited[a] = num_visited[a] + 1
		end
	end

	action_values = means(raw_action_values,num_visited)
	return action_values, num_visited, raw_action_values, p, legal
end

function monte_carlo_move(node,time,debug,UCB,smart)
	local start_time = os.time()
	local av, nv, rav = action_values(node,time,UCB,smart)
	local _, a = torch.max(av,1)
	node:make_move_by_idx(a[1])
	local elapsed_time = os.time() - start_time
	if debug then
		print('MC move: ' .. node.move2ptn[a[1]] .. ', Value: ' .. av[a[1]] .. ', Num Simulations: ' .. nv:sum() .. ', Time Elapsed: ' .. elapsed_time)
	end
	return av, nv, rav
end

--return mcts
