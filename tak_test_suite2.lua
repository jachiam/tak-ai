require 'tak_mcts_draft'
rand = random_AI.new()
takai = make_takai(3,true)
mctsai = mcts_AI.new(tak.new(4),45,1,true)

function test()
	game = tak.new(4)
	AI_vs_AI(game,mctsai,takai,true)
end
