require 'tak_AI'
require 'lib_AI'

n_thr = 5	-- visitation threshold for expansion
lambda = 0.5	-- mixing parameter for value function evaluation and monte carlo rollout evaluation
c_uct = 0.25	-- exploration/exploitation trade-off for UCT
n_vl = 3	-- number of virtual losses

local mcts_node = torch.class('mcts_node')

function mcts_node:__init(game_state,maxplayeris)
	self.game_state = game_state
	self.maxplayeris = maxplayeris
	self.legal_move_table = self.game_state:get_legal_move_table()
	self.Nv = torch.zeros(#self.legal_move_table)
	self.Nr = torch.zeros(#self.legal_move_table)
	self.Wv = torch.zeros(#self.legal_move_table)
	self.Wr = torch.zeros(#self.legal_move_table)
	self:update_Vv_Vr()
	self.Q  = torch.zeros(#self.legal_move_table)
	self.Nr_sum = 0		-- how many rollouts did we explore from this node?
	self.children = {}	-- children of this node
	self.value = nil	-- value of this node as a leaf

	if game_state:get_player() == maxplayeris then
		self.flip = false
	else
		self.flip = true
	end
end

function mcts_node:update_Vv_Vr()
	self.Vv = torch.gt(self.Nv,0)	-- Visited value
	self.Vr = torch.gt(self.Nr,0)	-- Visited rollout
end

function mcts_node:update_Q()	

	if #self.children > 0 then
		local Qv = torch.zeros(self.Nv:numel())
		Qv[self.Vv] = torch.cdiv(self.Wv[self.Vv],self.Nv[self.Vv]):mul(1-lambda)

		local Qr = torch.zeros(self.Nr:numel())
		Qr[self.Vr] = torch.cdiv(self.Wr[self.Vr],self.Nr[self.Vr]):mul(lambda)

		self.Q = Qv:add(Qr)
	else
		local Qr = torch.zeros(self.Nr:numel())
		Qr[self.Vr] = torch.cdiv(self.Wr[self.Vr],self.Nr[self.Vr])

		self.Q = Qr
	end

end

function mcts_node:set_value(val)
	self.value = val
end

function mcts_node:apply_virtual_loss(a)
	self.Nr[a] = self.Nr[a] + n_vl
	self.Wr[a] = self.Wr[a] + 0	-- here, we assume 0 = loss and 1 = win
	self:update_Vv_Vr()
end

function mcts_node:remove_virtual_loss(a)
	self.Nr[a] = self.Nr[a] - n_vl
	self:update_Vv_Vr()
end

function mcts_node:raw_value_update(a,val)
	local v = val
	if self.flip then v = 1 - v end
	self.Wv[a] = self.Wv[a] + val
	self.Nv[a] = self.Nv[a] + 1
	self:update_Vv_Vr()
	self:update_Q()
end

function mcts_node:raw_rollout_update(a,val)
	local v = val
	if self.flip then v = 1 - v end
	self.Wr[a] = self.Wr[a] + v
	self.Nr[a] = self.Nr[a] + 1
	self.Nr_sum = self.Nr_sum + 1
	self:update_Vv_Vr()
	self:update_Q()
	if self.Nr[a] > n_thr and self.children[a] == nil then 
		self:expand(a) 
	end
end

function mcts_node:expand(a)
	if self.children[a] == nil then
		local child = self.game_state:clone()
		child:make_move(self.legal_move_table[a])
		self.children[a] = mcts_node.new(child,self.maxplayeris) 
	end
end

function mcts_node:rollout(a,rollout_policy)
	local sim = rollout(self.game_state,rollout_policy,false,1,false)
	local val = default_value(sim,self.maxplayeris)
	return sim, val
end

function mcts_node:uct_select()
	local uct_vals = torch.cinv(self.Nr)
	if self.Nr_sum == 0 then
		-- if we haven't visited anything, every action has value infinity.
		-- pick something randomly.
		a = torch.random(self.Nr:numel())
		return a, uct_vals
	end
	--uct_vals[a] = self.Q[a] + 2 * c_uct * sqrt( log(2* self.Nr_sum) / self.Nr[a])
	uct_vals:mul(math.log(2*self.Nr_sum) + 1e-16):sqrt():mul(2*c_uct):add(self.Q)
	local _, a = torch.max(uct_vals,1)
	return a[1], uct_vals
end

function mcts_node:print_statistics()
	local function round(x) return math.floor(x*1000)/1000 end

	for a, move in pairs(self.legal_move_table) do
		print('Move: ' .. move .. '\t Wv: ' .. round(self.Wv[a]) .. '\t Nv: ' .. self.Nv[a]
			.. '\t Wr: ' .. round(self.Wr[a]) .. '\t Nr: ' 
			.. self.Nr[a] .. '\t Q: ' .. round(self.Q[a]))
	end
end


function mcts_loop(root,time)
	local start_time = os.time()

	local rollout_policy = default_rollout_policy.new()
	local depth

	local av_depth = 0
	local n = 0

	while os.time() - start_time < time do
		depth = mcts_search_single_iteration(root,rollout_policy,root.game_state:get_player(),true)
		av_depth = av_depth + depth
		n = n + 1
	end

	return av_depth, n
end

function mcts_search_single_iteration(root,rollout_policy,maxplayeris,virtual_losses)
	local pre_leaf_path = {}
	local pre_leaf_acts = {}
	-- selection phase
	local leaf_reached = false
	local cur = root
	while not(leaf_reached) do
		a = cur:uct_select()
		table.insert(pre_leaf_acts,a)
		table.insert(pre_leaf_path,cur)

		if virtual_losses then
			cur:apply_virtual_loss(a)
		end

		if cur.children[a] == nil then
			leaf_reached = true
		else
			cur = cur.children[a]
		end
	end

	if cur.value == nil then
		cur:set_value(normalized_value_of_node(cur.game_state,maxplayeris))
	end

	local value_eval = cur.value

	-- rollout phase
	local _, rollout_eval = cur:rollout(a,rollout_policy)


	-- backup phase
	for i=#pre_leaf_path,1,-1 do
		cur = pre_leaf_path[i]
		a = pre_leaf_acts[i]
		cur:raw_value_update(a,value_eval)
		cur:raw_rollout_update(a,rollout_eval)
		if virtual_losses then
			cur:remove_virtual_loss(a)
		end
	end

	return #pre_leaf_path
end

local mcts_AI = torch.class('mcts_AI','AI')

function mcts_AI:__init(game,ai_player_is)
	
end

function mcts_AI:move(node)
	
end
