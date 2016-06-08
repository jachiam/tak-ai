require 'tak_game'
require 'lib_AI'
require 'tak_AI_utils'

stochastic = false

local function run_speed_test(game)
	local start_time = os.clock()
	game:set_debug_times_to_zero()
	print(minimax_move3(game,5,debug_value_of_node))
	print('total time: ' .. os.clock() - start_time)
	game:print_debug_times()
	print(game.island_max_dims[1] .. ', ' .. game.island_max_dims[2])
	print(game.island_len_sums[1] .. ', ' .. game.island_len_sums[2])
	print()
	print()
end

local function run_speed_test2(game)
	local start_time = os.clock()
	game:set_debug_times_to_zero()
	print(minimax_move3(game,6,normalized_value_of_node2))
	print('total time: ' .. os.clock() - start_time)
	game:print_debug_times()
	print(game.island_max_dims[1] .. ', ' .. game.island_max_dims[2])
	print(game.island_len_sums[1] .. ', ' .. game.island_len_sums[2])
	print()
	print()
end


local function run_speed_test3(game)
	local start_time = os.clock()
	game:set_debug_times_to_zero()
	print(minimax_move3(game,6,normalized_value_of_node3))
	print('total time: ' .. os.clock() - start_time)
	game:print_debug_times()
	print(game.island_max_dims[1] .. ', ' .. game.island_max_dims[2])
	print(game.island_len_sums[1] .. ', ' .. game.island_len_sums[2])
	print()
	print()
end


game = tak.new(5)
game:play_game_from_file('game.txt')

print('Checksum: 194374')
run_speed_test(game)
print('Checksum: 2645531')
run_speed_test2(game)
print('Checksum: 2328669')
run_speed_test3(game)

game = tak.new(5)

print('Checksum: 145233')
run_speed_test(game)
print('Checksum: 356046')
run_speed_test2(game)
print('Checksum: 364510')
run_speed_test3(game)




