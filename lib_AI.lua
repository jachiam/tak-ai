require 'torch'


--------------------------------------------------
--		GAME OBJECT			--
--------------------------------------------------

-- this is the template for a game that is compatible with this library

local game_node = torch.class('game_node')

function game_node:__init()
	self.winner = 0
	self.ply = 0
	self.i2n = {1}	-- index to move notation
	self.history = {}
end

function game_node:is_terminal()
	if self.winner == 0 then
		return false
	else
		return true
	end
end

function game_node:get_i2n(i)
	return self.i2n[i]
end

function game_node:get_history()
	return history
end

-- accepts actions in either index or notation form
-- flag argument lets you do special things: for example, ignore certain calculations 
-- at the last step of minimax
function game_node:make_move(a, flag)	
	self.history[#self.history] = a
	self.ply = self.ply + 1
	if self.ply == 10 then self.winner = 1 end
	return true
end

function game_node:undo()
	self.history[#self.history] = nil
	self.ply = self.ply - 1
end

function game_node:clone()
	return game_node.new()
end

function game_node:get_player()
	return self.ply % 2 + 1
end

function game_node:get_children()
	local legal = {1}
	local children = {game_node.new()}
	return children, legal
end

function game_node:get_legal_move_mask(as_boolean)
	local legal_move_mask = torch.ones(1)
	if as_boolean then
		return legal_move_mask:byte()
	else
		return legal_move_mask
	end
end

function game_node:get_legal_move_table()
	return {1}
end

--------------------------------------------------
--		AI OBJECTS			--
--------------------------------------------------

-- the basic template for an AI interface

local AI = torch.class('AI')

function AI:move(node)
	return false
end


-------------------------------------
-- AI CLASS WRAPPER FOR HUMAN USER --
-------------------------------------

local human = torch.class('human','AI')

function human:move(node)
	local valid = false
	local a
	while not(valid) do
		a = io.read()
		valid = node:make_move(a)
	end
end


---------------------------
-- RANDOM AGENT AI CLASS --
---------------------------

local random_AI = torch.class('random_AI','AI')

function random_AI:move(node)
	local legal_move_mask = node:get_legal_move_mask()
	local a = torch.multinomial(legal_move_mask,1)[1]
	node:make_move(a)
	return true
end


-----------------------------------------------------
-- MINIMAX AI CLASS ver 1: Alpha-Beta Pruning Only --
-----------------------------------------------------

local minimax_AI = torch.class('minimax_AI','AI')

-- minimax_AI needs a value function from (node, player) pair to real scalar value
function minimax_AI:__init(depth,value,debug)
	self.depth = depth
	self.value = value
	self.debug = debug
	self.max_time = 0
	self.total_time = 0
	self.average_time = 0
	self.num_moves = 0
end

function minimax_AI:move(node)
	if node:is_terminal() then
		if self.debug then print 'Game is over.' end
		return false
	end
	local start_time = os.clock()
	local v, a, nl = minimax_move2(node,self.depth,self.value)	-- minimax_move2 is 3x faster
	local time_elapsed = os.clock() - start_time
	self.max_time = math.max(self.max_time,time_elapsed)
	self.total_time = self.total_time + time_elapsed
	self.num_moves = self.num_moves + 1
	self.average_time = self.total_time/self.num_moves
	if self.debug then
		print('AI move: ' .. a .. ', Value: ' .. v .. ', Num Leaves: ' .. nl .. ', Time taken: ' .. time_elapsed
			.. '\nMax Time: ' .. self.max_time 
			.. ', Total Time: ' .. self.total_time
			.. ', Average Time: ' .. self.average_time)
	end
	node:make_move(a)
	return true
end


-------------------------------------------------------------------
-- MINIMAX AI CLASS ver 2: Alpha-Beta Pruning + Killer Heuristic --
-------------------------------------------------------------------

local killer_minimax_AI = torch.class('killer_minimax_AI','AI')

-- minimax_AI needs a value function from (node, player) pair to real scalar value
function killer_minimax_AI:__init(depth,value,debug)
	self.depth = depth
	self.value = value
	self.debug = debug
	self.killer_moves = {}
	self.max_time = 0
	self.total_time = 0
	self.average_time = 0
	self.num_moves = 0
end

function killer_minimax_AI:move(node)
	if node:is_terminal() then
		if self.debug then print 'Game is over.' end
		return false
	end
	local start_time = os.clock()
	local v, a, nl, km = minimax_move3(node,self.depth,self.value,self.killer_moves)
	local time_elapsed = os.clock() - start_time
	self.killer_moves = {}
	for i=self.depth-2,1,-1 do
		self.killer_moves[i+2] = km[i]
	end
	
	self.max_time = math.max(self.max_time,time_elapsed)
	self.total_time = self.total_time + time_elapsed
	self.num_moves = self.num_moves + 1
	self.average_time = self.total_time/self.num_moves
	if self.debug then
		print('AI move: ' .. a .. ', Value: ' .. v .. ', Num Leaves: ' .. nl .. ', Time taken: ' .. time_elapsed
			.. '\nMax Time: ' .. self.max_time 
			.. ', Total Time: ' .. self.total_time
			.. ', Average Time: ' .. self.average_time)
		--print(km)
	end
	node:make_move(a)
	return true
end


-----------------------------------------------------------------------------------------
-- MINIMAX AI CLASS ver 3: Alpha-Beta Pruning + Killer Heuristic + Iterative Deepening --
-----------------------------------------------------------------------------------------

local iterative_killer_minimax_AI = torch.class('iterative_killer_minimax_AI','AI')

-- minimax_AI needs a value function from (node, player) pair to real scalar value
function iterative_killer_minimax_AI:__init(depth,value,shuffle,debug)
	self.depth = depth
	self.value = value
	self.shuffle = shuffle
	self.debug = debug
	self.max_time = 0
	self.total_time = 0
	self.average_time = 0
	self.num_moves = 0
end

function iterative_killer_minimax_AI:move(node)
	if node:is_terminal() then
		if self.debug then print 'Game is over.' end
		return false
	end
	local start_time = os.clock()
	local v, a, nl = correct_iterative_killer_search(node,self.depth,self.value,self.shuffle,1,self.debug)
	local time_elapsed = os.clock() - start_time
	self.max_time = math.max(self.max_time,time_elapsed)
	self.total_time = self.total_time + time_elapsed
	self.num_moves = self.num_moves + 1
	self.average_time = self.total_time/self.num_moves
	if self.debug then
		print('AI move: ' .. a .. ', Value: ' .. v .. ', Num Leaves: ' .. nl .. ', Time taken: ' .. time_elapsed
			.. '\nMax Time: ' .. self.max_time 
			.. ', Total Time: ' .. self.total_time
			.. ', Average Time: ' .. self.average_time)
	end
	node:make_move(a)
	return true
end



-------------------------------
-- FLAT MONTE CARLO AI CLASS --
-------------------------------

local flat_mc_AI = torch.class('flat_mc_AI','AI')

-- arguments to initialize flat_mc_AI:
--	time 	:	how long can it spend thinking per turn?		 (default: 60s)
--	check   :	do a one-move-lookahead for each move to see if it guarantees a loss (default:true)
--	rollout_policy: a function that takes a game node and returns an action. (default: random)
--	partial :	should it do full rollouts or partial rollouts?		 (default: false)
--	depth	:	if partial rollouts, to what depth?			 (default: 10)
--	value   :	a function that takes a game node and returns its value	 (default: 1 = win, 0.5 draw, else 0)
function flat_mc_AI:__init(time,check,rollout_policy,partial,depth,value,debug)
	self.time = time or 60
	if check == nil then self.check = true else self.check = check end
	self.rollout_policy = rollout_policy or default_rollout_policy.new()
	self.partial = partial or false
	self.depth = depth or 10
	self.value = value or default_value
	self.debug = debug
end

function flat_mc_AI:move(node)
	if node:is_terminal() then
		if self.debug then print 'Game is over.' end
		return false
	end
	
	local start_time = os.clock()
	local av, nv, rav, wm, lm = flat_mc_action_values(node,self.time,self.check,
							self.rollout_policy,
							self.partial,
							self.depth,
							self.value)

	local _, a = torch.max(av,1)
	local elapsed_time = os.clock() - start_time
	local n = node:get_i2n(a[1])
	if self.debug then
		print('MC move: ' .. n .. ', Value: ' .. av[a[1]] .. ', Num Simulations: ' .. nv:sum() .. ', Time taken: ' .. elapsed_time)
		for j=1,nv:numel() do
			if nv[j] > 0 then
				print(node:get_i2n(j) .. '\t av:\t' .. av[j] .. ', nv:\t' .. nv[j] .. ', wm: ' .. wm[j] .. ', lm: ' .. lm[j])
			end
		end
	end
	node:make_move(a[1])
	return true
end


-------------------------------------
-- ASYNC FLAT MONTE CARLO AI CLASS --
-------------------------------------

local async_flat_mc_AI = torch.class('async_flat_mc_AI','AI')

-- arguments to initialize async_flat_mc_AI:
--	time 	:	how long can it spend thinking per turn?		 (default: 60s)
--	check   :	do a one-move-lookahead for each move to see if it guarantees a loss (default:true)
--	rollout_policy: a function that takes a game node and returns an action. (default: random)
--	partial :	should it do full rollouts or partial rollouts?		 (default: false)
--	depth	:	if partial rollouts, to what depth?			 (default: 10)
--	value   :	a function that takes a game node and returns its value	 (default: 1 = win, 0.5 draw, else 0)
--	nthreads:	how many threads in threadpool?				 (default: 4)
--	deps	:	table of dependencies (string for filename or rock name) (default: empty table)
function async_flat_mc_AI:__init(time,check,rollout_policy,partial,depth,value,nthreads,deps,debug)
	self.time = time or 60
	if check == nil then self.check = true else self.check = check end
	self.rollout_policy = rollout_policy or default_rollout_policy.new()
	self.partial = partial or false
	self.depth = depth or 10
	self.value = value or default_value
	self.nthreads = nthreads or 4
	self.deps = deps or {}
	self.debug = debug

	self.pool = make_threadpool(self.nthreads,self.deps)
end

function async_flat_mc_AI:move(node)
	if node:is_terminal() then
		if self.debug then print 'Game is over.' end
		return false
	end
	
	local start_time = os.clock()
	local av, nv, rav, wm, lm = async_flat_mc_action_values(self.pool,node,self.time,self.check,
							self.rollout_policy,
							self.partial,
							self.depth,
							self.value)

	local _, a = torch.max(av,1)
	local elapsed_time = os.clock() - start_time
	local n = node:get_i2n(a[1])
	if self.debug then
		print('Async MC move: ' .. n .. ', Value: ' .. av[a[1]] .. ', Num Simulations: ' .. nv:sum() .. ', CPU time taken: ' .. elapsed_time)
		for j=1,nv:numel() do
			if nv[j] > 0 then
				print(node:get_i2n(j) .. '\t av:\t' .. av[j] .. ', nv:\t' .. nv[j] .. ', wm: ' .. wm[j] .. ', lm: ' .. lm[j])
			end
		end
	end
	node:make_move(a[1])
	return true
end

--------------------------------------------------
--		AI vs. AI			--
--------------------------------------------------

function AI_vs_AI(node,AI1,AI2,debug)
	while not(node:is_terminal()) do
		AI1:move(node)
		if debug then print(node:game_state_string()) end
		if node:is_terminal() then break end
		AI2:move(node)
		if debug then print(node:game_state_string()) end
	end
	return node:game_state_string()
end



--------------------------------------------------
--	DEFAULT VALUE FUNCTION			--
--------------------------------------------------

function default_value(node,player)
	if node.winner == player then
		return 1	-- win
	elseif node.winner == 0 then
		return 0.5	-- draw
	else
		return 0	-- loss
	end
end

function discounted_default_value(node,player)
	if node.winner == player then
		return 1 - 1e-16*node.ply	-- win
	elseif node.winner == 0 then
		return 0.5	-- draw
	else
		return 0	-- loss
	end
end

--------------------------------------------------
--	ROLLOUT POLICY OBJECTS			--
--------------------------------------------------

local policy = torch.class('policy')

function policy:act(node)
	local legal_move_table = node:get_legal_move_table()
	local action = torch.random(#legal_move_table) 
	return legal_move_table[action] 
	--local legal_move_mask = node:get_legal_move_mask()
	--return torch.multinomial(legal_move_mask,1)[1]
end

local default_rollout_policy = torch.class('default_rollout_policy','policy')

function default_rollout_policy:act(node)
	return policy.act(self,node)
end

local epsilon_greedy_policy = torch.class('epsilon_greedy_policy','policy')

function epsilon_greedy_policy:__init(epsilon,value,depth)
	self.depth = depth or 1
	self.epsilon = epsilon or 0.5
	self.value = value or default_value
end

function epsilon_greedy_policy:act(node)
	if torch.uniform() > self.epsilon then
		local _, a = minimax_move2(node,self.depth,self.value)
		return a
	else
		return policy.act(self,node)
	end
end

--------------------------------------------------
--	ALGORITHMS AND UTILITY FUNCTIONS	--
--------------------------------------------------

-----------------------------------
-- MINIMAX WITH ALPHA-BETA PRUNING:
-- arguments: 
--	node : game state 
--		node must have the following methods:
--			node:is_terminal()	returns boolean
--			node:get_children()	returns table of child nodes, table of legal moves 
--						that lead to those children 
--			node:make_move(a)	'a' is in same notation as table of legal moves
--
--	depth: how deep to search
--	alpha: should be -1/0 at first call
--	beta: should be 1/0 at first call
-- 	maximizingPlayer: boolean that indicates whether at this level we are 
--			  minning (false) or maxing (true)
--	maxplayeris: 1 or 2, helps us keep track of which player actually 
--		     called the alpha-beta recursive minimax function in the first place
--	value_of_node: a function from nodes and maxplayer id to values

-- this is the slower implementation, but could probably be parallelized safely
function alphabeta(node,depth,alpha,beta,maximizingPlayer,maxplayeris,value_of_node)
	if depth == 0 or node:is_terminal() then
		return value_of_node(node,maxplayeris), nil, 1
	end

	local children, legal = node:get_children()
	local best_action = 0
	local v = 0
	local a,b = alpha,beta
	local num_leaves = 0

	if maximizingPlayer then
		v = -1/0
		for i=1,#children do
			val, _, nl = alphabeta(children[i],depth- 1, a, b, false, maxplayeris,value_of_node)
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
		v = 1/0
		for i=1,#children do
			val, _, nl = alphabeta(children[i],depth- 1, a, b, true, maxplayeris,value_of_node)
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

	return v, legal[best_action], num_leaves
end

-- this is the faster implementation, cannot be parallelized
function alphabeta2(node,depth,alpha,beta,maximizingPlayer,maxplayeris,value_of_node)
	if depth == 0 or node:is_terminal() then
		return value_of_node(node,maxplayeris), nil, 1
	end

	local legal = node:get_legal_move_table()
	local best_action = 0
	local v = 0
	local a,b = alpha,beta
	local num_leaves, nl = 0, 0

	if maximizingPlayer then
		v = -1/0
		for i,move in pairs(legal) do
			node:make_move(move, depth==1)
			val, _, nl = alphabeta2(node,depth- 1, a, b, false, maxplayeris,value_of_node)
			num_leaves = num_leaves + nl
			node:undo()
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
		v = 1/0
		for i,move in pairs(legal) do
			node:make_move(move, depth==1)
			val, _, nl = alphabeta2(node,depth- 1, a, b, true, maxplayeris,value_of_node)
			num_leaves = num_leaves + nl
			node:undo()
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

	return v, legal[best_action], num_leaves
end

-- alphabeta with killer heuristic
function alphabeta3(node,depth,alpha,beta,maximizingPlayer,maxplayeris,value_of_node,killer_moves)
	if depth == 0 or node:is_terminal() then
		return value_of_node(node,maxplayeris), nil, 1
	end

	local legal = node:get_legal_move_table()
	local best_action = 0
	local v = 0
	local a,b = alpha,beta
	local num_leaves, nl = 0, 0

	if not(killer_moves[depth]==nil) then
		for i=1,#legal do
			if legal[i] == killer_moves[depth] then
				legal[1], legal[i] = legal[i], legal[1]
			end
		end
	end

	if maximizingPlayer then
		v = -1/0
		for i=1,#legal do
			local move = legal[i]
			node:make_move(move, depth==1)
			val, _, nl = alphabeta3(node,depth- 1, a, b, false, maxplayeris,value_of_node,killer_moves)
			num_leaves = num_leaves + nl
			node:undo()
			if val > v then
				best_action = i
				v = val
			end
			a = math.max(a,v)
			if b <= a then
				killer_moves[depth] = move
				break
			end
		end
	else
		v = 1/0
		for i=1,#legal do
			local move = legal[i]
			node:make_move(move, depth==1)
			val, _, nl = alphabeta3(node,depth- 1, a, b, true, maxplayeris,value_of_node,killer_moves)
			num_leaves = num_leaves + nl
			node:undo()
			if val < v then
				best_action = i
				v = val
			end
			b = math.min(b,v)
			if b <= a then
				killer_moves[depth] = move
				break
			end
		end
	end

	return v, legal[best_action], num_leaves
end

function shuffle_moves(legal)
	local n = #legal
	while n > 2 do
		local k = math.random(n)
		legal[n], legal[k] = legal[k], legal[n]
		n = n - 1
	end
end

-- alphabeta with killer heuristic, returning principal variation and other stats, including game theoretic value of node
function alphabeta4(node,maxdepth,depth,alpha,beta,maximizingPlayer,maxplayeris,value_of_node,killer_moves,cutlog,shuffle)
	if depth == maxdepth or node:is_terminal() then
		local gtv = 0.5
		if node.winner == maxplayeris then gtv = 1
		elseif node.winner == 3 - maxplayeris then gtv = 0 end
		return value_of_node(node,maxplayeris), nil, 1, {}, 0, gtv
	end

	local legal = node:get_legal_move_table()
	local best_action = 0
	local v,gtv = 0,0.5
	local a,b = alpha,beta
	local num_leaves, nl = 0, 0
	local val,gtval, vari, pvari, nc
	local pnc = 1

	if shuffle then shuffle_moves(legal) end

	if not(killer_moves[depth]==nil) then
		for i=1,#legal do
			if legal[i] == killer_moves[depth] then
				legal[1], legal[i] = legal[i], legal[1]
			end
		end
	end

	if maximizingPlayer then
		v = -1/0
		for i=1,#legal do
			local move = legal[i]
			node:make_move(move, depth==maxdepth-1)
			val, _, nl, vari, nc, gtval = alphabeta4(node,maxdepth,depth+1, a, b, false, maxplayeris,value_of_node,killer_moves,cutlog,shuffle)
			pnc = pnc + nc
			num_leaves = num_leaves + nl
			node:undo()
			if val > v then
				best_action = i
				v = val
				gtv = gtval
				pvari = vari
				pvari[depth] = move
			end
			a = math.max(a,v)
			if b <= a then
				killer_moves[depth] = move
				if not(cutlog[depth]) then cutlog[depth] = 0 end
				cutlog[depth] = cutlog[depth] + 1
				break
			end
		end
	else
		v = 1/0
		for i=1,#legal do
			local move = legal[i]
			node:make_move(move, depth==maxdepth-1)
			val, _, nl, vari, nc, gtval = alphabeta4(node,maxdepth,depth+1, a, b, true, maxplayeris,value_of_node,killer_moves,cutlog,shuffle)
			pnc = pnc + nc
			num_leaves = num_leaves + nl
			node:undo()
			if val < v then
				best_action = i
				v = val
				gtv = gtval
				pvari = vari
				pvari[depth] = move
			end
			b = math.min(b,v)
			if b <= a then
				killer_moves[depth] = move
				if not(cutlog[depth]) then cutlog[depth] = 0 end
				cutlog[depth] = cutlog[depth] + 1
				break
			end
		end
	end

	return v, legal[best_action], num_leaves, pvari, pnc, gtv
end



-- convenience method
function minimax_move(node,depth,value)
	return alphabeta(node,depth,-1/0,1/0,true,node:get_player(),value)
end

-- convenience method
function minimax_move2(node,depth,value)
	return alphabeta2(node,depth,-1/0,1/0,true,node:get_player(),value)
end

-- killer heuristic
function minimax_move3(node,depth,value,killer_moves)
	local killer_moves = killer_moves or {}
	local v,a,nl = alphabeta3(node,depth,-1/0,1/0,true,node:get_player(),value,killer_moves)
	return v,a,nl,killer_moves
end

-- killer heuristic + return principal variation
function minimax_move4(node,depth,value,variation)
	local killer_moves = variation or {}
	local v,a,nl,pv = alphabeta4(node,depth,0,-1/0,1/0,true,node:get_player(),value,killer_moves,{})
	return v,a,nl,killer_moves,pv
end


-- killer heuristic + iterative deepening, but correctly implemented
function correct_iterative_killer_search(node,maxdepth,value_of_node,shuffle,increment,debug)
	local v,a,nl,km,pv,nc,gtv
	local pv = {}
	local nl_prev = 1
	for i=1,maxdepth,increment do
		local cutlog = {}
		v,a,nl_cur,pv,nc,gtv = alphabeta4(node,i,0,-1/0,1/0,true,node:get_player(),value_of_node,pv,cutlog,shuffle)
		if debug then
			print('------Search Depth ' .. i .. '------')
			print('Value: ' .. v .. ', Action: ' .. a .. ', Leaves Searched: ' .. nl_cur)
			if not(gtv == 0.5) then print('Game Theoretic Value: ' .. gtv) end
			print('Approximate Branching Factor: ' .. nl_cur / nl_prev)
			print('Interior Node Count: ' .. nc)
			print('Principal Variation:')
			print(pv)
			--print('Cut Log:')
			--print(cutlog)
		end
		nl_prev = nl_cur
		if gtv == 1 or gtv == 0 then
			break
		end
	end
	return v,a,nl_cur,pv
end


---------------------------------------------
-- UTILITY FUNCTIONS FOR FLAT MONTE CARLO AI:
--
-- notes:
--	in what follows, extensive use is made of 'rav', 'av', and 'nv' as arguments.
--	'av' refers to 'action_values,' a vector with as many entries as legal actions in the game, 
--	which says how good each action is. Specifically, entries of 'av' must be between 0 and 1.
--	The entries in 'av' are averaged over many trials.
--	'rav' refers to 'raw_action_values', a vector which is just the total sum of action_values 
--	from the many trials. 
--	'nv' is 'num_visits', the number of trials which have started with each action being taken.
--	they are related by 'av' = 'rav' / 'nv'

function means(rav,nv)
	local visited = torch.gt(nv,0)
	local av = torch.zeros(nv:size())
	av[visited] = torch.cdiv(rav[visited],nv[visited])
	av[torch.eq(nv,0)] = -1e10	-- states not visited are assigned large, negative values; can't be -inf, though
	return av, visited
end

-- notes for UCB_action:
-- arguments:
--	legal_moves must be a 'byteTensor' with as many entries as moves, where the entry is 1 if the move is legal.
--	check is a boolean which indicates whether or not we are looking for moves that guarantee lead to losses.
--	losing_moves is a tensor with as many entries as moves, where the entry is 1 if the move guarantees a loss.
--
-- what this function does:
--	returns argmax_i av[i] + sqrt(2 ln(N) / nv[i]), where N = sum_i nv[i]
--
--	this is a selection policy for trading off exploration/exploitation in one-armed bandits 
--	with nice regret bounds
function UCB_action(rav,nv,legal_moves,check,losing_moves)
	if nv:sum() == 0 then
		-- if we haven't tried anything, pick something random.
		return torch.multinomial(legal_moves:double(),1)[1]
	end
	local av = means(rav,nv)
	local UCB_term = torch.zeros(nv:size())
	UCB_term[legal_moves] = 2*math.log(nv:sum()) + 1e-16	-- the 1e-16 avoids a 0/0 error when nv:sum() = 1.
	UCB_term[legal_moves] = UCB_term[legal_moves]:cdiv(nv[legal_moves])
	UCB_term[legal_moves]:sqrt()
	av = av + UCB_term
	if check then
		av[torch.eq(losing_moves,1)] = -1/0
	end
	local _, a = torch.max(av,1)
	return a[1]
end

function rollout(node,rollout_policy,partial,depth,noclone)
	local sim
	if noclone then sim = node else sim = node:clone() end

	if not(partial) then
		while not(sim:is_terminal()) do
			sim:make_move(rollout_policy:act(sim))
		end
	else
		for i=1,depth do
			if not(sim:is_terminal()) then sim:make_move(rollout_policy:act(sim)) end
		end
	end

	return sim
end

-- notes for select_and_playout_move:
--	winning_moves and losing_moves have entry 1 if the move guarantees a win / loss, otherwise 0
--	this function picks a move using UCB action, and then simulates a game starting at it

function select_and_playout_move(node, rav, nv,
				legal_moves,
				check,
				winning_moves,
				losing_moves,
				rollout_policy,
				partial,
				depth,
				value,
				noclone)
	local rollout_policy = rollout_policy or default_rollout_policy.new()
	local depth = depth or 10
	local value = value or default_value
	local copy 
	if not(noclone) then
		copy = node:clone()
	else
		copy = node
	end
	local a = UCB_action(rav,nv,legal_moves,check,losing_moves)
	local player = copy:get_player()
	
	local v, sim
	local runflag = false
	local guarantee_win = false
	local guarantee_lose = false

	local guarantee = winning_moves[a] == 1 or losing_moves[a] == 1
	if not(guarantee) then
		if copy:make_move(a) then
			if nv[a] == 0 and check then
				v = alphabeta2(copy,1,-1/0,1/0,false,player,default_value)
				if v == 1 then
					guarantee_win = true
				elseif v == 0 then
					guarantee_lose = true
				end
			end
			if not(guarantee_win or guarantee_lose) then
				sim = rollout(copy,rollout_policy,partial,depth-1,true)
				v = value(sim,player)
				runflag = true
			end
		end
	end

	return runflag, a, v, guarantee_win, guarantee_lose
end

-- serial version of flat monte carlo action value calculation
function flat_mc_action_values(node,time,check,
			rollout_policy,
			partial,
			depth,
			value)
	local legal_moves = node:get_legal_move_mask(true)
	local raw_action_values = torch.zeros(legal_moves:size())
	local num_visited = torch.zeros(legal_moves:size())
	local player = node:get_player()
	local losing_moves = num_visited:clone()
	local winning_moves = num_visited:clone()

	local a, v, sim
	local start = os.time()
	local flag, a, s, gw, gl
	while os.time() - start <= time do
		flag, a, v, gw, gl = select_and_playout_move(node,
						raw_action_values:clone(),
						num_visited:clone(),
						legal_moves:clone(),
						check,
						winning_moves:clone(),
						losing_moves:clone(),
						rollout_policy,
						partial,
						depth,
						value)

		if gw then
			winning_moves[a] = 1
			raw_action_values[a] = 1
			num_visited[a] = 1
		elseif gl then
			losing_moves[a] = 1
			raw_action_values[a] = 0
			num_visited[a] = 1
		elseif flag then
			raw_action_values[a] = raw_action_values[a] + v
			num_visited[a] = num_visited[a] + 1
		end
	end

	local action_values = means(raw_action_values,num_visited)
	return action_values, num_visited, raw_action_values, winning_moves, losing_moves
end

-- parallel version of flat monte carlo action value calculation
-- threadpool is first argument now
function async_flat_mc_action_values(pool,node,time,check,
			rollout_policy,
			partial,
			depth,
			value)

	local legal_moves = node:get_legal_move_mask(true)
	local raw_action_values = torch.zeros(legal_moves:size())
	local num_visited = torch.zeros(legal_moves:size())
	local player = node:get_player()
	local losing_moves = num_visited:clone()
	local winning_moves = num_visited:clone()

	local a, v, sim
	local start = os.time()
	local flag, a, s, gw, gl

	local jobcount = 0
	local jobid = 0
	local start_time

	local function async_eval()
	   
		-- fill up the queue as much as we can
		-- this will not block
		while pool:acceptsjob() and os.time() - start_time <= time do

			jobid = jobid + 1
		
			pool:addjob(
				function(jobid)
					local flag, a, val, gw, gl = select_and_playout_move(node,
									raw_action_values,--:clone(),
									num_visited,--:clone(),
									legal_moves,--:clone(),
									check,
									winning_moves,--:clone(),
									losing_moves,--:clone(),
									rollout_policy,
									partial,
									depth,
									value,
									true)

					return flag,a, val, gw, gl
				end,

				function(flag,a,val,gw,gl)

					if gw then
						winning_moves[a] = 1
						raw_action_values[a] = 1
						num_visited[a] = 1
						return
					elseif gl then
						losing_moves[a] = 1
						raw_action_values[a] = 0
						num_visited[a] = 1
						return
					end

					if flag then
						raw_action_values[a] = raw_action_values[a] + val
						num_visited[a] = num_visited[a] + 1
					end
				end,

				jobid
				)
		end

		   -- is there still something to do?
		if pool:hasjob() then
			pool:dojob() -- yes? do it!
			if pool:haserror() then -- check for errors
				pool:synchronize() -- finish everything and throw error
			end
			jobcount = jobcount + 1
		end
	end

	start_time = os.time()
	start_time_CPU = os.clock()
	while os.time() - start_time <= time do
		async_eval()
		--if winning_moves:sum() > 0 then break end
	end
	
	local real_jobtime = os.clock() - start_time_CPU
	print('Total CPU time: ' .. real_jobtime .. ', Estimated Speedup Over Realtime: ' .. real_jobtime / time)

	action_values = means(raw_action_values,num_visited)
	return action_values, num_visited, raw_action_values, winning_moves, losing_moves, jobcount
end

--------------------------------------------------
--	THREADPOOL MAKER FOR PARALLEL CODE	--
--------------------------------------------------

-- deps is a table of strings denoting dependencies
-- example, deps = {'tak_game','tak_AI'}
function make_threadpool(nthreads,deps,shared)
	local threads = require 'threads'
	local deps = deps or {}

	if shared then
		threads.Threads.serialization('threads.sharedserialize')
	end

	local pool = threads.Threads(nthreads, 
		function()
			require 'torch'
			require 'lib_AI'
			for _, dep in pairs(deps) do
				require(dep)
			end
		end,
		function(threadid)
			print('starting ' .. threadid)
		end)
	return pool
end

