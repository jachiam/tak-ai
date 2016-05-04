require 'tak_mcts_draft'
rand = random_AI.new()
takai = make_takai(3,true)
mctsai = mcts_AI.new(tak.new(5),30,1,true)

function test()
	game = tak.new(5)
	AI_vs_AI(game,mctsai,human,true)
end
