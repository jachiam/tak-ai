require 'torch'
require 'tak_AI'


function make_parameterized_takai(params,depth,debug)
	local value = generate_new_value_function(params)
	return killer_minimax_AI.new(depth,value,debug)
end


p0 = {0.75,0,2.5,0,0,0,0,0,3,0,0,0,-1,-1,0}

function mutate(p)
	local d = {}
	for j=1,#p do
		d[j] = torch.normal(p[j],1/math.max(10,math.abs(p[j])))
	end
	return d
end


function initialize_population(p0,N,depth)
	local d
	local P = {}
	P[1] = p0
	for j=1,N do
		if j>1 then local p = mutate(p0) else p = p0 end
		P[j] = {p,make_parameterized_takai(p,depth,false)}
	end
	return P
end


function evaluate(P,ngames)
	local stats = {}
	for j=1,#P do
		stats[j] = {0,0,0,0,0} -- wins as white, wins as black, losses as white, losses as black, ties
	end
	for j=1,ngames do
		local i1 = torch.random(#P)
		local i2 = torch.random(#P)
		if i1 == i2 and i2<#P then 
			i2 = i2 + 1 
		elseif i1 == i2 and i2>1 then
			i2 = i2 - 1
		end
		local winner = compete(P[i1][2],P[i2][2])
		if winner==1 then
			stats[i1][1] = stats[i1][1] + 1	-- white won
			stats[i2][4] = stats[i2][4] + 1 -- black lost
		elseif winner==2 then
			stats[i1][3] = stats[i1][3] + 1	-- white lost
			stats[i2][2] = stats[i2][2] + 1 -- black won
		else
			stats[i1][5] = stats[i1][5] + 1
			stats[i2][5] = stats[i2][5] + 1
		end
	end

	local scores = {}
	for j=1,#P do
		scores[j] = stats[j][1] + 1.1*stats[j][2] - stats[j][3] - 0.9*stats[j][4]
	end

	return scores, stats
end

function evolve(P,n_sel,mut_prob)
	
	
	
end


function compete(AI1,AI2)
	local game = tak.new(5)
	while not(game.game_over) do
		AI1:move(game)
		if game:is_terminal() then break end
		AI2:move(game)
	end
	return game.winner
end
