require 'tak_AI_utils'
require 'lib_AI'

------------------------------
-- TAKAI : A MINIMAX TAK AI --
------------------------------

function make_takai(depth,debug)
	return minimax_AI.new(depth,normalized_value_of_node,debug)
end


