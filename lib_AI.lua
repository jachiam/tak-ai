require 'torch'

--------------------------------------------------
--		AI OBJECTS			--
--------------------------------------------------

local AI = torch.class('AI')

function AI:move(node)
	-- the basic template for an AI interface
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
	v, a, _, mc, nl = alphabeta(node,self.depth,-1/0,1/0,true,node:get_player(),self.value)
	node:make_move(a)
	if self.debug then
		print('AI move: ' .. a .. ', Value: ' .. v .. ', Num Leaves: ' .. nl)
	end
	return mc
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
-- 	maximizingPlayer: boolean that indicates whether at this level we are minning (false) or maxing (true)
--	maxplayeris: 1 or 2, helps us keep track of which player actually called the alpha-beta recursive minimax function in the first place
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

