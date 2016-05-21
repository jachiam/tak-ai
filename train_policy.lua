require 'tak_training'
require 'tak_policy'
require 'tak_value'
require 'optim'


data = load_dataset('training/5-5-16a.t7')
p = tak_policy.new(tak.new(5))
v = tak_value.new(tak.new(5))

function train(trainable,data,lr,batch_size,niter)
	local function round(x,n) 
		if n ~= nil then y = 10^n else y = 1000 end
		return math.floor(x*y)/y 
	end
	local lr = lr or 0.0001
	for j=1,niter do
		print('\n\n========= Iteration ' .. j .. ' =========')
		print('% completed:\t' .. round(100*j/niter) 
			.. '\np mean: \t' .. trainable.params:mean()
			.. '\np max:  \t' .. trainable.params:max()
			.. '\ngp mean: \t' .. trainable.gradparams:mean() 
			.. '\ngp max:  \t' .. trainable.gradparams:max())
		local batch = data:sample_minibatch(batch_size)
		local targets
		local feval = function(x)
			if x~=trainable.params then
				trainable.params:copy(x)
			end
			trainable.gradparams:zero()
			if trainable.__typename == 'tak_value' then targets = batch.v else targets = batch.a end
			local outputs, input = trainable:get_outputs(batch.s)
			local f = trainable.criterion:forward(outputs,targets)
			local df_do = trainable.criterion:backward(outputs,targets)
			trainable.network:backward(input,df_do)
			return f,trainable.gradparams
		end
		optim_config = optim_config or {learningRate=lr,alpha=0.9,epsilon=1e-8}
		state = state or {}
		local _, f0 = optim.rmsprop(feval,trainable.params,optim_config,state)
		--local f = feval(trainable.params)
		local outputs = trainable:get_outputs(batch.s)
		local f = trainable.criterion:forward(outputs,targets)
		print('\nloss before:\t' .. round(f0[1],6) .. '\nloss after:\t' .. round(f,6)
			.. '\ndelta:      \t' .. round(f - f0[1],6))
	end
end
