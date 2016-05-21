require 'torch'
require 'math'
require 'move_enumerator'
ffi = require('ffi')
require 'bit'

local tak = torch.class('tak')

-- N.B.: The "making_a_copy" argument is used when making a fast clone of a tak game,
-- which is helpful in the AI tree search.
function tak:__init(size,making_a_copy)

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

	-- Index 1:   board position
	-- Index 2:   height in stack
	-- Index 3:   player owning piece (1 for player 1, 2 for player 2)
	-- Index 4:   type of stone on this square (1 for flat, 2 for standing, 3 for cap)
	-- values: 
		-- 0 means 'there is no stone of this description here'
		-- 1 means 'there is a stone of this description here'
		-- e.g, if self.board[i][1][2][3] = 1, that means,
		--      at position (1,3,1), player 2 has a capstone. 
	self.board = {} 
	self.em = {0,0,0}
	self.f = {1,0,0}
	self.s = {0,1,0}
	self.c = {0,0,1}
	for i=1,self.size*self.size do
		self.board[i] = {}
		for k=1,self.max_height do
			self.board[i][k] = {self.em,self.em}
		end
	end

	-- convenience variable for keeping track of the topmost entry in each position
	self.heights = {}
	for i=1,self.size*self.size do
		self.heights[i] = 0
	end

	self.ply = 0	-- how many plys have elapsed since the start of the game?
	self.move_history_ptn = {}
	self.move_history_idx = {}
	self.board_top = {} 
	for i=1,self.size*self.size do
		self.board_top[i] = {self.em,self.em}
	end

	self.empty_squares = {}
	for i=1,self.size*self.size do
		self.empty_squares[i] = 1
	end
	self.num_empty_squares = self.size*self.size

	self.flattening_history = {}
	self.legal_moves_by_ply = {}

	--sbsd: stacks_by_sum_and_distance
	--sbsd1: when the last stone is a cap crushing a wall
	self.move2ptn, self.ptn2move, _, _, _, _, _, self.sbsd, self.sbsd1 = ptn_moves(self.carry_limit)

	self.top_walls = self:make_filled_table(0)
	self.blocks = self:make_filled_table(0)

	self.is_up_boundary = {}
	self.is_down_boundary = {}
	self.is_left_boundary = {}
	self.is_right_boundary = {}
	for i=1,self.size*self.size do
		self.is_up_boundary[i] = false
		self.is_down_boundary[i] = false
		self.is_right_boundary[i] = false
		self.is_left_boundary[i] = false
	end
	for i=1,self.size do
		self.is_up_boundary[self.size*self.size+i] = true
		self.is_down_boundary[-i+1] = true
		self.is_right_boundary[1 + i*self.size] = true
		self.is_left_boundary[self.size*(i-1)] = true
	end


	self.l2i = {'a','b','c','d','e','f','g','h'}
	self.pos = {}
	self.pos2index = {}
	self.x = {}
	self.y = {}
	self.has_left = {}
	self.has_right = {}
	self.has_up = {}
	self.has_down = {}
	for i=1,self.size do
		for j=1,self.size do
			self.x[i+self.size*(j-1)] = i
			self.y[i+self.size*(j-1)] = j
			if i > 1 then 
				self.has_left[i+self.size*(j-1)] = true 
			else
				self.has_left[i+self.size*(j-1)] = false
			end
			if i < self.size then 
				self.has_right[i+self.size*(j-1)] = true 
			else
				self.has_right[i+self.size*(j-1)] = false
			end
			if j > 1 then 
				self.has_down[i+self.size*(j-1)] = true 
			else
				self.has_down[i+self.size*(j-1)] = false
			end
			if j < self.size then 
				self.has_up[i+self.size*(j-1)] = true 
			else
				self.has_up[i+self.size*(j-1)] = false
			end
			self.pos[i+self.size*(j-1)] = self.l2i[i] .. j
			self.pos2index[self.l2i[i] .. j] = i+self.size*(j-1)
		end
	end

	self.explored = {}
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
	self.check_stack_moves_time = 0
	self.execute_move_time = 0
	self.flood_fill_time = 0
	self.undo_time = 0
	self.road_check_time = 0
	value_of_node_time = 0
end

