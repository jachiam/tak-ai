require 'tak_game'
require 'lib_AI'
require 'tak_AI_utils'

local function run_speed_test(game,switch,floodswitch)
	game.switch = switch
	game.floodswitch = floodswitch
	local start_time = os.clock()
	game:set_debug_times_to_zero()
	print(minimax_move3(game,5,debug_value_of_node))
	print('total time: ' .. os.clock() - start_time)
	game:print_debug_times()
	print('Loop count: ' .. game.loop_count)
	print('Loop len:   ' .. game.loop_len)
	print('Av loop len:' .. game.loop_len / game.loop_count)
	print(game.island_max_dims[1] .. ', ' .. game.island_max_dims[2])
	print(game.island_len_sums[1] .. ', ' .. game.island_len_sums[2])
	print()
	print()
end

local function run_speed_test2(game,switch,floodswitch)
	game.switch = switch
	game.floodswitch = floodswitch
	local start_time = os.clock()
	game:set_debug_times_to_zero()
	print(minimax_move3(game,6,normalized_value_of_node2))
	print('total time: ' .. os.clock() - start_time)
	game:print_debug_times()
	print('Loop count: ' .. game.loop_count)
	print('Loop len:   ' .. game.loop_len)
	print('Av loop len:' .. game.loop_len / game.loop_count)
	print(game.island_max_dims[1] .. ', ' .. game.island_max_dims[2])
	print(game.island_len_sums[1] .. ', ' .. game.island_len_sums[2])
	print()
	print()
end


game = tak.new(5)
game:play_game_from_file('game.txt')

--run_speed_test(game,false)
run_speed_test(game,true,false)
run_speed_test(game,true,true)
--run_speed_test2(game,false)
run_speed_test2(game,true,false)
run_speed_test2(game,true,true)

game = tak.new(5)

--run_speed_test(game,false)
run_speed_test(game,true,false)
run_speed_test(game,true,true)
run_speed_test2(game,true,false)
run_speed_test2(game,true,true)



