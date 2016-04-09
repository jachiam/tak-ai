local threads = require 'threads'
require 'tak_game'
require 'tak_tree_AI'
require 'tak_flatmc_AI'
require 'os'

function make_threadpool(nthreads)
	local pool = threads.Threads(nthreads, 
		function()
			require 'torch'
			require 'tak_game'
			require 'tak_tree_AI'
			require 'tak_flatmc_AI'
		end,
		function(threadid)
			print('starting ' .. threadid)
		end)
	return pool
end

pool = make_threadpool(4)

function do_stuff(node,nsims)

	local upval = 0
	local upcount = 0
	for i=1,nsims do
		pool:addjob(
			function()
				local s = simulate_game(node,false)
				if s.winner == player then
					return 1
				elseif s.winner == 0 then
					return 0.5
				else
					return 0
				end
			end,
			function(val)
				upval = upval + val
				upcount = upcount + 1
			end
		)
	end

	pool:synchronize()

	return upval, upcount
end

function do_stuff_async(node,time)

	local upval = 0
	local upcount = 0
	local jobcount = 0
	local jobid = 0
	local start_time

	local function get()
	   
		-- fill up the queue as much as we can
		-- this will not block
		while pool:acceptsjob() and os.time() - start_time <= time do
			jobid = jobid + 1
		
			pool:addjob(
				function(jobid)
					local s = simulate_game(node,false)
					if s.winner == player then
						return 1
					elseif s.winner == 0 then
						return 0.5
					else
						return 0
					end
				end,

				function(val)
					upval = upval + val
					upcount = upcount + 1
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
			return upval, upcount
		end
	end

	start_time = os.time()
	while os.time() - start_time <= time do
		-- get something asynchronously
		upval, upcount = get()
	end

	return upval, upcount, jobcount
end

function async_action_values(node,time,check,smart,partial,k)

	local partial = partial or false
	local k = k or 10

	local legal = node.legal_moves_by_ply[#node.legal_moves_by_ply]
	local raw_action_values = torch.zeros(legal[3]:size())
	local action_values = torch.zeros(legal[3]:size())
	local num_visited = torch.zeros(legal[3]:size())
	local player = node:get_player()
	local legal_moves = legal[3]:byte()
	local losing_moves = num_visited:clone()
	local winning_moves = num_visited:clone()

	local jobcount = 0
	local jobid = 0
	local jobtime = 0
	local start_time

	local function async_eval()
	   
		-- fill up the queue as much as we can
		-- this will not block
		while pool:acceptsjob() and os.time() - start_time <= time do

			jobid = jobid + 1
		
			pool:addjob(
				function(jobid)
					local start = os.clock()
					local flag, a, val, gw, gl = select_and_playout_move(node,
									raw_action_values:clone(),
									num_visited:clone(),
									legal_moves:clone(),
									check,
									winning_moves:clone(),
									losing_moves:clone(),
									smart,
									partial,
									k)

					return flag,a, val, gw, gl, os.clock() - start
				end,

				function(flag,a,val,gw,gl,dt)

					jobtime = jobtime + dt

					if gw then
						winning_moves[a] = 1
						raw_action_values[a] = 1
						num_visited[a] = 1
						return
					elseif gl then
						losing_moves[a] = 1
						raw_action_values[a] = 0
						num_visited[a] = 1
						return
					end

					if flag then
						raw_action_values[a] = raw_action_values[a] + val
						num_visited[a] = num_visited[a] + 1
					end
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
		--if winning_moves:sum() > 0 then break end
	end
	
	local real_jobtime = os.clock() - start_time_CPU
	print('Total job time: ' .. jobtime .. ', Estimated Speedup Over Realtime: ' .. jobtime / time)
	print('Total CPU time: ' .. real_jobtime .. ', Estimated Speedup Over Realtime: ' .. real_jobtime / time)

	action_values = means(raw_action_values,num_visited)
	return action_values, num_visited, raw_action_values, winning_moves, losing_moves, legal, jobcount, jobtime
end

function async_flat_monte_carlo_move(node,time,debug,smart,partial,k)
	if node.game_over then
		if debug then print 'Game is over.' end
		return false
	end
	local start_time = os.time()
	local av, nv, rav, wm, lm = async_action_values(node,time,true,smart,partial,k)
	local _, a = torch.max(av,1)
	node:make_move_by_idx(a[1])
	local elapsed_time = os.time() - start_time
	if debug then
		print('MC move: ' .. node.move2ptn[a[1]] .. ', Value: ' .. av[a[1]] .. ', Num Simulations: ' .. nv:sum() .. ', Time Elapsed: ' .. elapsed_time)
		print('Moves considered: ')
		--local visited = torch.gt(nv,0)
		for i=1,av:numel() do
			if nv[i] > 0 then
				print(node.move2ptn[i] .. '\t' .. 'Value: ' .. round(av[i]) .. '\t Num Plays: ' .. nv[i])
			end
		end
	end
	return av, nv, rav, wm, lm
end

function round(x)
	return math.floor(x*1000)/1000
end
