require 'tak_AI'
require 'lib_AI'

n_thr = 3	-- visitation threshold for expansion
lambda = 0.4	-- mixing parameter for value function evaluation and monte carlo rollout evaluation
c_uct = 0.25	-- exploration/exploitation trade-off for UCT
n_vl = 3	-- number of virtual losses

local mcts_node = torch.class('mcts_node')

function mcts_node:__init(game_state,maxplayeris)
	self.game_state = game_state
	self.maxplayeris = maxplayeris
	self.legal_move_table = self.game_state:get_legal_move_table() -- index to move
	self.move2index = {}
	for j, move in pairs(self.legal_move_table) do self.move2index[move] = j end
	self.Nv = torch.zeros(#self.legal_move_table)
	self.Nr = torch.zeros(#self.legal_move_table)
	self.Wv = torch.zeros(#self.legal_move_table)
	self.Wr = torch.zeros(#self.legal_move_table)
	--[[self.Vv = torch.zeros(#self.legal_move_table)
	self.Vr = torch.zeros(#self.legal_move_table)]]
	self:update_Vv_Vr()
	self.Q  = torch.zeros(#self.legal_move_table)
	self.Nr_sum = 0		-- how many rollouts did we explore from this node?
	self.children = {}	-- children of this node
	self.value = nil	-- value of this node as a leaf

	self.guaranteed_losses = torch.zeros(#self.legal_move_table)
	self.guaranteed_wins = torch.zeros(#self.legal_move_table)

	if game_state:get_player() == maxplayeris then
		self.maxnode = true
	else
		self.maxnode = false
	end
end

function mcts_node:update_Vv_Vr()
	self.Vv = torch.gt(self.Nv,0)	-- Visited value
	self.Vr = torch.gt(self.Nr,0)	-- Visited rollout
	--[[self.Vv:copy(torch.gt(self.Nv,0))
	self.Vr:copy(torch.gt(self.Nr,0))]]
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

	self.Q:cmul(torch.add(-self.guaranteed_losses,1))

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
	if not(self.maxnode) then v = 1 - v end
	self.Wv[a] = self.Wv[a] + val
	self.Nv[a] = self.Nv[a] + 1
	self:update_Vv_Vr()
	self:update_Q()
end

function mcts_node:raw_rollout_update(a,val)
	local v = val
	if not(self.maxnode) then v = 1 - v end
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
		if child:is_terminal() then
			if child.winner == self.maxplayeris and self.maxnode then
				self.guaranteed_wins[a] = 1
			elseif not(child.winner == self.maxplayeris) and not(self.maxnode) then
				self.guaranteed_losses[a] = 1
			end
		end
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
	if self.guaranteed_losses:sum() > 0 and not(self.maxnode) then
		uct_vals = self.guaranteed_losses
	elseif self.guaranteed_wins:sum() > 0 and self.maxnode then
		uct_vals = self.guaranteed_wins
	end
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

	return #pre_leaf_path, pre_leaf_path, pre_leaf_acts
end

function advance_to_child(root,last_move)
	local a = root.move2index[last_move]
	local child = root.children[a]
	if child ~= nil then
		return child
	else
		root:expand(a)
		return root.children[a]
	end
end

local mcts_AI = torch.class('mcts_AI','AI')

function mcts_AI:__init(game,time,ai_player_is,debug)
	self.root = mcts_node.new(game,ai_player_is)
	self.time = time
	self.debug = debug
end

function mcts_AI:move(node)
	if node:is_terminal() then
		if self.debug then print 'Game is over.' end
		return false
	end
	local start_time = os.clock()
	local hist = node:get_history()
	if #hist > 0 then
		local last_move = hist[#hist]
		self.root = advance_to_child(self.root,last_move)
	end
	mcts_loop(self.root,self.time)
	local nv ,a_ind = torch.max(self.root.Nr,1)
	a = self.root.legal_move_table[a_ind[1]]
	local v = self.root.Q[a_ind[1]]
	if self.debug then
		print('AI move: ' .. a .. ', Value: ' .. v .. ', Num Visits: ' .. nv[1] .. ', Time taken: ' .. (os.clock() - start_time))
		self.root:print_statistics()
	end
	node:make_move(a)
	self.root = advance_to_child(self.root,a)
end














local async_mcts_node = torch.class('async_mcts_node','mcts_node')

function async_mcts_node:update_Vv_Vr()
	if self.Vv == nil then
		self.Vv = torch.gt(self.Nv,0)	-- Visited value
		self.Vr = torch.gt(self.Nr,0)	-- Visited rollout
	else
		self.Vv:copy(torch.gt(self.Nv,0))
		self.Vr:copy(torch.gt(self.Nr,0))
	end
end

function async_mcts_node:update_Q()	

	if #self.children > 0 then
		local Qv = torch.zeros(self.Nv:numel())
		Qv[self.Vv] = torch.cdiv(self.Wv[self.Vv],self.Nv[self.Vv]):mul(1-lambda)

		local Qr = torch.zeros(self.Nr:numel())
		Qr[self.Vr] = torch.cdiv(self.Wr[self.Vr],self.Nr[self.Vr]):mul(lambda)

		self.Q:copy(Qv:add(Qr))
	else
		local Qr = torch.zeros(self.Nr:numel())
		Qr[self.Vr] = torch.cdiv(self.Wr[self.Vr],self.Nr[self.Vr])

		self.Q:copy(Qr)
	end

	self.Q:cmul(torch.add(-self.guaranteed_losses,1))

end

function async_mcts_node:raw_rollout_update(a,val)
	local v = val
	if not(self.maxnode) then v = 1 - v end
	self.Wr[a] = self.Wr[a] + v
	self.Nr[a] = self.Nr[a] + 1
	self.Nr_sum = self.Nr_sum + 1
	self:update_Vv_Vr()
	self:update_Q()
end




function async_mcts_loop(pool,root,time)

	local rollout_policy = default_rollout_policy.new()
	
	local av_depth = 0
	local n = 0

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
					depth, path, acts = mcts_search_single_iteration(root,
									rollout_policy,
									root.game_state:get_player(),
									true)
					return depth, path, acts
				end,

				function(depth, path, acts)
					local cur,a = path[#path], acts[#acts]
					if cur.Nr[a] > n_thr and cur.children[a] == nil then 
						cur:expand(a) 
					end
					av_depth = av_depth + depth
					n = n + 1
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
		--if root.guaranteed_wins:sum() > 0 then break end
	end
	
	local real_jobtime = os.clock() - start_time_CPU
	print('Total CPU time: ' .. real_jobtime .. ', Estimated Speedup Over Realtime: ' .. real_jobtime / time)

	return av_depth, n
end



local async_mcts_AI = torch.class('async_mcts_AI','AI')

function async_mcts_AI:__init(game,time,ai_player_is,nthreads,debug)
	self.root = async_mcts_node.new(game,ai_player_is)
	self.time = time
	self.nthreads = nthreads or 4
	self.debug = debug

	self.threadpool = make_threadpool(nthreads,{'tak_mcts_draft'},true)
end

function async_mcts_AI:move(node)
	if node:is_terminal() then
		if self.debug then print 'Game is over.' end
		return false
	end
	local start_time = os.clock()
	local hist = node:get_history()
	if #hist > 0 then
		local last_move = hist[#hist]
		self.root = advance_to_child(self.root,last_move)
	end
	async_mcts_loop(self.pool,self.root,self.time)
	local nv ,a_ind = torch.max(self.root.Nr,1)
	a = self.root.legal_move_table[a_ind[1]]
	local v = self.root.Q[a_ind[1]]
	if self.debug then
		local tot_time = os.clock() - start_time
		print('AI move: ' .. a .. ', Value: ' .. v .. ', Num Visits: ' .. nv[1] .. ', Realtime Taken: ' .. self.time )
		self.root:print_statistics()
	end
	node:make_move(a)
	self.root = advance_to_child(self.root,a)
end
