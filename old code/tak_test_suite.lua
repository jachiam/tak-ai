require 'tak_game'
--require 'tak_tree_AI'
--require 'tak_flatmc_AI'
--require 'tak_flatmc_AI_multithreaded'
t = tak.new(4)

--s = t:clone() 
gameptn = "[Size \"5\"]\n" ..
"\n1. Fa3 Fd1 " ..
"\n2. Sd2 Se5 " ..
"\n3. Ca4 Sb1 " ..
"\n4. Fe1 1e5-1 " ..
"\n5. Fe2 Ce5 " ..
"\n6. Fe3 1e5-1 " ..
"\n7. Fd3 Se5 " ..
"\n8. Fd4 1e5<1 " ..
"\n9. Fc4 Se5 " ..
"\n10. Fb4 	"
-- t:play_game_from_ptn(gameptn)

gameptn2 = "[Size \"4\"]\n" ..
"\n1. Fd2 Fd1 " ..
"\n2. Fc1 Fd4 " ..
"\n3. Fc2 Fd3 " ..
"\n4. Fc3 1d3<1 " ..
"\n5. Fb2 1d2-1 " ..
"\n6. Fd2 2d1+2 " ..
"\n7. Fd1 3d2-3 " ..
"\n8. Fd2 4d1+4 " ..
"\n9. Fd1 2c3-2 " ..
"\n10. Fb1 3c2-3 " ..
"\n11. 1d1<1" --Sd1 
-- 12. 4c1+112 	
t:reset()
--t:play_game_from_ptn(gameptn2)
--generate_game_by_alphabeta(t,1,2,5,true,true)

--io.input('game.txt')
--gptn = io.read('*all')
function data(filename)
	local f = torch.DiskFile(filename)
	local gptn = f:readString('*a')
	f:close()
	return gptn
end

t:play_game_from_ptn(data('game.txt'))

--[[
require 'tak_policy.lua'

tp = tak_policy.new(t.size,t.max_height,#t.move2ptn)
p = tp.network:getParameters()
print(p:size())]]

--[[
function minimax_vs_montecarlo(game,UCB,smart,mintime)
	local mintime = mintime or 75
	while not(game.game_over) do
		start_time = os.time()
		AI_move(game,3,true)
		time_elapsed = os.time() - start_time
		flat_monte_carlo_move(game,math.max(3*time_elapsed,mintime),true,UCB,smart,true)
		print(game:game_to_ptn())
	end
end

function minimax_vs_async_montecarlo(game,smart,mintime,minimax_first,partial,k)
	local mintime = mintime or 75
	local time_elapsed = 0
	local partial = partial or false
	local k = k or 10
	while not(game.game_over) do
		if minimax_first then
			start_time = os.time()
			AI_move(game,3,true)
			time_elapsed = os.time() - start_time
			async_flat_monte_carlo_move(game,math.max(time_elapsed,mintime),true,smart,partial,k)
		else
			async_flat_monte_carlo_move(game,math.max(time_elapsed,mintime),true,smart,partial,k)
			start_time = os.time()
			AI_move(game,3,true)
			time_elapsed = os.time() - start_time
		end
		print(game:game_to_ptn())
	end
end 

function against_MC_AI(node,mintime,debug,smart,partial,k)
	local mintime = mintime or 75
	while node.win_type == 'NA' do
		if debug then
			print(node:game_to_ptn())
			print ''
		end
		ptn = io.read()
		if ptn == 'quit' then
			break
		end
		valid = node:accept_user_ptn(ptn)
		if valid and not(node.game_over) then
			async_flat_monte_carlo_move(game,mintime,true,smart,partial,k)
		end
	end
	print('Game Over: ' .. node.outstr)
end ]]