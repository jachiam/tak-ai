require 'torch'
require 'math'
require 'move_enumerator'

local tak = torch.class('tak')

-- N.B.: The "making_a_copy" argument is used when making a fast clone of a tak game,
-- which is helpful in the AI tree search.
function tak:__init(size,making_a_copy)

	self.get_all_islands = true

	self.verbose = false
	self.size = size or 5
	if self.size == 3 then
		self.piece_count = 10
		self.cap_count = 0
	elseif self.size == 4 then
		self.piece_count = 15
		self.cap_count = 0
	elseif self.size == 5 then
		self.piece_count = 21 
		self.cap_count = 1
	elseif self.size == 6 then
		self.piece_count = 30
		self.cap_count = 1
	elseif self.size == 7 then
		self.piece_count = 40
		self.cap_count = 2
	elseif self.size == 8 then
		self.piece_count = 50
		self.cap_count = 2
	else
		print 'Invalid size'
		return
	end
	
	self.carry_limit = self.size
	self.max_height = 2*self.piece_count + 1

	-- DEBUG AND CLOCKING
	self:set_debug_times_to_zero()

	if making_a_copy then return end
	self.player_pieces = {self.piece_count, self.piece_count}
	self.player_caps = {self.cap_count, self.cap_count}

	-- Index 1&2: board position
	-- Index 3:   height in stack
	-- Index 4:   player owning piece (1 for player 1, 2 for player 2)
	-- Index 5:   type of stone on this square (1 for flat, 2 for standing, 3 for cap)
	-- values: 
		-- 0 means 'there is no stone of this description here'
		-- 1 means 'there is a stone of this description here'
		-- e.g, if self.board[1][3][1][2][3] = 1, that means,
		--      at position (1,3,1), player 2 has a capstone. 
	self.board = {} 
	for i=1,self.size do
		self.board[i] = {}
		for j=1, self.size do
			self.board[i][j] = {}
			for k=1,self.max_height do
				self.board[i][j][k] = {{0,0,0},{0,0,0}}
			end
		end
	end

	-- convenience variable for keeping track of the topmost entry in each position
	-- self.heights[4][2] = 0 means, position (4,2) is empty.
	-- self.heights[4][2] = 3 means, position (4,2) has a stack of size 3.
	self.heights = {}
	for i=1, self.size do 
		self.heights[i] = {}
		for j=1, self.size do
			self.heights[i][j] = 0
		end
	end

	self.ply = 0	-- how many plys have elapsed since the start of the game?
	self.move_history_ptn = {}
	self.move_history_idx = {}
	self.board_top = {} 
	for i=1,self.size do
		self.board_top[i] = {}
		for j=1, self.size do
			self.board_top[i][j] = {{0,0,0},{0,0,0}}
		end
	end

	self.empty_squares = {}
	for i=1,self.size do
		self.empty_squares[i] = {}
		for j=1, self.size do
			self.empty_squares[i][j] = 1
		end
	end
	self.num_empty_squares = self.size*self.size

	self.flattening_history = {}
	self.legal_moves_by_ply = {}

	--sbsd: stacks_by_sum_and_distance
	--sbsd1: when the last stone is a cap crushing a wall
	self.move2ptn, self.ptn2move, _, _, _, _, _, self.sbsd, self.sbsd1 = ptn_moves(self.carry_limit)

	self:populate_legal_moves_at_this_ply()

	self.game_over = false
	self.winner = 0
	self.win_type = 'NA'

	self.island_sums = {{},{}}
	self.islands_minmax = {{},{}}
	self.player_flats = {0,0}

end



function tak:get_history()
	return self.move_history_ptn
end

function tak:get_i2n(i)
	return self.move2ptn[i]
end

function tak:set_debug_times_to_zero()
	self.get_legal_moves_time = 0
	self.execute_move_time = 0
	self.flood_fill_time = 0
	self.undo_time = 0
	self.road_check_time = 0
	value_of_node_time = 0
end

