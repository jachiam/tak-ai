require 'torch'
require 'math'
require 'move_enumerator'
--ffi = require('ffi')
--require 'bit'

local min, max = math.min, math.max

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
	self.board_size = self.size*self.size

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

	self.top_walls = self:make_filled_table(false)
	self.blocks = self:make_filled_table(false)

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

	self.queue = {}
	for i=1,self.board_size do self.queue[i] = 0 end

	self.explored = {}
	self:generate_all_moves()
	self:populate_legal_moves_at_this_ply()

	self.game_over = false
	self.winner = 0
	self.win_type = 'NA'

	self.island_sums = {{},{}}
	self.num_islands = {0,0}
	self.island_max_dims = {0,0}
	self.island_len_sums = {0,0}
	self.player_flats = {0,0}
end

function tak:generate_all_moves()
	self.place_flat = {}
	self.place_wall = {}
	self.place_cap  = {}
	self.moves = {}
	self.moves1 = {}
	self.move2pos = {}
	self.is_place_flat = {}
	self.is_place_wall = {}
	self.is_place_cap  = {}
	self.move2stacksum = {}
	self.move2stackdel = {}
	self.move2stackstr = {}
	self.place_info = {f={self.f,1,0,false,false},s={self.s,1,0,true,true},c={self.c,0,1,true,false}}
	local move_type,ptn,stackdir,stackstr
	for i=1,#self.move2ptn do
		ptn = self.move2ptn[i]
		move_type = string.sub(ptn,1,1)
		self.is_place_flat[ptn] = move_type == 'f'
		self.is_place_wall[ptn] = move_type == 's'
		self.is_place_cap[ptn] = move_type == 'c'

		self.move2stacksum[ptn] = tonumber(move_type)
		if tonumber(move_type) then
			stackdir = string.sub(ptn,4,4)
			stackstr = string.sub(ptn,5,#ptn)
			if stackdir == '<' then self.move2stackdel[ptn] = -1
			elseif stackdir == '+' then self.move2stackdel[ptn] = self.size
			elseif stackdir == '>' then self.move2stackdel[ptn] = 1
			elseif stackdir == '-' then self.move2stackdel[ptn] = -self.size
			end
			self.move2stackstr[ptn] = stackstr
		end

		self.move2pos[ptn] = self.pos2index[string.sub(ptn,2,3)]
	end

	local dirs = {'<','+','>','-'}
	for i=1, self.board_size do
		self.place_flat[i] = 'f' .. self.pos[i]
		self.place_wall[i] = 's' .. self.pos[i]
		self.place_cap[i]  = 'c' .. self.pos[i]
		self.moves[i] = {}
		self.moves1[i] = {}
		for k=1,4 do
			self.moves[i][k] = {}
			self.moves1[i][k] = {}
			if (k==1 and self.has_left[i]) or (k==2 and self.has_up[i]) or (k==3 and self.has_right[i]) or (k==4 and self.has_down[i]) then
				for j=1,self.size do
					self.moves[i][k][j] = {}
					self.moves1[i][k][j] = {}
					for l=1,j do
						self.moves[i][k][j][l] = {}
						self.moves1[i][k][j][l] = {}
						local seqs = self.sbsd[j][l]
						for m=1,#seqs do
							self.moves[i][k][j][l][m] = seqs[m][1] .. self.pos[i] .. dirs[k] .. seqs[m][2]
						end
						local seqs1 = self.sbsd1[j][l]
						for m=1,#seqs1 do
							self.moves1[i][k][j][l][m] = seqs1[m][1] .. self.pos[i] .. dirs[k] .. seqs1[m][2]
						end
					end
				end
			end
		end
	end
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
	value_of_node_time = 0
end

function tak:print_debug_times()
	print('undo time: \t' .. self.undo_time)
	print('get legal moves time: \t' .. self.get_legal_moves_time)
	print('check stack moves time: \t' .. self.check_stack_moves_time)
	print('execute move time: \t' .. self.execute_move_time)
	print('flood fill time: \t' .. self.flood_fill_time)
	print('value of node time: \t' .. value_of_node_time)

end

function tak:is_terminal()
	return self.game_over
end

function tak:undo()

	--local start_time = os.clock()
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
	if #self.legal_moves_by_ply > self.ply + 1 then
		self.legal_moves_by_ply[#self.legal_moves_by_ply] = nil
	end

	self:undo_move(most_recent_move)

	--self.undo_time = self.undo_time + os.clock() - start_time

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
	copy.move_history_ptn = {}
	copy.legal_moves_by_ply = {}
	copy.game_over = self.game_over
	copy.winner = self.winner
	copy.win_type = self.win_type
	copy.move2ptn = self.move2ptn
	copy.ptn2move = self.ptn2move
	copy.sbsd = self.sbsd
	copy.sbsd1 = self.sbsd1
	copy.place_flat = self.place_flat
	copy.place_wall = self.place_wall
	copy.place_cap  = self.place_cap
	copy.moves      = self.moves
	copy.moves1     = self.moves1
	copy.island_sums = {{},{}}
	self.num_islands = {0,0}
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



function tak:check_stack_moves_dry(legal_moves_ptn,player,i)
	--local start_time = os.clock()
	local hand = min(self.heights[i],self.size)
	local top_is_cap = self.board_top[i][player][3] == 1
	local seqs, dist, x

	local moves, moves1 = self.moves[i], self.moves1[i]
	local n = #legal_moves_ptn

	if self.has_left[i] then
		dist = 0
		x = i - 1
		while (not(self.is_left_boundary[x]) and not(self.blocks[x]) and dist<hand) do
			dist = dist + 1
			x = x - 1
		end
		if top_is_cap and dist<hand and not(self.is_left_boundary[x]) and self.top_walls[x] then 
			dist = dist + 1
			seqs = moves1[1][hand][dist]
		else
			seqs = moves[1][hand][dist]
		end
		if hand == 1 and dist == 1 then
			n = n + 1
			--
		elseif dist>0 then
			local N = #seqs
			for m=1,N do
				n = n + 1
				--
			end
		end
	end

	if self.has_down[i] then
		dist = 0
		x = i - self.size
		while (x > 0 and not(self.blocks[x]) and dist<hand) do 
			dist = dist + 1
			x = x - self.size
		end
		if top_is_cap and dist<hand and x > 0 and self.top_walls[x] then 
			dist = dist + 1
			seqs = moves1[4][hand][dist]
		else
			seqs = moves[4][hand][dist]
		end
		if hand == 1 and dist == 1 then
			n = n + 1
			--
		elseif dist>0 then
			local N = #seqs
			for m=1,N do
				n = n + 1
				--
			end
		end
	end

	if self.has_right[i] then
		dist = 0
		x = i + 1
		while (not(self.is_right_boundary[x]) and not(self.blocks[x]) and dist<hand) do 
			dist = dist + 1
			x = x + 1
		end
		if top_is_cap and dist<hand and not(self.is_right_boundary[x]) and self.top_walls[x] then 
			dist = dist + 1
			seqs = moves1[3][hand][dist]
		else
			seqs = moves[3][hand][dist]
		end
		if hand == 1 and dist == 1 then
			n = n + 1
			--
		elseif dist>0 then
			local N = #seqs
			for m=1,N do
				n = n + 1
				--
			end
		end
	end

	if self.has_up[i] then
		dist = 0
		x = i + self.size
		while (not(self.is_up_boundary[x]) and not(self.blocks[x]) and dist<hand) do 
			dist = dist + 1
			x = x + self.size
		end
		if top_is_cap and dist<hand and not(self.is_up_boundary[x]) and self.top_walls[x] then 
			dist = dist + 1
			seqs = moves1[2][hand][dist]
		else
			seqs = moves[2][hand][dist]
		end
		if hand == 1 and dist == 1 then
			n = n + 1
			--
		elseif dist>0 then
			local N = #seqs
			for m=1,N do
				n = n + 1
				--
			end
		end
	end

	--self.check_stack_moves_time = self.check_stack_moves_time + (os.clock() - start_time)
end


function tak:get_legal_moves_dry(player)

	local legal_moves_ptn = {}

	--local start_time = os.clock()

	local empty, player_pieces, player_caps, board_top, pos, ply,board_size = self.empty_squares, self.player_pieces, self.player_caps, self.board_top, self.pos, self.ply, self.board_size

	for i=1,board_size do
		if empty[i]==1 and ply > 1 then
			if player_pieces[player] > 0 then
				--
				--
			end
			if player_caps[player] > 0 then
				--
			end
		elseif ply > 1 then
			if not(board_top[i][player] == self.em) then
				self:check_stack_moves(legal_moves_ptn,player,i)
			end
		elseif empty[i]==1 then
			--
		end
	end

	--self.get_legal_moves_time = self.get_legal_moves_time + (os.clock() - start_time)
	
	return legal_moves_ptn
end



function tak:check_stack_moves(legal_moves_ptn,player,i)
	--local start_time = os.clock()
	local hand = min(self.heights[i],self.size)
	local top_is_cap = self.board_top[i][player][3] == 1
	local seqs, dist, x

	local moves, moves1 = self.moves[i], self.moves1[i]
	local n = #legal_moves_ptn

	if self.has_left[i] then
		dist = 0
		x = i - 1
		while (not(self.is_left_boundary[x]) and not(self.blocks[x]) and dist<hand) do
			dist = dist + 1
			x = x - 1
		end
		if top_is_cap and dist<hand and not(self.is_left_boundary[x]) and self.top_walls[x] then 
			dist = dist + 1
			seqs = moves1[1][hand][dist]
		else
			seqs = moves[1][hand][dist]
		end
		if hand == 1 and dist == 1 then
			n = n + 1
			legal_moves_ptn[n] = seqs[1]
		elseif dist>0 then
			local N = #seqs
			for m=1,N do
				n = n + 1
				legal_moves_ptn[n] = seqs[m]
			end
		end
	end

	if self.has_down[i] then
		dist = 0
		x = i - self.size
		while (x > 0 and not(self.blocks[x]) and dist<hand) do 
			dist = dist + 1
			x = x - self.size
		end
		if top_is_cap and dist<hand and x > 0 and self.top_walls[x] then 
			dist = dist + 1
			seqs = moves1[4][hand][dist]
		else
			seqs = moves[4][hand][dist]
		end
		if hand == 1 and dist == 1 then
			n = n + 1
			legal_moves_ptn[n] = seqs[1]
		elseif dist>0 then
			local N = #seqs
			for m=1,N do
				n = n + 1
				legal_moves_ptn[n] = seqs[m]
			end
		end
	end

	if self.has_right[i] then
		dist = 0
		x = i + 1
		while (not(self.is_right_boundary[x]) and not(self.blocks[x]) and dist<hand) do 
			dist = dist + 1
			x = x + 1
		end
		if top_is_cap and dist<hand and not(self.is_right_boundary[x]) and self.top_walls[x] then 
			dist = dist + 1
			seqs = moves1[3][hand][dist]
		else
			seqs = moves[3][hand][dist]
		end
		if hand == 1 and dist == 1 then
			n = n + 1
			legal_moves_ptn[n] = seqs[1]
		elseif dist>0 then
			local N = #seqs
			for m=1,N do
				n = n + 1
				legal_moves_ptn[n] = seqs[m]
			end
		end
	end

	if self.has_up[i] then
		dist = 0
		x = i + self.size
		while (not(self.is_up_boundary[x]) and not(self.blocks[x]) and dist<hand) do 
			dist = dist + 1
			x = x + self.size
		end
		if top_is_cap and dist<hand and not(self.is_up_boundary[x]) and self.top_walls[x] then 
			dist = dist + 1
			seqs = moves1[2][hand][dist]
		else
			seqs = moves[2][hand][dist]
		end
		if hand == 1 and dist == 1 then
			n = n + 1
			legal_moves_ptn[n] = seqs[1]
		elseif dist>0 then
			local N = #seqs
			for m=1,N do
				n = n + 1
				legal_moves_ptn[n] = seqs[m]
			end
		end
	end

	--self.check_stack_moves_time = self.check_stack_moves_time + (os.clock() - start_time)
end


function tak:get_legal_moves(player)

	local legal_moves_ptn = {}

	--local start_time = os.clock()

	local empty, player_pieces, player_caps, board_top, pos, ply,board_size = self.empty_squares, self.player_pieces, self.player_caps, self.board_top, self.pos, self.ply, self.board_size

	for i=1,board_size do
		if empty[i]==1 and ply > 1 then
			if player_pieces[player] > 0 then
				legal_moves_ptn[#legal_moves_ptn+1] = self.place_flat[i]
				legal_moves_ptn[#legal_moves_ptn+1] = self.place_wall[i]
			end
			if player_caps[player] > 0 then
				legal_moves_ptn[#legal_moves_ptn+1] = self.place_cap[i]
			end
		elseif ply > 1 then
			if not(board_top[i][player] == self.em) then
				self:check_stack_moves(legal_moves_ptn,player,i)
			end
		elseif empty[i]==1 then
			legal_moves_ptn[#legal_moves_ptn+1] = self.place_flat[i]
		end
	end

	--self.get_legal_moves_time = self.get_legal_moves_time + (os.clock() - start_time)
	
	return legal_moves_ptn
end


function tak:get_legal_move_table()
	return self.legal_moves_by_ply[#self.legal_moves_by_ply]
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
		local legal_moves_ptn = self:get_legal_moves(player)
		table.insert(self.legal_moves_by_ply,legal_moves_ptn)
	end
end


function tak:make_move(ptn,flag)
	
	--local start_time = os.clock()

	-- on the first turn of each player, they play a piece belonging to
	-- the opposite player
	local player
	if self.ply < 2 then
		player = 2 - self.ply
	else
		player = self:get_player()
	end

	--table.insert(self.move_history_ptn,ptn)
	self.move_history_ptn[#self.move_history_ptn + 1] = ptn

	local move_type = string.sub(ptn,1,1)
	local i = self.pos2index[string.sub(ptn,2,3)]
	--local i = self.move2pos[ptn]

	local stacksum = tonumber(move_type)

	local flattening_flag = false

	if not(stacksum) then
		local place_info = self.place_info[move_type]
		self.heights[i] = 1
		self.board[i][1][player] = place_info[1]
		self.player_pieces[player] = self.player_pieces[player] - place_info[2]
		self.player_caps[player] = self.player_caps[player] - place_info[3]
		self.board_top[i][player] = self.board[i][1][player] 
		self.empty_squares[i] = 0
		self.blocks[i] = place_info[4]
		self.top_walls[i] = place_info[5]
	else
		flattening_flag = self:execute_slide_move(player,move_type,ptn,i)
	end

	self.ply = self.ply + 1
	--self.execute_move_time = self.execute_move_time + (os.clock() - start_time)

	if not(flag) then
		self:populate_legal_moves_at_this_ply()
	end

	self:check_victory_conditions()
	--table.insert(self.flattening_history,flattening_flag)
	self.flattening_history[#self.flattening_history+1] = flattening_flag

	return true
end

function tak:execute_slide_move(player,move_type,ptn,i)
	local flattening_flag = false

	local stacksum = tonumber(move_type)
	local stackdir = string.sub(ptn,4,4)
	local stackstr = string.sub(ptn,5,#ptn)
	local h = self.heights[i] - stacksum
	self.heights[i] = h

	if h == 0 then 
		self.empty_squares[i] = 1 
		self.board_top[i][1] = self.em
		self.board_top[i][2] = self.em
	else
		self.board_top[i][1] = self.board[i][h][1]
		self.board_top[i][2] = self.board[i][h][2]
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
		self.board[x][self.heights[x]][1] = self.board[i][h+k][1]
		self.board[x][self.heights[x]][2] = self.board[i][h+k][2]
		self.board_top[x][1] = self.board[x][self.heights[x]][1]
		self.board_top[x][2] = self.board[x][self.heights[x]][2]
		self.board[i][h+k][1] = self.em
		self.board[i][h+k][2] = self.em
		-- flattening logic
		if (k == stacksum and self.board_top[x][player]==self.c and self.heights[x] > 1) then
			local h2 = self.heights[x]
			if self.board[x][h2-1][player][2] == 1 then
				self.board[x][h2-1][player] = self.f
				flattening_flag = true
			elseif self.board[x][h2-1][3 - player][2] == 1 then
				self.board[x][h2-1][3 - player] = self.f
				flattening_flag = true
			end
			self.top_walls[x] = false
		end

		if m == D then
			x = x + del
			m = 0
			d = d + 1
			D = tonumber(string.sub(stackstr,d,d))
		end
		m = m + 1
	end
	self.blocks[i] = (self.board_top[i][1] == self.s or self.board_top[i][1] == self.c
				or self.board_top[i][2] == self.s or self.board_top[i][2] == self.c)
	self.top_walls[i] = (self.board_top[i][1] == self.s or self.board_top[i][2] == self.s)

	x = x - del
	self.blocks[x] = (self.board_top[x][1] == self.s or self.board_top[x][1] == self.c
				or self.board_top[x][2] == self.s or self.board_top[x][2] == self.c)
	self.top_walls[x] = (self.board_top[x][1] == self.s or self.board_top[x][2] == self.s)

	return flattening_flag
end



function tak:undo_move(ptn)
	-- on the first turn of each player, they play a piece belonging to
	-- the opposite player
	local player
	if self.ply < 2 then
		player = 2 - self.ply
	else
		player = self:get_player()
	end

	local move_type = string.sub(ptn,1,1)
	local i = self.move2pos[ptn]

	local stacksum = tonumber(move_type)

	if not(stacksum) then
		local d = 0
		if move_type == 'c' then d = 1 end
		self.heights[i] = 0
		self.board[i][1][player] = self.em
		self.player_pieces[player] = self.player_pieces[player] + 1 - d
		self.player_caps[player] = self.player_caps[player] + d
		self.board_top[i][player] = self.em 
		self.empty_squares[i] = 1
		self.blocks[i] = false
		self.top_walls[i] = false
	else
		self:undo_slide_move(player,move_type,ptn,i)
	end

	self.flattening_history[#self.flattening_history] = nil
end

function tak:undo_slide_move(player,move_type,ptn,i)
	local stacksum = tonumber(move_type)
	local stackdir = string.sub(ptn,4,4)
	local stackstr = string.sub(ptn,5,#ptn)

	self.empty_squares[i] = 0
	local h = self.heights[i] 

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
		self.board[i][h+n+m][1] = self.board[x][self.heights[x]][1]
		self.board[i][h+n+m][2] = self.board[x][self.heights[x]][2]
		self.board[x][self.heights[x]][1] = self.em
		self.board[x][self.heights[x]][2] = self.em
		self.heights[x] = self.heights[x] - 1
		-- unflattening logic
		if (k==stacksum and self.flattening_history[#self.flattening_history]) then
			if self.board[x][self.heights[x]][player][1] == 1 then
				self.board[x][self.heights[x]][player] = self.s
			elseif self.board[x][self.heights[x]][3 - player][1] == 1 then
				self.board[x][self.heights[x]][3 - player] = self.s 
			end
		end
		if self.heights[x] > 0 then
			self.board_top[x][1] = self.board[x][self.heights[x]][1]
			self.board_top[x][2] = self.board[x][self.heights[x]][2]
		else
			self.board_top[x][1] = self.em
			self.board_top[x][2] = self.em
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
	self.board_top[i][1] = self.board[i][self.heights[i]][1]
	self.board_top[i][2] = self.board[i][self.heights[i]][2]

	self.blocks[i] = (self.board_top[i][1] == self.s or self.board_top[i][1] == self.c
				or self.board_top[i][2] == self.s or self.board_top[i][2] == self.c)
	self.top_walls[i] = (self.board_top[i][1] == self.s or self.board_top[i][2] == self.s)

	self.blocks[x] = (self.board_top[x][1] == self.s or self.board_top[x][1] == self.c
				or self.board_top[x][2] == self.s or self.board_top[x][2] == self.c)
	self.top_walls[x] = (self.board_top[x][1] == self.s or self.board_top[x][2] == self.s)
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

function tak:check_victory_conditions()
	local player_one_remaining = self.player_pieces[1] + self.player_caps[1]
	local player_two_remaining = self.player_pieces[2] + self.player_caps[2]

	local empty, board_top = self.empty_squares, self.board_top
	local end_is_nigh = false
	local explored = self.explored

	self.num_empty_squares = 0
	self.player_flats[1] = 0
	self.player_flats[2] = 0
	for i=1,self.board_size do
		explored[i] = false
		self.num_empty_squares = self.num_empty_squares + empty[i]
		if board_top[i][1] == self.f then
			self.player_flats[1] = self.player_flats[1] + 1
		elseif board_top[i][2] == self.f then
			self.player_flats[2] = self.player_flats[2] + 1
		end
	end

	-- if the game board is full or either player has run out of pieces, trigger end
	if self.num_empty_squares == 0 or player_one_remaining == 0 or player_two_remaining == 0 then
		end_is_nigh = true
	end

	-- let's find us some island information

	--local start_time = os.clock()

	local x, y = self.x, self.y
	local has_left, has_right, has_down, has_up = self.has_left, self.has_right, self.has_down, self.has_up
	local min_x, max_x, min_y, max_y, sum
	local p1_rw, p2_rw = false, false
	local queue = self.queue

	local function flood_fill(start,player)
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



	local p1_rw, p2_rw = false, false
	local dim1, dim2 = 0,0
	local dimsum1, dimsum2 = 0,0
	local p1_isles, p2_isles = self.island_sums[1], self.island_sums[2]
	local num_isles1, num_isles2 = 0,0
	for i=1,self.board_size do
		if not(explored[i]) then
			if board_top[i][1][1] == 1 or board_top[i][1][3] == 1 then
				sum = 0
				min_x, max_x, min_y, max_y = x[i],x[i],y[i],y[i]
				flood_fill(i,1)
				num_isles1 = num_isles1 + 1
				p1_isles[num_isles1] = sum
				dim1 = max(max_x - min_x, max_y - min_y, dim1)
				dimsum1 = dimsum1 + dim1
			elseif board_top[i][2][1] == 1 or board_top[i][2][3] == 1 then
				sum = 0
				min_x, max_x, min_y, max_y = x[i],x[i],y[i],y[i]
				flood_fill(i,2)
				num_isles2 = num_isles2 + 1
				p2_isles[num_isles2] = sum
				dim2 = max(max_x - min_x, max_y - min_y, dim2)
				dimsum2 = dimsum2 + dim1
			end
		end
	end

	self.island_max_dims[1] = dim1
	self.island_max_dims[2] = dim2
	self.island_len_sums[1] = dimsum1
	self.island_len_sums[2] = dimsum2
	p1_rw = dim1 == self.size - 1
	p2_rw = dim2 == self.size - 1
	self.island_sums[1] = p1_isles
	self.island_sums[2] = p2_isles
	self.num_islands[1] = num_isles1
	self.num_islands[2] = num_isles2

	--self.flood_fill_time = self.flood_fill_time + (os.clock() - start_time)

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
		local outstr
		if self.winner == 1 and self.win_type == 'F' then
			outstr = 'F - 0'
		elseif self.winner == 1 and self.win_type == 'R' then
			outstr = 'R - 0'
		elseif self.winner == 2 and self.win_type == 'F' then
			outstr = '0 - F'
		elseif self.winner == 2 and self.win_type == 'R' then
			outstr = '0 - R'
		else
			outstr = '1/2 - 1/2'
		end
		self.outstr = outstr
	end

	--return self.game_over, self.winner, self.win_type, p1_rw, p2_rw

end


function tak:get_children()
	local legal = self.legal_moves_by_ply[#self.legal_moves_by_ply]
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
		legal = self.legal_moves_by_ply[#self.legal_moves_by_ply]
		move = torch.random(1,#legal)
		self:make_move(legal[move])
	end
end

function tak:simulate_random_game()
	while not(self.game_over) do
		legal = self.legal_moves_by_ply[#self.legal_moves_by_ply]
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
		local move_ptn = string.lower(ptn_move)
		if move_ptn == string.match(move_ptn,'%a%d') then
			move_ptn = 'f' .. move_ptn
		elseif move_ptn == string.match(move_ptn,'%a%d[<>%+%-]') then
			move_ptn = '1' .. move_ptn .. '1'
		elseif move_ptn == string.match(move_ptn,'%d%a%d[<>%+%-]') then
			move_ptn = move_ptn .. string.sub(move_ptn,1,1)
		end
		self:make_move(move_ptn)
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
	local moves = game.legal_moves_by_ply[#game.legal_moves_by_ply]
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
