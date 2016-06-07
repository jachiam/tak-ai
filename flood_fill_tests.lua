require 'tak_AI'
game = tak.new(5)
game:play_game_from_file('game.txt')

queue = {}
for j=1,game.board_size do queue[j] = 0 end

local min, max = math.min, math.max
function flood_fill_tests(switch)

	local island_sums
	local explored, board_top = game.explored, game.board_top
	for i=1,game.board_size do explored[i] = false end
	local x, y = game.x, game.y
	local has_left, has_right, has_down, has_up = game.has_left, game.has_right, game.has_down, game.has_up
	local min_x, max_x, min_y, max_y, sum
	local p1_rw, p2_rw = false, false

	local function flood_fill1(j,player)
		if (not(explored[j]) and (board_top[j][player][1] == 1 or board_top[j][player][3] == 1) ) then
			explored[j] = true
			sum = sum + 1

			min_x = min(x[j],min_x)
			max_x = max(x[j],max_x)
			min_y = min(y[j],min_y)
			max_y = max(y[j],max_y)

			if has_left[j] and not(explored[j-1]) then
				flood_fill1(j-1,player)
			end
			if has_right[j] and not(explored[j+1]) then
				flood_fill1(j+1,player)
			end
			if has_down[j] and not(explored[j-game.size]) then
				flood_fill1(j-game.size,player)
			end
			if has_up[j] and not(explored[j+game.size]) then
				flood_fill1(j+game.size,player)
			end
		end
	end

	local queue = queue
	local function flood_fill2(start,player)
		local pointer = 1
		local end_of_queue = 1
		queue[1] = start
		repeat
			local j = queue[pointer]
			if (not(explored[j]) and (board_top[j][player][1] == 1 or board_top[j][player][3] == 1) ) then
				explored[j] = true
				sum = sum + 1

				min_x = min(x[j],min_x)
				max_x = max(x[j],max_x)
				min_y = min(y[j],min_y)
				max_y = max(y[j],max_y)

				if has_left[j] and not(explored[j-1]) then
					end_of_queue = end_of_queue + 1
					queue[end_of_queue] = j - 1
				end
				if has_right[j] and not(explored[j+1]) then
					end_of_queue = end_of_queue + 1
					queue[end_of_queue] = j + 1
				end
				if has_down[j] and not(explored[j-game.size]) then
					end_of_queue = end_of_queue + 1
					queue[end_of_queue] = j - game.size
				end
				if has_up[j] and not(explored[j+game.size]) then
					end_of_queue = end_of_queue + 1
					queue[end_of_queue] = j + game.size
				end
			end
			pointer = pointer + 1
		until pointer > end_of_queue
	end


	local function flood_fill(j,player)
		if switch==1 then
			flood_fill1(j,player)
		elseif switch==2 then
			flood_fill2(j,player)
		end
	end

	local p1_rw, p2_rw = false, false
	local dim1, dim2 = 0,0
	local dimsum1, dimsum2 = 0,0
	local p1_isles, p2_isles = {},{}
	for i=1,game.board_size do
		if not(explored[i]) then
			if board_top[i][1][1] == 1 or board_top[i][1][3] == 1 then
				sum = 0
				min_x, max_x, min_y, max_y = game.x[i], game.x[i], game.y[i], game.y[i]
				flood_fill(i,1)
				p1_isles[#p1_isles+1] = sum
				dim1 = max(max_x - min_x, max_y - min_y, dim1)
				dimsum1 = dimsum1 + dim1
			elseif board_top[i][2][1] == 1 or board_top[i][2][3] == 1 then
				sum = 0
				min_x, max_x, min_y, max_y = game.x[i], game.x[i], game.y[i], game.y[i]
				flood_fill(i,2)
				p2_isles[#p2_isles+1] = sum
				dim2 = max(max_x - min_x, max_y - min_y, dim2)
				dimsum2 = dimsum2 + dim1
			end
		end
	end
	
	p1_rw = dim1 == game.size - 1
	p2_rw = dim2 == game.size - 1

	return p1_rw, p2_rw, p1_isles, p2_isles
end

function test1()
	for j=1,100000 do flood_fill_tests(1) end
end

function test2()
	for j=1,100000 do flood_fill_tests(2) end
end

test1()
test2()