function tak:print_debug_times()
	print('undo time: \t' .. self.undo_time)
	print('get legal moves time: \t' .. self.get_legal_moves_time)
	print('execute move time: \t' .. self.execute_move_time)
	print('flood fill time: \t' .. self.flood_fill_time)
	print('road check time: \t' .. self.road_check_time)
	print('value of node time: \t' .. value_of_node_time)

end

function tak:is_terminal()
	return not(self.win_type == 'NA')
end

function tak:undo()

	local start_time = os.clock()
	if self.ply == 0 then
		return
	end
	self.ply = self.ply - 1
	if self.game_over then
		self.game_over = false
		self.winner = 0
		self.win_type = 'NA'
	end

	most_recent_move = self.move_history_ptn[#self.move_history_ptn]
	self.move_history_ptn[#self.move_history_ptn] = nil
	self.move_history_idx[#self.move_history_idx] = nil
	self.legal_moves_by_ply[#self.legal_moves_by_ply] = nil

	self:make_move(most_recent_move,true,true)

	self.undo_time = self.undo_time + os.clock() - start_time

end

function tak:reset()
	self:__init(self.size)
end

function tak:clone(deep)
	if deep then
		return self:deep_clone()
	else
		return self:fast_clone()
	end
end

function tak:fast_clone()
	local copy = tak.new(self.size,true)
	copy.board = deepcopy(self.board)
	copy.heights = deepcopy(self.heights)
	copy.board_top = deepcopy(self.board_top)
	copy.empty_squares = deepcopy(self.empty_squares)
	copy.ply = self.ply
	copy.player_pieces = deepcopy(self.player_pieces)
	copy.player_caps = deepcopy(self.player_caps)
	copy.move_history_ptn = deepcopy(self.move_history_ptn)
	copy.move_history_idx = deepcopy(self.move_history_idx)
	copy.legal_moves_by_ply = deepcopy(self.legal_moves_by_ply)
	copy.game_over = self.game_over
	copy.winner = self.winner
	copy.win_type = self.win_type
	copy.move2ptn = self.move2ptn
	copy.ptn2move = self.ptn2move
	copy.sbsd = self.sbsd
	copy.sbsd1 = self.sbsd1
	copy.island_sums = {{},{}}
	copy.islands_minmax = {{},{}}
	copy.player_flats = {0,0}
	copy.flattening_history = {}
	return copy
end

function tak:deep_clone()
	local copy = tak.new(self.size)
	copy:play_game_from_ptn(self:game_to_ptn(),true)
	return copy
end

function tak:board_to_TPS()

	local function stack2str(stack)
		str = ''
		for k=1,self.max_height do
			for l=1,2 do
				if stack[k][{l,1}]==1 then
					str = str .. l
				elseif stack[k][{l,2}]==1 then
					str = str .. l ..'S'
				elseif stack[k][{l,3}]==1 then
					str = str .. l ..'C'
				end
			end
			if str[#str] == 'S' or str[#str] == 'C' then
				return str
			end
		end
		return str
	end

	tps = '[ '
	for i=1,self.size do
		for j=1,self.size do
			stack = self.board[j][self.size + 1 - i]
			if stack:sum() == 0 then
				tps = tps .. 'x,'
			else
				tps = tps .. stack2str(stack) .. ','
			end
		end
		if i < self.size then
			tps = tps .. '/'
		end
	end

	tps = tps .. ' '.. self:get_player() .. ' ]'

	return tps
end

function tak:get_empty_squares()
	return self.empty_squares, self.board_top
end


function tak:get_legal_moves(player)

	local legal_moves_ptn = {}
	local empty_squares, board_top = self:get_empty_squares()
	local letters = {'a','b','c','d','e','f','g','h'}

	local start_time = os.clock()

	local blocks = {}
	local top_walls = {}
	for i=1,self.size do
		blocks[i] = {}
		top_walls[i] = {}
		for j=1, self.size do
			blocks[i][j] = (self.board_top[i][j][1][2] == 1 or self.board_top[i][j][1][3] == 1
					or self.board_top[i][j][2][2] == 1 or self.board_top[i][j][2][3] == 1)
			top_walls[i][j] = (self.board_top[i][j][1][2] == 1 or self.board_top[i][j][2][2] == 1)
		end
	end

	local function add_stack_moves(pos,dir,seqs)
		if not(seqs == nil) then
			for m=1,#seqs do
				table.insert(legal_moves_ptn, seqs[m][1] .. pos .. dir .. seqs[m][2])
			end
		end
	end

	-- <magic>
	local function check_stack_moves(i,j,pos)
		-- hand size, or, how many stones we can take from this stack
		local hand = self.heights[i][j]
		if hand > self.size then hand = self.size end

		local blocked = {false, false, false, false}
		local dirs = {'<', '-', '>', '+'}
		local dist = {0, 0, 0, 0}
		local del = {{-1,0},{0,-1},{1,0},{0,1}}

		local top_is_cap = board_top[i][j][player][3] == 1

		local seqs

		for k=1,4 do
			local x,y = i + del[k][1],j + del[k][2]
			if x > 0 and y > 0 and x<= self.size and y <= self.size then 
				blocked[k] = blocks[x][y] 
			end
			while (not(blocked[k]) 
				and x > 0 and y > 0 
				and x <= self.size and y <= self.size 
				and dist[k]< hand) do
				dist[k] = dist[k] + 1
				x = x + del[k][1]
				y = y + del[k][2]
				if x > 0 and y > 0 and x<= self.size and y <= self.size then 
					blocked[k] = blocks[x][y] 
				end
			end
			if blocked[k] then
				if not(top_is_cap) then
					seqs = self.sbsd[hand][dist[k]]
				else
					local dest = {i + del[k][1]*(dist[k]+1), j + del[k][2]*(dist[k]+1)}
					if top_walls[dest[1]][dest[2]] then
						dist[k] = dist[k] + 1
						seqs = self.sbsd1[hand][math.min(hand,dist[k])]
					else
						seqs = self.sbsd[hand][dist[k]]
					end
				end
			else
				seqs = self.sbsd[hand][dist[k]]
			end
			if dist[k] > 0 then
				add_stack_moves(pos,dirs[k],seqs)
			end
		end		
	end
	-- </magic>

	local pos, control

	for i=1,self.size do
		for j=1,self.size do
			pos = letters[i] .. j
			if empty_squares[i][j]==1 and self.ply > 1 then
				if self.player_pieces[player] > 0 then
					table.insert(legal_moves_ptn, 'f' .. pos)
					table.insert(legal_moves_ptn, 's' .. pos)
				end
				if self.player_caps[player] > 0 then
					table.insert(legal_moves_ptn, 'c' .. pos)
				end
			elseif self.ply > 1 then
				control = (board_top[i][j][player][1] 
						+ board_top[i][j][player][2] 
						+ board_top[i][j][player][3])
				if control > 0 then
					check_stack_moves(i,j,pos)
				end
			elseif empty_squares[i][j]==1 then
				table.insert(legal_moves_ptn,'f' .. pos)
			end
		end
	end

	local legal_moves_check = {}
	for i=1,#legal_moves_ptn do
		legal_moves_check[legal_moves_ptn[i]] = true
	end

	self.get_legal_moves_time = self.get_legal_moves_time + (os.clock() - start_time)
	
	return legal_moves_ptn, legal_moves_check
end


function tak:get_legal_move_table()
	return self.legal_moves_by_ply[#self.legal_moves_by_ply][2]
end

function tak:get_legal_move_mask(as_bool)
	local mask = torch.zeros(#self.move2ptn)
	local legal = self:get_legal_move_table()
	for i=1,#legal do mask[self.ptn2move[legal[i]]] = 1 end
	if as_bool then mask = mask:byte() end
	return mask
end


function tak:get_player()
	-- self.ply says how many plys have been played, starts at 0
	return self.ply % 2 + 1
end

function tak:populate_legal_moves_at_this_ply()
	local player = self:get_player()
	if #self.legal_moves_by_ply < self.ply+1 then
		local legal_moves_ptn, legal_moves_check = self:get_legal_moves(player)
		table.insert(self.legal_moves_by_ply,{player,legal_moves_ptn,legal_moves_check})
	end
end


function tak:make_move(move_ptn,flag,undo)
	if move_ptn=='undo' then 
		self:undo()
		return true
	elseif move_ptn=='undo2' then
		self:undo()
		self:undo()
		return true
	end

	if type(move_ptn) == 'number' then move_ptn = self.move2ptn[move_ptn] end
	local move_ptn = string.lower(move_ptn)
	if move_ptn == string.match(move_ptn,'%a%d') then
		move_ptn = 'f' .. move_ptn
	elseif move_ptn == string.match(move_ptn,'%a%d[<>%+%-]') then
		move_ptn = '1' .. move_ptn .. '1'
	elseif move_ptn == string.match(move_ptn,'%d%a%d[<>%+%-]') then
		move_ptn = move_ptn .. string.sub(move_ptn,1,1)
	end
	
	if self.ptn2move[move_ptn] == nil then
		print 'Did not recognize move.'
		return false
	elseif self.game_over and not(undo) then
		if self.verbose then print 'Game is over.' end
		return false
	elseif self.legal_moves_by_ply[#self.legal_moves_by_ply][3][move_ptn] == nil and not(undo) then
		print('Tried move ' .. move_ptn)
		print 'Move is illegal.'
		return false
	end

	local start_time = os.clock()
	local ptn = move_ptn

	-- on the first turn of each player, they play a piece belonging to
	-- the opposite player
	local player
	if self.ply < 2 then
		player = 2 - self.ply
	else
		player = self:get_player()
	end

	--if undo then player = 3 - player end

	if not(undo) then
		table.insert(self.move_history_ptn,ptn)
		table.insert(self.move_history_idx,self.ptn2move[ptn])
	end
	move_type = string.sub(ptn,1,1)
	letter = string.sub(ptn,2,2)
	local l2i = {a = 1, b = 2, c = 3, d = 4, e = 5, f = 6, g = 7, h = 8}
	i = l2i[letter]
	j = tonumber(string.sub(ptn,3,3))


	local flattening_flag = false
	if move_type == 'f' then
		if not(undo) then
			self.heights[i][j] = 1
			self.board[i][j][1][player][1] = 1
			self.player_pieces[player] = self.player_pieces[player] - 1
			self.board_top[i][j][player][1] = 1
			self.empty_squares[i][j] = 0
		else
			self.heights[i][j] = 0
			self.board[i][j][1][player][1] = 0
			self.player_pieces[player] = self.player_pieces[player] + 1
			self.board_top[i][j][player][1] = 0
			self.empty_squares[i][j] = 1
		end
	elseif move_type == 's' then
		if not(undo) then
			self.heights[i][j] = 1
			self.board[i][j][1][player][2] = 1		
			self.player_pieces[player] = self.player_pieces[player] - 1
			self.board_top[i][j][player][2] = 1
			self.empty_squares[i][j] = 0
		else
			self.heights[i][j] = 0
			self.board[i][j][1][player][2] = 0
			self.player_pieces[player] = self.player_pieces[player] + 1
			self.board_top[i][j][player][2] = 0
			self.empty_squares[i][j] = 1
		end
	elseif move_type == 'c' then
		if not(undo) then
			self.heights[i][j] = 1
			self.board[i][j][1][player][3] = 1
			self.player_caps[player] = self.player_caps[player] - 1	
			self.board_top[i][j][player][3] = 1
			self.empty_squares[i][j] = 0
		else
			self.heights[i][j] = 0
			self.board[i][j][1][player][3] = 0
			self.player_caps[player] = self.player_caps[player] + 1	
			self.board_top[i][j][player][3] = 0
			self.empty_squares[i][j] = 1
		end
	else
		-- oooh this is gonna be hard, especially the 'undo' run
		-- welcome to index magic and duct tape... but you're reading this code, so you already knew that
		stacksum = tonumber(move_type)
		stackdir = string.sub(ptn,4,4)
		stackstr = string.sub(ptn,5,#ptn)
		local h

		if not(undo) then
			h = self.heights[i][j] - stacksum
			self.heights[i][j] = h
			if h == 0 then 
				self.board_top[i][j] = {{0,0,0},{0,0,0}}
				self.empty_squares[i][j] = 1 
			else
				self.board_top[i][j] = self.board[i][j][h]
			end
		else
			self.empty_squares[i][j] = 0
			h = self.heights[i][j] 
		end

		local del
		if stackdir == '<' then
			del = {-1,0}
		elseif stackdir == '+' then
			del = {0,1}
		elseif stackdir == '>' then
			del = {1,0}
		elseif stackdir == '-' then
			del = {0,-1}
		end
		local x,y = i+del[1],j+del[2]
		local d = 1
		local D = tonumber(string.sub(stackstr,d,d))
		local m, n
		if not(undo) then m = 1 else m = D; n = 0  end
		for k=1,stacksum do
			if not(undo) then
				self.empty_squares[x][y] = 0
				self.heights[x][y] = self.heights[x][y] + 1
				self.board[x][y][self.heights[x][y]] = self.board[i][j][h+k]
				self.board_top[x][y] = self.board[x][y][self.heights[x][y]]
				self.board[i][j][h+k] = {{0,0,0},{0,0,0}}
				-- flattening logic
				if (k == stacksum and self.board[x][y][self.heights[x][y]][player][3] == 1 
					and self.heights[x][y] > 1) then
					local h2 = self.heights[x][y]
					if self.board[x][y][h2-1][player][2] == 1 then
						self.board[x][y][h2-1][player] = {1,0,0}
						flattening_flag = true
					elseif self.board[x][y][h2-1][3 - player][2] == 1 then
						self.board[x][y][h2-1][3 - player] = {1,0,0}
						flattening_flag = true
					end
				end

				if m == D then
					x = x + del[1]
					y = y + del[2]
					m = 0
					d = d + 1
					D = tonumber(string.sub(stackstr,d,d))
				end
				m = m + 1
			else
				self.board[i][j][h+n+m] = self.board[x][y][self.heights[x][y]]
				--print('aight... ' .. x .. ', ' .. y .. ', ' .. self.heights[x][y])
				--print(h+n+m)
				--print(self.board[x][y][self.heights[x][y]])
				self.board[x][y][self.heights[x][y]] = {{0,0,0},{0,0,0}}
				self.heights[x][y] = self.heights[x][y] - 1
				-- unflattening logic
				if (k==stacksum and self.flattening_history[#self.flattening_history]) then
					if self.board[x][y][self.heights[x][y]][player][1] == 1 then
						self.board[x][y][self.heights[x][y]][player] = {0,1,0}
					elseif self.board[x][y][self.heights[x][y]][3 - player][1] == 1 then
						self.board[x][y][self.heights[x][y]][3 - player] = {0,1,0}
					end
				end
				if self.heights[x][y] > 0 then
					self.board_top[x][y] = self.board[x][y][self.heights[x][y]]
				else
					self.board_top[x][y] = {{0,0,0},{0,0,0}}
					self.empty_squares[x][y] = 1
				end
				if m == 1 and d < #stackstr then
					x = x + del[1]
					y = y + del[2]
					d = d + 1
					n = n + D
					D = tonumber(string.sub(stackstr,d,d))
					m = D + 1
				end
				m = m - 1
			end
		end

		if undo then
			self.heights[i][j] = h + stacksum
			self.board_top[i][j] = self.board[i][j][self.heights[i][j]]
		end
	end

	if not(undo) then
		self.ply = self.ply + 1
		self.execute_move_time = self.execute_move_time + (os.clock() - start_time)
	end

	if not(flag) then
		self:populate_legal_moves_at_this_ply()
	else
		if #self.legal_moves_by_ply < self.ply+1 then
			table.insert(self.legal_moves_by_ply,{})
		end
	end

	if not(undo) then
		self:check_victory_conditions()
		table.insert(self.flattening_history,flattening_flag)
	else
		self.flattening_history[#self.flattening_history] = nil
	end

	return true
end

function tak:make_zero_table()
	return self:make_filled_table(0)
end

function tak:make_filled_table(n)
	local ntab = {}
	for i=1,self.size do
		ntab[i] = {}
		for j=1,self.size do
			ntab[i][j] = n
		end
	end
	return ntab
end

function tak:check_victory_conditions()
	local player_one_remaining = self.player_pieces[1] + self.player_caps[1]
	local player_two_remaining = self.player_pieces[2] + self.player_caps[2]

	-- if the game board is full or either player has run out of pieces, trigger end
	local empty, board_top = self:get_empty_squares()
	local end_is_nigh = false

	self.num_empty_squares = 0
	self.player_flats = {0,0}
	for i=1,self.size do
		for j=1,self.size do
			self.num_empty_squares = self.num_empty_squares + empty[i][j]
			if board_top[i][j][1][1] == 1 then 
				self.player_flats[1] = self.player_flats[1] + 1
			elseif board_top[i][j][2][1] == 1 then
				self.player_flats[2] = self.player_flats[2] + 1
			end
		end
	end

	if self.num_empty_squares == 0 or player_one_remaining == 0 or player_two_remaining == 0 then
		end_is_nigh = true
	end

	local unexplored = self:make_filled_table(1)

	-- let's find us some island information

	local function get_islands(player)

		local start_time = os.clock()
		local island_sums, islands_minmax

		local function flood_fill(i,j)
			if ((board_top[i][j][player][1] == 1 or board_top[i][j][player][3] == 1) 
				and unexplored[i][j] == 1) then
				unexplored[i][j] = 0
				island_sums[#island_sums] = island_sums[#island_sums] + 1

				if i < islands_minmax[#islands_minmax][1] then
					islands_minmax[#islands_minmax][1] = i
				end
				if j < islands_minmax[#islands_minmax][2] then
					islands_minmax[#islands_minmax][2] = j
				end
				if i > islands_minmax[#islands_minmax][3] then
					islands_minmax[#islands_minmax][3] = i
				end
				if j > islands_minmax[#islands_minmax][4] then
					islands_minmax[#islands_minmax][4] = j
				end

				if i > 1 then
					flood_fill(i-1,j)
				end
				if i < self.size then
					flood_fill(i+1,j)
				end
				if j > 1 then
					flood_fill(i,j-1)
				end
				if j < self.size then
					flood_fill(i,j+1)
				end
			end
		end

		island_sums = {}
		islands_minmax = {}
		if self.get_all_islands then
			for i=1,self.size do
				for j=1,self.size do
					if (unexplored[i][j] == 1 and 
						(board_top[i][j][player][1] == 1 or board_top[i][j][player][3] == 1)) then
						table.insert(island_sums,0)
						table.insert(islands_minmax,{i,j,i,j})
						flood_fill(i,j)
					end
				end
			end
		else
			for i=1,self.size do
				if (unexplored[i][1] == 1 and 
					(board_top[i][1][player][1] == 1 or board_top[i][1][player][3] == 1)) then
					table.insert(island_sums,0)
					table.insert(islands_minmax,{i,j,i,j})
					flood_fill(i,1)
				end
			end
			for j=1,self.size do
				if (unexplored[1][j] == 1 and 
					(board_top[1][j][player][1] == 1 or board_top[1][j][player][3] == 1)) then
					table.insert(island_sums,0)
					table.insert(islands_minmax,{i,j,i,j})
					flood_fill(1,j)
				end
			end
		end

		self.flood_fill_time = self.flood_fill_time + (os.clock() - start_time)
		return island_sums, islands_minmax
	end


	local function check_road_wins()
		rw = {}
		local isle, a, b, c, d
		for player=1,2 do
			rw[player] = false
			local island_sums, islands_minmax = get_islands(player)
			self.islands_minmax[player] = islands_minmax

			local start_time = os.clock()
			j = 1
			while not(rw[player]) and j <= #island_sums do
				-- can't be a road if it doesn't have at least N stones in it
				if island_sums[j] >= self.size then
					rw[player] = (islands_minmax[j][1] == 1
							and islands_minmax[j][3] == self.size) or
							(islands_minmax[j][2] == 1 
							and islands_minmax[j][4] == self.size)
				end
				j = j + 1
			end

			self.island_sums[player] = island_sums
			self.road_check_time = self.road_check_time + (os.clock() - start_time)
		end
		return rw[1], rw[2]
	end

	local p1_rw, p2_rw = check_road_wins()
	local road_win = p1_rw or p2_rw



	if road_win then
		if p1_rw and not(p2_rw) then
			self.winner = 1
			self.win_type = 'R'
		elseif p2_rw and not(p1_rw) then
			self.winner = 2
			self.win_type = 'R'
		else
			self.winner = 0
			self.win_type = 'DRAW'
		end
	end

	-- if there was no road win, but the game is over, score it by flat win
	if not(road_win) and end_is_nigh then
		player_one_flats = 0
		player_two_flats = 0
		for i=1,self.size do
			for j=1, self.size do
				if board_top[i][j][1][1] == 1 then
					player_one_flats = player_one_flats + 1
				elseif board_top[i][j][2][1] == 1 then
					player_two_flats = player_two_flats + 1
				end 
			end
		end
		if player_one_flats > player_two_flats then
			self.winner = 1
			self.win_type = 'F'
		elseif player_two_flats > player_one_flats then
			self.winner = 2
			self.win_type = 'F'
		else
			self.winner = 0
			self.win_type = 'DRAW'
		end			
	end

	self.game_over = road_win or end_is_nigh

	if self.game_over then
		if self.winner == 1 then
			outstr = self.win_type .. ' - 0'
		elseif self.winner == 2 then
			outstr = '0 - ' .. self.win_type
		else
			outstr = '1/2 - 1/2'
		end
		-- print('GAME OVER: ' .. outstr)
		self.outstr = outstr
	end

	return self.game_over, self.winner, self.win_type, p1_rw, p2_rw

end


function tak:get_children()
	local legal = self.legal_moves_by_ply[#self.legal_moves_by_ply][2]
	-- slightly hacky lua black magic to reduce number of table rehashes, saves some time
	local children = {nil,nil,nil,nil,nil}
	for _,ptn in pairs(legal) do
		local copy = self:clone()
		copy:make_move(ptn)
		table.insert(children,copy)
	end

	return children, legal
end

function tak:generate_random_game(max_moves)
	for i=1,max_moves do
		legal = self.legal_moves_by_ply[#self.legal_moves_by_ply][2]
		move = torch.random(1,#legal)
		self:make_move(legal[move])
	end
end

function tak:simulate_random_game()
	while not(self.game_over) do
		legal = self.legal_moves_by_ply[#self.legal_moves_by_ply][2]
		if #legal == 0 then break end
		move = torch.random(1,#legal)
		self:make_move(legal[move])
	end
end

function tak:game_to_ptn(as_table)
	local game_ptn

	if as_table then
		game_ptn = {size = self.size}
	else
		game_ptn = '[Size "' .. self.size .. '"]\n\n'
	end

	for i=1,#self.move_history_ptn do
		
		ptn = self.move_history_ptn[i]

		ptn_tail = string.sub(ptn,2,#ptn)
		ptn_head = string.upper(string.sub(ptn,1,1))

		if as_table then
			game_ptn[i] = ptn_head .. ptn_tail
		else
			if (i+1) % 2 == 0 then
				j = (i + 1)/2
				game_ptn = game_ptn .. j .. '. '
			end
			game_ptn = game_ptn .. ptn_head .. ptn_tail .. ' '
			if (i+1) % 2 == 1 then
				game_ptn = game_ptn .. '\n'
			end
		end
	end
	return game_ptn
end

function tak:game_state_string()
	return self:game_to_ptn()
end

function tak:play_game_from_ptn(ptngame,quiet)
	if not(quiet) then
		print 'Playing the following game: '
		print(ptngame)
	end
	l,u = string.find(ptngame,"Size")
	size = tonumber(string.sub(ptngame,u+3,u+3))
	self:__init(size)
	iterator = string.lower(ptngame):gmatch("%w?%a%d[<>%+%-]?%d*")
	for ptn_move in iterator do
		self:make_move(ptn_move)
	end		
end

function tak:play_game_from_file(filename,quiet)
	local f = torch.DiskFile(filename)
	local gptn = f:readString('*a')
	f:close()
	self:play_game_from_ptn(gptn,quiet)
end

function tak:print_tak_board(mark_squares,just_top)
	if just_top then
		return self.print_any_tak_board(self.board_top,mark_squares,just_top)
	else
		return self.print_any_tak_board(self.board,mark_squares,just_top)
	end
end

function tak.print_any_tak_board(board,mark_squares,just_top)
	--local board = self.board
	--if just_top then board = self.board_top end

	--local size = self.size
	--local max_height = self.max_height
	local size, max_height
	if type(board) == 'table' then
		size = #board
		max_height = #board[1][1]
	else
		size = board:size(1)
		max_height = board:size(3)
	end
	local stacks = {}
	local widest_in_col = torch.zeros(size)

	local function notation_from_piece(piece)
		if piece[1][1] == 1 then
			return 'w'
		elseif piece[1][2] == 1 then
			return '[w]'
		elseif piece[1][3] == 1 then
			return '{w}'
		elseif piece[2][1] == 1 then
			return 'b'
		elseif piece[2][2] == 1 then
			return '[b]'
		elseif piece[2][3] == 1 then
			return '{b}'
		end
		return ''
	end

	local function notation_from_stack(stack)
		local stacknot = ''
		if just_top then
			return notation_from_piece(stack)
		end
		for k=1,max_height do
			stacknot = stacknot .. notation_from_piece(stack[k])
		end
		return stacknot
	end

	for i=1,size do
		stacks[i] = {}
		for j=1, size do
			--if self.heights[i][j] > 0 then
			stacks[i][j] = notation_from_stack(board[i][j])
			--else
			if stacks[i][j] == '' then
				stacks[i][j] = ' '
			end
			if #stacks[i][j] > widest_in_col[i] then
				widest_in_col[i] = #stacks[i][j]
			end
		end
	end

	local function pad(n)
		local p = ''
		for k=1,n do 
			p = p .. ' '
		end
		return p
	end

	-- pb: printed board
	-- ll: letter line
	-- bl: break line

	local pb = ''
	local wid = widest_in_col:sum() + 3*size + 1

	local letters = {'a','b','c','d','e','f','g','h'}
	local ll = '    '
	for i=1,size do
		ll = ll .. ' ' .. letters[i]
		for j=1, widest_in_col[i] do
			ll = ll .. ' '
		end
		ll = ll .. ' '
	end

	local bl = '+'
	if mark_squares then bl = '   ' .. bl end

	for i=1, size do
		for j=1, widest_in_col[i]+2 do
			bl = bl .. '-'
		end
		bl = bl .. '+'
	end

	bl = bl .. '\n'

	pb = pb .. bl
	for j=size,1,-1 do
		if mark_squares then 
			pb = pb .. j .. '  ' 
		end
	 	pb = pb .. '| '
		for i=1,size do		
			pb = pb .. stacks[i][j]
			p = pad(widest_in_col[i] - #stacks[i][j])
			pb = pb .. p .. ' | ' 
		end
		pb = pb .. '\n' .. bl
	end
	if mark_squares then pb = pb .. ll .. '\n' end

	return pb
end

function tak:move_test()
	local moves = game.legal_moves_by_ply[#game.legal_moves_by_ply][2]
	for i=1,#moves do
		print('Player to move is ' .. self:get_player())
		print('Length of legal_moves_by_ply is ' .. #game.legal_moves_by_ply)
		print('Trying move ' .. moves[i])
		check = self:make_move(moves[i])
		print(self:print_tak_board(true))
		print(self:print_tak_board(true,true))
		if not(check) then break end
		self:undo()
	end
end

return tak
