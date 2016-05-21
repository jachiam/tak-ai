require 'torch'
require 'nn'
require 'tak_game'

local tak_value = torch.class('tak_value')

function tak_value:__init(game)
	self.size = game.size
	self.num_planes = game.max_height * 2 * 3
	self:make_network()
	self.criterion = nn.MSECriterion()--:float()
	self.params,self.gradparams = self.network:getParameters()
	self.exp = nn.Exp()--:float()
end

function tak_value:make_network(debug)

	test_x = torch.rand(1,1,self.num_planes,self.size,self.size)

	nfilters = 32
	nlinear = 256

	self.network = nn.Sequential()
	self.network:add(nn.VolumetricConvolution(1,nfilters,
						10,self.size,self.size,		-- kT, kW, kH
						5,1,1,				-- dT, dW, dH
						5,3,3))			-- padT, padW, padH
	--self.network:add(nn.ReLU())


	out = self.network:forward(test_x)
	if debug then print(out:size()) end

	self.network:add(nn.VolumetricConvolution(nfilters,nfilters,
						5,3,3,
						2,1,1,
						1,1,1))
	--self.network:add(nn.ReLU())


	out = self.network:forward(test_x)
	if debug then print(out:size()) end

	self.network:add(nn.VolumetricConvolution(nfilters,nfilters,
						5,3,3,
						2,1,1,
						1,1,1))
	--self.network:add(nn.ReLU())

	out = self.network:forward(test_x)
	if debug then print(out:size()) end


	self.network:add(nn.VolumetricConvolution(nfilters,nfilters,
						5,3,3,
						1,1,1,
						1,1,1))
	--self.network:add(nn.ReLU())

	out = self.network:forward(test_x)
	if debug then print(out:size()) end


	self.network:add(nn.VolumetricConvolution(nfilters,nfilters,
						5,3,3,
						1,1,1,
						1,1,1))
	--self.network:add(nn.ReLU())

	out = self.network:forward(test_x)
	if debug then print(out:size()) end


	len = out:size(2)*out:size(3)*out:size(4)*out:size(5)

	self.network:add(nn.Reshape(len))
	self.network:add(nn.Linear(len,nlinear))
	self.network:add(nn.Sigmoid())
	self.network:add(nn.Linear(nlinear,1))
	self.network:add(nn.Sigmoid())

	--self.network:float()
end

function tak_value:preproc_data(states)
	dim = states:nDimension()
	nbatch = states:size(1) -- if batched
	if dim == 5 then	-- board state has 5 dims
		input = states:reshape(1,1,self.size,self.size,self.num_planes):transpose(3,5)
	else			-- batched states would have 6
		input = states:reshape(nbatch,1,self.size,self.size,self.num_planes):transpose(3,5)
	end
	return input
end

function tak_value:get_outputs(states)
	input = self:preproc_data(states)
	values = self.network:forward(input)
	return values, input
end

function tak_value:feval(batch)
	self.gradparams:zero()
	local outputs, input = self:get_outputs(batch.s)
	local f = self.criterion:forward(outputs,batch.v)
	local df_do = self.criterion:backward(outputs,batch.v)
	self.network:backward(input,df_do)
	return f,self.gradparams
end

