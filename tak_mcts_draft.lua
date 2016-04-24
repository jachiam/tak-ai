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

	--[[
	if #self.children > 0 then
		self.Q = torch.cdiv(self.Wv,self.Nv)*(1-lambda) + torch.cdiv(self.Wr,self.Nr)*lambda
	else
		self.Q = torch.cdiv(self.Wr,self.Nr)
	end]]
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
	self.Wv[a] = self.Wv[a] + val
	self.Nv[a] = self.Nv[a] + 1
	self:update_Vv_Vr()
	self:update_Q()
end

function mcts_node:raw_rollout_update(a,val)
	self.Wr[a] = self.Wr[a] + val
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
		child:make_move(a)
		self.children[a] = child 
	end
end

function mcts_node:rollout(a,rollout_policy)
	local sim = rollout(node,rollout_policy,false,1,false)
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
	return a, uct_vals
end

function mcts_node:print_statistics()
	for a, move in pairs(self.legal_move_table) do
		print('Move: ' .. move .. '\t Wv: ' .. self.Wv[a] .. '\t Nv: ' .. self.Nv[a]
			.. '\t Wr: ' .. self.Wr[a] .. '\t Nr: ' .. self.Nr[a] .. '\t Q: ' .. self.Q[a])
	end
end


function mcts_loop(root,time)
	local start_time = os.time()

	while os.time() - start_time < time do
		mcts_search_single_iteration(root,rollout_policy,root.game_state:get_player(),true)
	end
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
end
