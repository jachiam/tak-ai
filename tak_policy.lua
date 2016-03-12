require 'torch'
require 'nn'

local tak_policy = torch.class('tak_policy')

function tak_policy:__init(size,max_height,num_actions)
	self.size = size
	self.num_planes = max_height * 2 * 3
	self.num_actions = num_actions
	self:make_network()
	self.exp = nn.Exp():float()
end

function tak_policy:make_network()

	nfilters = 32

	self.network = nn.Sequential()
	self.network:add(nn.VolumetricConvolution(1,nfilters,
						30,self.size,self.size,		-- kT, kW, kH
						18,1,1,				-- dT, dW, dH
						15,3,3))			-- padT, padW, padH
	self.network:add(nn.ReLU())
	self.network:add(nn.VolumetricConvolution(nfilters,nfilters,
						3,3,3,
						1,1,1))
	self.network:add(nn.ReLU())
	self.network:add(nn.VolumetricConvolution(nfilters,nfilters,
						3,3,3,
						1,1,1))
	self.network:add(nn.ReLU())

	test_x = torch.rand(1,1,self.num_planes,self.size,self.size)
	out = self.network:forward(test_x)
	print(out:size())
	len = out:size(2)*out:size(3)*out:size(4)*out:size(5)

	self.network:add(nn.Reshape(len))
	self.network:add(nn.Linear(len,self.num_actions))
	self.network:add(nn.LogSoftMax())

	self.network:float()
end

function tak_policy:get_log_pdists(states)
	dim = states:nDimension()
	nbatch = states:size()[1] -- if batched
	if dim == 5 then	-- board state has 5 dims
		input = states:reshape(1,1,self.size,self.size,self.num_planes):transpose(3,5)
	else			-- batched states would have 6
		input = states:reshape(nbatch,1,self.size,self.size,self.num_planes):transpose(3,5)
	end
	log_pdists = self.network:forward(input)
	return log_pdists
end

function tak_policy:get_action(state)
	log_pdist = self:get_log_pdists(state)
	pdist = self.exp:forward(log_pdist):squeeze()
	action = torch.multinomial(pdist:float(), 1)[1]
	return action, pdist, log_pdist
end
