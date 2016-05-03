--[[require 'tak_AI'

game = tak.new(5)
game:play_game_from_file('game.txt')
map = game.board_top[{{},{},1,1}] + game.board_top[{{},{},1,3}] ]]

function calculate_islands(map,method,looptype)

	local unexplored_nodes, islands, l, w

	local function flood_fill(unexplored,island,i,j)
		if map[{i,j}] == 1 and unexplored[{i,j}] == 1 then
			unexplored[{i,j}] = 0
			island[{i,j}] = 1
			if i > 1 then
				flood_fill(unexplored,island,i-1,j)
			end
			if i < l then
				flood_fill(unexplored,island,i+1,j)
			end
			if j > 1 then
				flood_fill(unexplored,island,i,j-1)
			end
			if j < w then
				flood_fill(unexplored,island,i,j+1)
			end
		end
	end

	local function flood_fill2(unexplored,island,i,j)
		local q = {{i,j}}
		local nproc = 0
		local x, x2
		while #q > nproc do
			x = q[nproc+1]
			if map[x] == 1 and unexplored[x] == 1 then
				unexplored[x] = 0
				island[x] = 1
				x2 = { {x[1]-1,x[2]}, {x[1]+1,x[2]},
					{x[1],x[2]-1}, {x[1], x[2]+1} }
				if x[1] > 1 and unexplored[x2[1]] == 1 then
					table.insert(q,x2[1])
				end
				if x[1] < l and unexplored[x2[2]] == 1 then
					table.insert(q,x2[2])
				end
				if x[2] > 1 and unexplored[x2[3]] == 1 then
					table.insert(q,x2[3])
				end
				if x[2] < w and unexplored[x2[4]] == 1 then
					table.insert(q,x2[4])
				end
			end
			nproc = nproc + 1
		end
	end


	local function flood_fill3(unexplored,island,i,j)
		local q = {{i,j}}
		local nproc = 0
		local x, y
		while #q > nproc do
			x = q[nproc+1]
			if map[x] == 1 and unexplored[x] == 1 then
				unexplored[x] = 0
				island[x] = 1
				if x[2] > 1 then table.insert(q,{x[1],x[2]-1}) end
				if x[2] < w then table.insert(q,{x[1],x[2]+1}) end
				y = {x[1],x[2]}
				local flag = x[1] > 1
				while flag do
					y = {y[1] - 1, y[2]}
					if unexplored[y] == 1 and map[y] == 1 then
						unexplored[y] = 0
						island[y] = 1
						if y[2] > 1 and unexplored[{y[1],y[2]-1}] == 1 then table.insert(q,{y[1],y[2]-1}) end
						if y[2] < w and unexplored[{y[1],y[2]+1}] == 1 then table.insert(q,{y[1],y[2]+1}) end
					else
						flag = false
					end
					if y[1] == 1 then flag = false end
				end
				y = {x[1],x[2]}
				flag = x[1] < l
				while flag do
					y = {y[1] + 1, y[2]}
					if unexplored[y] == 1 and map[y] == 1 then
						unexplored[y] = 0
						island[y] = 1
						if y[2] > 1 and unexplored[{y[1],y[2]-1}] == 1 then table.insert(q,{y[1],y[2]-1}) end
						if y[2] < w and unexplored[{y[1],y[2]+1}] == 1 then table.insert(q,{y[1],y[2]+1}) end
					else
						flag = false
					end
					if y[1] == l then flag = false end
				end
			end
			nproc = nproc + 1
		end
	end

	l,w = map:size()[1], map:size()[2]
	islands = {}
	unexplored_nodes = torch.ones(l,w)

	if looptype== 1 then
		for i=1,l do
			for j=1,w do
				if unexplored_nodes[{i,j}] == 1 and map[{i,j}] == 1 then
					table.insert(islands,torch.zeros(l,w))
					if method==1 then
						flood_fill(unexplored_nodes,islands[#islands],i,j)
					elseif method==2 then
						flood_fill2(unexplored_nodes,islands[#islands],i,j)
					elseif method==3 then
						flood_fill3(unexplored_nodes,islands[#islands],i,j)
					end
				end
			end
		end
	else
		for i=1,l do
			if unexplored_nodes[{i,1}] == 1 and map[{i,1}] == 1 then
				table.insert(islands,torch.zeros(l,w))
				if method==1 then
					flood_fill(unexplored_nodes,islands[#islands],i,1)
				elseif method==2 then
					flood_fill2(unexplored_nodes,islands[#islands],i,1)
				elseif method==3 then
					flood_fill3(unexplored_nodes,islands[#islands],i,1)
				end
			end
		end	
		for j=2,w do
			if unexplored_nodes[{1,j}] == 1 and map[{1,j}] == 1 then
				table.insert(islands,torch.zeros(l,w))
				if method==1 then
					flood_fill(unexplored_nodes,islands[#islands],1,j)
				elseif method==2 then
					flood_fill2(unexplored_nodes,islands[#islands],1,j)
				elseif method==3 then
					flood_fill3(unexplored_nodes,islands[#islands],1,j)
				end
			end
		end	

	end


	return islands
end

