--require 'tak_test_suite'
require 'math'
require 'torch'
require 'nn'

--local mcts = {}

softmax = nn.SoftMax()

function rollout_policy(node,get_children)

	local function sign(x)
		--return x * (1/math.abs(x))
		if x == math.abs(x) then
			return 1
		else
			return -1
		end
	end

	local legal = node.legal_moves_by_ply[#node.legal_moves_by_ply]
	local policy = legal[3]:clone():fill(-1e10)
	local values = legal[3]:clone():fill(0)
	local children = {}
	local player = node:get_player()
	for i=1,legal[3]:nElement() do
		if legal[3][i] == 1 then
			local child = node:clone()
			child:make_move_by_idx(i)
			if get_children then table.insert(children,child) end
			values[i] = value_of_node(child,true,player)
			policy[i] = sign(values[i]) * math.log(math.abs(values[i]))
		end
	end
	policy = softmax:forward(policy):clone()
	return policy, children, legal, values
end

function sample_on_policy(p)
	return torch.multinomial(p,1)[1]
end

function simulate_game(node)
	local sim = node:clone()
	while not(sim.game_over) do
		local p = rollout_policy(sim)
		local a = sample_on_policy(p)
		sim:make_move_by_idx(a)
	end
	return sim
end

function action_values(node,time)
	local p, children, legal = rollout_policy(node,true)
	local action_values = torch.zeros(#legal)
	local start = os.time()
	local action_values = legal[3]:clone():fill(0):float()
	local num_visited = legal[3]:clone():fill(0):float()
	local player = node:get_player()

	local function value(s)
		if s.winner == player then
			return 1
		elseif s.winner == 0 then
			return 0
		else
			return -1
		end
	end

	while os.time() - start <= time do
		local a = sample_on_policy(p)
		if node:make_move_by_idx(a) then
			sim = simulate_game(node)
			node:undo()
			action_values[a] = action_values[a] + value(sim)
			num_visited[a] = num_visited[a] + 1
		end
	end

	gzero = torch.gt(num_visited,0)
	action_values[gzero] = action_values[gzero]:cdiv(num_visited[gzero])
	return action_values, num_visited, p, legal
end

--return mcts
