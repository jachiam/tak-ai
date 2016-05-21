require 'tak_game'
require 'lib_AI'
require 'tak_AI_utils'
game = tak.new(5)
game:play_game_from_file('game.txt')
local start_time = os.clock()
game:set_debug_times_to_zero()
print(minimax_move3(game,5,debug_value_of_node))
print('total time: ' .. os.clock() - start_time)
game:print_debug_times()
