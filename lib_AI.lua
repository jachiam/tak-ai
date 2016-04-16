require 'torch'


--------------------------------------------------
--		GAME OBJECT			--
--------------------------------------------------

-- this is the template for a game that is compatible with this library

local game_node = torch.class('game_node')

function game_node:__init()
	self.winner = 0
	self.ply = 0
end

function game_node:is_terminal()
	return false
end

function game_node:make_move(a)
	self.ply = self.ply + 1
	return true
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


----------------------
-- MINIMAX AI CLASS --
----------------------

local minimax_AI = torch.class('minimax_AI','AI')

-- minimax_AI needs a value function from (node, player) pair to real scalar value
function minimax_AI:__init(depth,value,debug)
	self.depth = depth
	self.value = value
	self.debug = debug
end

function minimax_AI:move(node)
	if node:is_terminal() then
		if self.debug then print 'Game is over.' end
		return false
	end
	local v, a, mc, nl
	--v, a, _, mc, nl = alphabeta(node,self.depth,-1/0,1/0,true,node:get_player(),self.value)
	v, a, nl = minimax_move2(node,self.depth,self.value)
	node:make_move(a)
	if self.debug then
		print('AI move: ' .. a .. ', Value: ' .. v .. ', Num Leaves: ' .. nl)
	end
	return mc
end

-------------------------------
-- FLAT MONTE CARLO AI CLASS --
-------------------------------

local flat_mc_AI = torch.class('flat_mc_AI','AI')

-- arguments to initialize flat_mc_AI:
--	time 	:	how long can it spend thinking per turn?		 (default: 60s)
--	rollout_policy: a function that takes a game node and returns an action. (default: random)
--	partial :	should it do full rollouts or partial rollouts?		 (default: false)
--	depth	:	if partial rollouts, to what depth?			 (default: 10)
--	value   :	a function that takes a game node and returns its value	 (default: value 0 everywhere)
function flat_mc_AI:__init(time,rollout_policy,partial,depth,value,debug)
	self.time = time
	self.rollout_policy = rollout_policy
	self.partial = partial
	self.depth = depth
	self.value = value
	self.debug = debug
end

function flat_mc_AI:move(node)
	if node:is_terminal() then
		if self.debug then print 'Game is over.' end
		return false
	end
	
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


--------------------------------------------------
--	ROLLOUT POLICY OBJECTS			--
--------------------------------------------------

local policy = torch.class('policy')

function policy:act(node)
	local legal_move_mask = node:get_legal_move_mask()
	return torch.multinomial(legal_move_mask,1)[1]
end

local default_rollout_policy = torch.class('default_rollout_policy','policy')

local epsilon_greedy_policy = torch.class('epsilon_greedy_policy','policy')

function epsilon_greedy_policy:__init(epsilon,value)
	self.epsilon = epsilon or 0.5
	self.value = value or default_value
end

function epsilon_greedy_policy:act(node)
	if torch.uniform() > self.epsilon then
		local _, a = minimax_move(node,1,self.value)
		return a
	else
		local legal_move_mask = node:get_legal_move_mask()
		return torch.multinomial(legal_move_mask,1)[1]
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
function alphabeta(node,depth,alpha,beta,maximizingPlayer,maxplayeris,value_of_node)
	if depth == 0 or node:is_terminal() then
		return value_of_node(node,maxplayeris), nil, nil, nil, 1
	end

	local children, legal = node:get_children()
	local best_action = 0
	local v = 0
	local a,b = alpha,beta

	local moves_considered = {}
	local num_leaves = 0

	if maximizingPlayer then
		v = -1/0
		for i=1,#children do
			val, _, _, _, nl = alphabeta(children[i],depth- 1, a, b, false, maxplayeris,value_of_node)
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
		v = 1/0
		for i=1,#children do
			val, _, _, _, nl = alphabeta(children[i],depth- 1, a, b, true, maxplayeris,value_of_node)
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
			node:make_move(move)
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
			node:make_move(move)
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


-- convenience method
function minimax_move(node,depth,value)
	return alphabeta(node,depth,-1/0,1/0,true,node:get_player(),value)
end


-- convenience method
function minimax_move2(node,depth,value)
	return alphabeta2(node,depth,-1/0,1/0,true,node:get_player(),value)
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
			sim:make_move(rollout_policy:act(sim))
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
				value)
	local rollout_policy = rollout_policy or default_rollout_policy
	local depth = depth or 10
	local value = value or default_value
	local copy = node:clone()
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
				v = alphabeta(copy,1,-1/0,1/0,false,player,default_value)
				if v == 1 then
					guarantee_win = true
				elseif v == 0 then
					guarantee_lose = true
				end
			end
			if not(guarantee_win or guarantee_lose) then
				sim = rollout(copy,rollout_policy,partial,depth-1)
				v = value(sim,player)
				runflag = true
			end
		end
	end

	return runflag, a, v, guarantee_win, guarantee_lose
end