function tak:print_debug_times()
	print('undo time: \t' .. self.undo_time)
	print('get legal moves time: \t' .. self.get_legal_moves_time)
	print('check stack moves time: \t' .. self.check_stack_moves_time)
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

	local most_recent_move = self.move_history_ptn[#self.move_history_ptn]
	self.move_history_ptn[#self.move_history_ptn] = nil
	self.move_history_idx[#self.move_history_idx] = nil
	self.legal_moves_by_ply[#self.legal_moves_by_ply] = nil

	self:undo_move(most_recent_move,true,true)

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
	copy.em = self.em
	copy.f  = self.f
	copy.s  = self.s
	copy.c  = self.c
	copy.heights = deepcopy(self.heights)
	copy.empty_squares = deepcopy(self.empty_squares)
	--[[copy.board = deepcopy(self.board)
	copy.board_top = deepcopy(self.board_top)]]
	copy.board = {}
	copy.board_top = {}
	for i=1,self.size*self.size do
		copy.board[i] = {}
		for k=1,self.max_height do
			copy.board[i][k] = {self.board[i][k][1],self.board[i][k][2]}
		end
		copy.board_top[i] = {self.board_top[i][1], self.board_top[i][2]}
	end
	copy.blocks = {}
	copy.top_walls = {}
	copy.ply = self.ply
	copy.player_pieces = deepcopy(self.player_pieces)
	copy.player_caps = deepcopy(self.player_caps)
	--[[copy.move_history_ptn = deepcopy(self.move_history_ptn)
	copy.move_history_idx = deepcopy(self.move_history_idx)
	copy.legal_moves_by_ply = deepcopy(self.legal_moves_by_ply)]]
	copy.move_history_ptn = {}
	copy.move_history_idx = {}
	copy.legal_moves_by_ply = {}
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
	copy.flattening_history = deepcopy(self.flattening_history)
	copy.pos = self.pos
	copy.pos2index = self.pos2index
	copy.x = self.x 
	copy.y = self.y 
	copy.has_left = self.has_left
	copy.has_right = self.has_right
	copy.has_up = self.has_up
	copy.has_down = self.has_down
	copy.is_left_boundary = self.is_left_boundary
	copy.is_right_boundary = self.is_right_boundary
	copy.is_up_boundary = self.is_up_boundary
	copy.is_down_boundary = self.is_down_boundary
	copy.explored = {}
	return copy
end

function tak:deep_clone()
	local copy = tak.new(self.size)
	copy:play_game_from_ptn(self:game_to_ptn(),true)
	return copy
end

function tak:get_empty_squares()
	return self.empty_squares, self.board_top
end


function tak:check_stack_moves(legal_moves_ptn,player,i,pos)
	local start_time = os.clock()
	local hand = math.min(self.heights[i],self.size)
	local top_is_cap = self.board_top[i][player][3] == 1
	local seqs, dist, x

	local sbsd, sbsd1 = self.sbsd, self.sbsd1

	dist = 0
	x = i - 1
	while (not(self.is_left_boundary[x]) and not(self.blocks[x]) and dist<hand) do
		dist = dist + 1
		x = x - 1
	end
	if dist<hand and not(self.is_left_boundary[x]) and top_is_cap and self.top_walls[x] then 
		dist = dist + 1
		seqs = sbsd1[hand][dist]
	else
		seqs = sbsd[hand][dist]
	end
	if dist>0 then
		local n=#legal_moves_ptn
		local N = #seqs
		for m=1,N do
			n = n + 1
			legal_moves_ptn[n] = seqs[m][1] .. pos .. '<' .. seqs[m][2]
		end
	end

	dist = 0
	x = i - self.size
	while (x > 0 and not(self.blocks[x]) and dist<hand) do 
		dist = dist + 1
		x = x - self.size
	end
	if dist<hand and x > 0 and top_is_cap and self.top_walls[x] then 
		dist = dist + 1
		seqs = sbsd1[hand][dist]
	else
		seqs = sbsd[hand][dist]
	end
	if dist>0 then
		local n=#legal_moves_ptn
		local N = #seqs
		for m=1,N do
			n = n + 1
			legal_moves_ptn[n] = seqs[m][1] .. pos .. '-' .. seqs[m][2]
		end
	end


	dist = 0
	x = i + 1
	while (not(self.is_right_boundary[x]) and not(self.blocks[x]) and dist<hand) do 
		dist = dist + 1
		x = x + 1
	end
	if dist<hand and not(self.is_right_boundary[x]) and top_is_cap and self.top_walls[x] then 
		dist = dist + 1
		seqs = sbsd1[hand][dist]
	else
		seqs = sbsd[hand][dist]
	end
	if dist>0 then
		local n=#legal_moves_ptn
		local N = #seqs
		for m=1,N do
			n = n + 1
			legal_moves_ptn[n] = seqs[m][1] .. pos .. '>' .. seqs[m][2]
		end
	end


	dist = 0
	x = i + self.size
	while (not(self.is_up_boundary[x]) and not(self.blocks[x]) and dist<hand) do 
		dist = dist + 1
		x = x + self.size
	end
	if dist<hand and not(self.is_up_boundary[x]) and top_is_cap and self.top_walls[x] then 
		dist = dist + 1
		seqs = sbsd1[hand][dist]
	else
		seqs = sbsd[hand][dist]
	end
	if dist>0 then
		local n=#legal_moves_ptn
		local N = #seqs
		for m=1,N do
			n = n + 1
			legal_moves_ptn[n] = seqs[m][1] .. pos .. '+' .. seqs[m][2]
		end
	end

	self.check_stack_moves_time = self.check_stack_moves_time + (os.clock() - start_time)
end

function tak:get_legal_moves(player)

	local legal_moves_ptn = {}

	local start_time = os.clock()

	local empty, player_pieces, player_caps, board_top, pos, ply = self.empty_squares, self.player_pieces, self.player_caps, self.board_top, self.pos, self.ply
	local control
	local board_size = self.size*self.size

	for i=1,board_size do
		self.blocks[i] = (board_top[i][1] == self.s or board_top[i][1] == self.c
				or board_top[i][2] == self.s or board_top[i][2] == self.c)
		self.top_walls[i] = board_top[i][1] == self.s or board_top[i][2] == self.s
	end

	for i=1,board_size do
		if empty[i]==1 and ply > 1 then
			if player_pieces[player] > 0 then
				legal_moves_ptn[#legal_moves_ptn+1] = 'f' .. pos[i]
				legal_moves_ptn[#legal_moves_ptn+1] = 's' .. pos[i]
			end
			if player_caps[player] > 0 then
				legal_moves_ptn[#legal_moves_ptn+1] = 'c' .. pos[i]
			end
		elseif ply > 1 then
			if not(board_top[i][player] == self.em) then
				self:check_stack_moves(legal_moves_ptn,player,i,pos[i])
			end
		elseif empty[i]==1 then
			legal_moves_ptn[#legal_moves_ptn+1] = 'f' .. pos[i]
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
	--[[if move_ptn=='undo' then 
		self:undo()
		return true
	elseif move_ptn=='undo2' then
		self:undo()
		self:undo()
		return true
	end]]

	--[[if type(move_ptn) == 'number' then move_ptn = self.move2ptn[move_ptn] end
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
	end]]

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

	table.insert(self.move_history_ptn,ptn)
	table.insert(self.move_history_idx,self.ptn2move[ptn])

	local move_type = string.sub(ptn,1,1)
	local i = self.pos2index[string.sub(ptn,2,3)]

	local flattening_flag = false
	if move_type == 'f' then
		self.heights[i] = 1
		self.board[i][1][player] = self.f 
		self.player_pieces[player] = self.player_pieces[player] - 1
		self.board_top[i][player] = self.board[i][1][player] 
		self.empty_squares[i] = 0
	elseif move_type == 's' then
		self.heights[i] = 1
		self.board[i][1][player] = self.s 		
		self.player_pieces[player] = self.player_pieces[player] - 1
		self.board_top[i][player] = self.board[i][1][player] 
		self.empty_squares[i] = 0
	elseif move_type == 'c' then
		self.heights[i] = 1
		self.board[i][1][player] = self.c 
		self.player_caps[player] = self.player_caps[player] - 1	
		self.board_top[i][player] = self.board[i][1][player] 
		self.empty_squares[i] = 0
	else
		-- oooh this is gonna be hard, especially the 'undo' run
		-- welcome to index magic and duct tape... but you're reading this code, so you already knew that
		stacksum = tonumber(move_type)
		stackdir = string.sub(ptn,4,4)
		stackstr = string.sub(ptn,5,#ptn)
		local h


		h = self.heights[i] - stacksum
		self.heights[i] = h
		if h == 0 then 
			self.board_top[i] = {self.em,self.em}
			self.empty_squares[i] = 1 
		else
			self.board_top[i] = self.board[i][h]
		end

		local del
		if stackdir == '<' then
			del = -1
		elseif stackdir == '+' then
			del = self.size
		elseif stackdir == '>' then
			del = 1
		elseif stackdir == '-' then
			del = -self.size
		end
		local x = i + del
		local d = 1
		local D = tonumber(string.sub(stackstr,d,d))
		local m, n
		m = 1
		for k=1,stacksum do

			self.empty_squares[x] = 0
			self.heights[x] = self.heights[x] + 1
			self.board[x][self.heights[x]] = self.board[i][h+k]
			self.board_top[x] = self.board[x][self.heights[x]]
			self.board[i][h+k] = {self.em,self.em}
			-- flattening logic
			if (k == stacksum and self.board_top[x][player][3] == 1 
				and self.heights[x] > 1) then
				local h2 = self.heights[x]
				if self.board[x][h2-1][player][2] == 1 then
					self.board[x][h2-1][player] = self.f
					flattening_flag = true
				elseif self.board[x][h2-1][3 - player][2] == 1 then
					self.board[x][h2-1][3 - player] = self.f
					flattening_flag = true
				end
			end

			if m == D then
				x = x + del
				m = 0
				d = d + 1
				D = tonumber(string.sub(stackstr,d,d))
			end
			m = m + 1
		end
	end

	self.ply = self.ply + 1
	self.execute_move_time = self.execute_move_time + (os.clock() - start_time)

	if not(flag) then
		self:populate_legal_moves_at_this_ply()
	end

	self:check_victory_conditions()
	table.insert(self.flattening_history,flattening_flag)

	return true
end


function tak:undo_move(move_ptn)

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

	local move_type = string.sub(ptn,1,1)
	local i = self.pos2index[string.sub(ptn,2,3)]

	local flattening_flag = false
	if move_type == 'f' then
		self.heights[i] = 0
		self.board[i][1][player] = self.em
		self.player_pieces[player] = self.player_pieces[player] + 1
		self.board_top[i][player] = self.em 
		self.empty_squares[i] = 1
	elseif move_type == 's' then
		self.heights[i] = 0
		self.board[i][1][player] = self.em 
		self.player_pieces[player] = self.player_pieces[player] + 1
		self.board_top[i][player] = self.em 
		self.empty_squares[i] = 1
	elseif move_type == 'c' then
		self.heights[i] = 0
		self.board[i][1][player] = self.em 
		self.player_caps[player] = self.player_caps[player] + 1	
		self.board_top[i][player] = self.em 
		self.empty_squares[i] = 1
	else
		-- oooh this is gonna be hard, especially the 'undo' run
		-- welcome to index magic and duct tape... but you're reading this code, so you already knew that
		stacksum = tonumber(move_type)
		stackdir = string.sub(ptn,4,4)
		stackstr = string.sub(ptn,5,#ptn)
		local h

		self.empty_squares[i] = 0
		h = self.heights[i] 

		local del
		if stackdir == '<' then
			del = -1
		elseif stackdir == '+' then
			del = self.size
		elseif stackdir == '>' then
			del = 1
		elseif stackdir == '-' then
			del = -self.size
		end
		local x = i + del
		local d = 1
		local D = tonumber(string.sub(stackstr,d,d))
		local m, n = D, 0
		for k=1,stacksum do
			self.board[i][h+n+m] = self.board[x][self.heights[x]]
			self.board[x][self.heights[x]] = {self.em,self.em}--{{0,0,0},{0,0,0}}
			self.heights[x] = self.heights[x] - 1
			-- unflattening logic
			if (k==stacksum and self.flattening_history[#self.flattening_history]) then
				if self.board[x][self.heights[x]][player][1] == 1 then
					self.board[x][self.heights[x]][player] = self.s --{0,1,0}
				elseif self.board[x][self.heights[x]][3 - player][1] == 1 then
					self.board[x][self.heights[x]][3 - player] = self.s --{0,1,0}
				end
			end
			if self.heights[x] > 0 then
				self.board_top[x] = self.board[x][self.heights[x]]
			else
				self.board_top[x] = {self.em,self.em}--{{0,0,0},{0,0,0}}
				self.empty_squares[x] = 1
			end
			if m == 1 and d < #stackstr then
				x = x + del
				d = d + 1
				n = n + D
				D = tonumber(string.sub(stackstr,d,d))
				m = D + 1
			end
			m = m - 1
		end

		self.heights[i] = h + stacksum
		self.board_top[i] = self.board[i][self.heights[i]]
	end

	self.flattening_history[#self.flattening_history] = nil
	return true
end


function tak:make_zero_table()
	return self:make_filled_table(0)
end

function tak:make_filled_table(n)
	local ntab = {}
	for i=1,self.size*self.size do
		ntab[i] = n
	end
	return ntab
end


local min, max = math.min, math.max

function tak:check_victory_conditions()
	local player_one_remaining = self.player_pieces[1] + self.player_caps[1]
	local player_two_remaining = self.player_pieces[2] + self.player_caps[2]

	-- if the game board is full or either player has run out of pieces, trigger end
	local empty, board_top = self:get_empty_squares()
	local end_is_nigh = false
	local explored = self.explored

	self.num_empty_squares = 0
	self.player_flats = {0,0}
	for i=1,self.size*self.size do
		explored[i] = false
		self.num_empty_squares = self.num_empty_squares + empty[i]
		if board_top[i][1][1] == 1 then 
			self.player_flats[1] = self.player_flats[1] + 1
		elseif board_top[i][2][1] == 1 then
			self.player_flats[2] = self.player_flats[2] + 1
		end
	end

	if self.num_empty_squares == 0 or player_one_remaining == 0 or player_two_remaining == 0 then
		end_is_nigh = true
	end

	-- let's find us some island information

	local start_time = os.clock()
	local island_sums, islands_minmax

	local x, y = self.x, self.y
	local has_left, has_right, has_down, has_up = self.has_left, self.has_right, self.has_down, self.has_up
	local minmax
	--local em, f, s, c = self.em, self.f, self.s, self.c

	local function flood_fill(i,player)
		if (not(explored[i]) and (board_top[i][player][1] == 1 or board_top[i][player][3] == 1) ) then
			explored[i] = true
			island_sums[player][#island_sums[player]] = island_sums[player][#island_sums[player]] + 1

			minmax[1] = min(x[i],minmax[1])
			minmax[2] = min(y[i],minmax[2])
			minmax[3] = max(x[i],minmax[3])
			minmax[4] = max(y[i],minmax[4])

			if has_left[i] and not(explored[i-1]) then
				flood_fill(i-1,player)
			end
			if has_right[i] and not(explored[i+1]) then
				flood_fill(i+1,player)
			end
			if has_down[i] and not(explored[i-self.size]) then
				flood_fill(i-self.size,player)
			end
			if has_up[i] and not(explored[i+self.size]) then
				flood_fill(i+self.size,player)
			end
		end
	end


	local p1_rw, p2_rw = false, false
	island_sums = {{},{}}
	islands_minmax = {{},{}}
	for i=1,self.size*self.size do
		if not(explored[i]) then
			if board_top[i][1][1] == 1 or board_top[i][1][3] == 1 then
				island_sums[1][#island_sums[1]+1] = 0
				islands_minmax[1][#islands_minmax[1]+1] = {self.x[i],self.y[i],
									   self.x[i],self.y[i]}
				minmax = islands_minmax[1][#islands_minmax[1]]
				flood_fill(i,1)
			elseif board_top[i][2][1] == 1 or board_top[i][2][3] == 1 then
				island_sums[2][#island_sums[2]+1] = 0
				islands_minmax[2][#islands_minmax[2]+1] = {self.x[i],self.y[i],
									   self.x[i],self.y[i]}
				minmax = islands_minmax[2][#islands_minmax[2]]
				flood_fill(i,2)
			end
		end
	end

	self.flood_fill_time = self.flood_fill_time + (os.clock() - start_time)
	self.island_sums, self.islands_minmax = island_sums,islands_minmax

	local p1_rw, p2_rw = false, false

	local start_time = os.clock()
	local j = 1
	while not(p1_rw) and j <= #self.island_sums[1] do
		if self.island_sums[1][j] >= self.size then
			p1_rw = (self.islands_minmax[1][j][1] == 1
					and self.islands_minmax[1][j][3] == self.size) or
					(self.islands_minmax[1][j][2] == 1 
					and self.islands_minmax[1][j][4] == self.size)
		end
		j = j + 1
	end
	j = 1
	while not(p2_rw) and j <= #self.island_sums[2] do
		if self.island_sums[2][j] >= self.size then
			p2_rw = (self.islands_minmax[2][j][1] == 1
					and self.islands_minmax[2][j][3] == self.size) or
					(self.islands_minmax[2][j][2] == 1 
					and self.islands_minmax[2][j][4] == self.size)
		end
		j = j + 1
	end

	self.road_check_time = self.road_check_time + (os.clock() - start_time)

	if p1_rw or p2_rw then
		self.win_type = 'R'
		if p1_rw and not(p2_rw) then
			self.winner = 1
		elseif p2_rw and not(p1_rw) then
			self.winner = 2
		else
			self.winner = self:get_player()
		end
	end

	-- if there was no road win, but the game is over, score it by flat win
	if not(p1_rw or p2_rw) and end_is_nigh then
		if self.player_flats[1] > self.player_flats[2] then
			self.winner = 1
			self.win_type = 'F'
		elseif self.player_flats[2] > self.player_flats[1] then
			self.winner = 2
			self.win_type = 'F'
		else
			self.winner = 0
			self.win_type = 'DRAW'
		end	
	end

	self.game_over = p1_rw or p2_rw or end_is_nigh

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
	local size, max_height
	size = math.sqrt(#board)
	max_height = #board[1]
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
			stacks[i][j] = notation_from_stack(board[i+size*(j-1)])
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
