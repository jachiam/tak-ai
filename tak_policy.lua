require 'torch'
require 'nn'
require 'tak_game'

local tak_policy = torch.class('tak_policy')

function tak_policy:__init(game)--size,max_height,num_actions)
	self.size = game.size
	self.num_planes = game.max_height * 2 * 3
	self.num_actions = #game.move2ptn --num_actions
	self:make_network()
	self.criterion = nn.ClassNLLCriterion()--:float()
	self.params,self.gradparams = self.network:getParameters()
	self.exp = nn.Exp()--:float()
end

function tak_policy:make_network(debug)

	test_x = torch.rand(1,1,self.num_planes,self.size,self.size)

	nfilters = 32
	nlinear = 256

	self.network = nn.Sequential()
	self.network:add(nn.VolumetricConvolution(1,nfilters,
						10,self.size,self.size,		-- kT, kW, kH
						5,1,1,				-- dT, dW, dH
						5,3,3))			-- padT, padW, padH
	self.network:add(nn.ReLU())


	out = self.network:forward(test_x)
	if debug then print(out:size()) end

	self.network:add(nn.VolumetricConvolution(nfilters,nfilters,
						5,3,3,
						2,1,1,
						1,1,1))
	self.network:add(nn.ReLU())


	out = self.network:forward(test_x)
	if debug then print(out:size()) end

	self.network:add(nn.VolumetricConvolution(nfilters,nfilters,
						5,3,3,
						2,1,1,
						1,1,1))
	self.network:add(nn.ReLU())

	out = self.network:forward(test_x)
	if debug then print(out:size()) end


	self.network:add(nn.VolumetricConvolution(nfilters,nfilters,
						5,3,3,
						1,1,1,
						1,1,1))
	self.network:add(nn.ReLU())

	out = self.network:forward(test_x)
	if debug then print(out:size()) end


	self.network:add(nn.VolumetricConvolution(nfilters,nfilters,
						5,3,3,
						1,1,1,
						1,1,1))
	self.network:add(nn.ReLU())

	out = self.network:forward(test_x)
	if debug then print(out:size()) end


	len = out:size(2)*out:size(3)*out:size(4)*out:size(5)

	self.network:add(nn.Reshape(len))
	self.network:add(nn.Linear(len,nlinear))
	self.network:add(nn.ReLU())
	self.network:add(nn.Linear(nlinear,self.num_actions))
	self.network:add(nn.LogSoftMax())

	--self.network:float()
end

function tak_policy:preproc_data(states)
	dim = states:nDimension()
	nbatch = states:size(1) -- if batched
	if dim == 5 then	-- board state has 5 dims
		input = states:reshape(1,1,self.size,self.size,self.num_planes):transpose(3,5)
	else			-- batched states would have 6
		input = states:reshape(nbatch,1,self.size,self.size,self.num_planes):transpose(3,5)
	end
	return input
end

function tak_policy:get_outputs(states)
	input = self:preproc_data(states)
	log_pdists = self.network:forward(input)
	return log_pdists, input
end

function tak_policy:feval(batch)
	self.gradparams:zero()
	local outputs, input = self:get_outputs(batch.s)
	local f = self.criterion:forward(outputs,batch.a)
	local df_do = self.criterion:backward(outputs,batch.a)
	self.network:backward(input,df_do)
	return f,self.gradparams
end

function tak_policy:get_action(state,legal_move_mask)
	log_pdist = self:get_outputs(state)
	pdist = self.exp:forward(log_pdist):squeeze():mul(legal_move_mask)
	action = torch.multinomial(pdist:float(), 1)[1]
	return action, pdist, log_pdist
end

function tak_policy:act(node)
	local state = torch.DoubleTensor(node.board,node:get_legal_move_mask())
	return self:get_action(state)
end

function tak_policy:rollout(node)
	local a
	while not(node.game_over) do
		a = self:act(node)
		node:make_move(a)
	end
end
