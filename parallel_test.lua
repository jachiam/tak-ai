require 'lib_AI'

pool = make_threadpool(4)

function parallel_test(time)

	local depth = 0

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
					depth = depth + 1
					return depth
				end,

				function(dep)
					depth = dep
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

	return depth
end
