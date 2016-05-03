require 'torch'
require 'math'
require 'move_enumerator'
require 'flood_fill'

local tak = torch.class('tak')

-- N.B.: The "making_a_copy" argument is used when making a fast clone of a tak game,
-- which is helpful in the AI tree search.
function tak:__init(size,making_a_copy)

	self.isle_method = 1

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
		-- e.g, if self.board[1,3,1,2,3] = 1, that means,
		--      at position (1,3,1), player 2 has a capstone. 
	self.board = torch.zeros(self.size,self.size,self.max_height,2,3):float()

	-- convenience variable for keeping track of the topmost entry in each position
	-- self.heights[4,2] = 0 means, position (4,2) is empty.
	-- self.heights[4,2] = 3 means, position (4,2) has a stack of size 3.
	self.heights = torch.zeros(self.size,self.size):long()

	self.ply = 0	-- how many plys have elapsed since the start of the game?
	self.move_history_ptn = {}
	self.move_history_idx = {}
	self.board_history = {self.board:clone()}
	self.heights_history = {self.heights:clone()}
	self.board_top = torch.zeros(self.size,self.size,2,3):float()
	self.empty_squares = torch.ones(self.size,self.size):float()
	self.board_top_history = {self.board_top:clone()}
	self.empty_squares_history = {self.empty_squares:clone()}
	self.legal_moves_by_ply = {}

	--sbsd: stacks_by_sum_and_distance
	--sbsd1: when the last stone is a cap crushing a wall
	self.move2ptn, self.ptn2move, self.stack_moves_by_pos, self.stack_sums, self.stack_moves, _, _, self.sbsd, self.sbsd1 = ptn_moves(self.carry_limit)

	self.magic_ld = nil
	self.magic_ur = nil

	self:populate_legal_moves_at_this_ply()

	self.game_over = false
	self.winner = 0
	self.win_type = 'NA'

	self.islands = {{},{}}
end

function tak:get_history()
	return self.move_history_ptn
end

function tak:get_i2n(i)
	return self.move2ptn[i]
end

function tak:set_debug_times_to_zero()
	self.get_empty_squares_time = 0
	self.get_legal_moves_time = 0
	self.execute_move_time = 0
	self.flood_fill_time = 0
end

function tak:print_debug_times()
	print('empty squares time: \t' .. self.get_empty_squares_time)
	print('get legal moves time: \t' .. self.get_legal_moves_time)
	print('execute move time: \t' .. self.execute_move_time)
	print('flood fill time: \t' .. self.flood_fill_time)

end

function tak:is_terminal()
	return not(self.win_type == 'NA')
end

function tak:undo()
	if self.ply == 0 then
		return
	end
	if self.game_over then
		self.game_over = false
		self.winner = 0
		self.win_type = 'NA'
	end
	self.move_history_ptn[#self.move_history_ptn] = nil
	self.move_history_idx[#self.move_history_idx] = nil
	self.legal_moves_by_ply[#self.legal_moves_by_ply] = nil

	self.board_history[#self.board_history] = nil
	self.heights_history[#self.heights_history] = nil
	self.board_top_history[#self.board_top_history] = nil
	self.empty_squares_history[#self.empty_squares_history] = nil

	self.board:copy(self.board_history[#self.board_history])
	self.heights:copy(self.heights_history[#self.heights_history])
	self.board_top:copy(self.board_top_history[#self.board_top_history])
	self.empty_squares:copy(self.empty_squares_history[#self.empty_squares_history])

	self.player_pieces = {self.piece_count - self.board[{{},{},{},1,{1,2}}]:sum(), 
			      self.piece_count - self.board[{{},{},{},2,{1,2}}]:sum()}
	self.player_caps =   {self.cap_count - self.board[{{},{},{},1,3}]:sum(), 
			      self.cap_count - self.board[{{},{},{},2,3}]:sum()}
	self.ply = self.ply - 1
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
	copy.board = self.board:clone()
	copy.heights = self.heights:clone()
	copy.board_top = self.board_top:clone()
	copy.empty_squares = self.empty_squares:clone()
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
	copy.stack_moves_by_pos = self.stack_moves_by_pos
	copy.stack_sums = self.stack_sums
	copy.stack_moves = self.stack_moves
	copy.sbsd = self.sbsd
	copy.sbsd1 = self.sbsd1
	copy.islands = {{},{}}
	copy.board_history = {}
	copy.heights_history = {}
	copy.board_top_history = {}
	copy.empty_squares_history = {}
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
				if stack[{k,l,1}]==1 then
					str = str .. l
				elseif stack[{k,l,2}]==1 then
					str = str .. l ..'S'
				elseif stack[{k,l,3}]==1 then
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
			stack = self.board[{j,self.size + 1 - i}]
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

function tak:is_board_valid()
	return torch.le(self.board:sum(3):sum(4):sum(5):squeeze(),1):sum()
end

function tak:get_legal_moves(player)

	local legal_moves_ptn = {}
	local empty_squares, board_top = self:get_empty_squares()
	local letters = {'a','b','c','d','e','f','g','h'}

	local start_time = os.clock()

	local top_walls, top_caps, l_space, r_space, u_space, d_space

	local bt = board_top:sum(3):squeeze()
	top_walls = bt[{{},{},2}]
	top_caps  = bt[{{},{},3}]
	top_walls_and_caps = top_walls + top_caps

	if self.magic_ld == nil and self.magic_ur == nil then
		self.magic_ld = torch.zeros(self.size,self.size):float()
		self.magic_ur = torch.zeros(self.size,self.size):float()
		i = 0; self.magic_ld:apply(function() i = i + 1; return i end)
		i = i + 1; self.magic_ur:apply(function() i = i - 1; return i end)
	end

	local twc_ld = torch.cmul(top_walls_and_caps,self.magic_ld)
	local twc_ur = torch.cmul(top_walls_and_caps,self.magic_ur)

	local function add_stack_moves(hand,pos,dir,seqs)
		if not(seqs == nil) then
			for m=1,#seqs do
				table.insert(legal_moves_ptn, seqs[m][1] .. pos .. dir .. seqs[m][2])
			end
		end
	end

	-- <magic>
	local function check_stack_moves(i,j,pos)
		-- hand size, or, how many stones we can take from this stack
		local hand = self.heights[{i,j}]
		if hand > self.size then hand = self.size end

		local l_space, d_space, r_space, u_space

		if i-1 >= 1 then l_space = twc_ld[{{1,i-1},j}] else l_space = torch.Tensor() end
		if j-1 >= 1 then d_space = twc_ld[{i,{1,j-1}}] else d_space = torch.Tensor() end
		if i+1 <= self.size then r_space = twc_ur[{{i+1,self.size},j}] else r_space = torch.Tensor() end
		if j+1 <= self.size then u_space = twc_ur[{i,{j+1,self.size}}] else u_space = torch.Tensor() end

		local spaces = { l_space, d_space, r_space, u_space }
		local sums = { l_space:sum(), d_space:sum(), r_space:sum(), u_space:sum() }
		local dirs = {'<', '-', '>', '+'}
		local dist = {i-1, j-1, self.size - i, self.size - j}
		local delta = {{-1,0},{0,-1},{1,0},{0,1}}

		local top_is_cap = board_top[{i,j,player,3}] == 1

		local seqs

		for k=1,4 do
			if not(sums[k] == 0) then
				local _, ind = torch.max(spaces[k],1)
				if k==1 then
					dist[k] = i - ind[1] - 1
				elseif k==2 then
					dist[k] = j - ind[1] - 1
				else
					dist[k] = ind[1] - 1
				end
				if not(top_is_cap) then
					seqs = self.sbsd[hand][math.min(hand,dist[k])]
				else
					local dest = {i + delta[k][1]*(dist[k]+1), j + delta[k][2]*(dist[k]+1)}
					if top_walls[dest] == 1 then
						dist[k] = dist[k] + 1
						seqs = self.sbsd1[hand][math.min(hand,dist[k])]
					else
						seqs = self.sbsd[hand][math.min(hand,dist[k])]
					end
				end
			else
				seqs = self.sbsd[hand][math.min(hand,dist[k])]
			end
			if dist[k] > 0 then
				add_stack_moves(hand,pos,dirs[k],seqs)
			end
		end		
	end
	-- </magic>

	local pos, control

	for i=1,self.size do
		for j=1,self.size do
			pos = letters[i] .. j
			if empty_squares[{i,j}]==1 and self.ply > 1 then
				if self.player_pieces[player] > 0 then
					table.insert(legal_moves_ptn, 'f' .. pos)
					table.insert(legal_moves_ptn, 's' .. pos)
				end
				if self.player_caps[player] > 0 then
					table.insert(legal_moves_ptn, 'c' .. pos)
				end
			elseif self.ply > 1 then
				control = board_top[{i,j,player}]:sum()
				if control > 0 then
					check_stack_moves(i,j,pos)
				end
			elseif empty_squares[{i,j}]==1 then
				table.insert(legal_moves_ptn,'f' .. pos)
			end
		end
	end

	local legal_move_mask = torch.zeros(#self.move2ptn)
	for i=1,#legal_moves_ptn do
		legal_move_mask[self.ptn2move[legal_moves_ptn[i]]] = 1
	end


	self.get_legal_moves_time = self.get_legal_moves_time + (os.clock() - start_time)
	
	return legal_moves_ptn, legal_move_mask, twc_ld, twc_ur
end



function tak:get_legal_move_mask(as_boolean)
	local legal_move_mask = self.legal_moves_by_ply[#self.legal_moves_by_ply][3]
	if as_boolean then
		return legal_move_mask:byte()
	else
		return legal_move_mask
	end
end

function tak:get_legal_move_table()
	return self.legal_moves_by_ply[#self.legal_moves_by_ply][2]
end

function tak:get_player()
	-- self.ply says how many plys have been played, starts at 0
	return self.ply % 2 + 1
end

function tak:populate_legal_moves_at_this_ply()
	local player = self:get_player()
	if #self.legal_moves_by_ply < self.ply+1 then
		local legal_moves_ptn, legal_moves_mask = self:get_legal_moves(player)
		table.insert(self.legal_moves_by_ply,{player,legal_moves_ptn,legal_moves_mask})
	end
end

-- this is the one we need for the AI move interface
-- flag is special and tells us not to compute legal moves
function tak:make_move(move,flag)
	if type(move) == 'number' then
		return self:make_move_by_idx(move,flag)
	else
		return self:accept_user_ptn(move,flag) --self:make_move_by_ptn(move)
	end
end

function tak:make_move_by_idx(move_idx,flag)
	return self:execute_move(self.move2ptn[move_idx],move_idx,flag)
end

function tak:make_move_by_ptn(move_ptn,flag)
	return self:execute_move(move_ptn,self.ptn2move[move_ptn],flag)
end

-- sanitize user ptn to allow some notational shortcuts
function tak:accept_user_ptn(move_ptn,flag)
	if move_ptn == 'undo' then
		self:undo()
		self:undo()
		return true
	end
	move_ptn = string.lower(move_ptn)
	if move_ptn == string.match(move_ptn,'%a%d') then
		move_ptn = 'f' .. move_ptn
	elseif move_ptn == string.match(move_ptn,'%a%d[<>%+%-]') then
		move_ptn = '1' .. move_ptn .. '1'
	elseif move_ptn == string.match(move_ptn,'%d%a%d[<>%+%-]') then
		move_ptn = move_ptn .. string.sub(move_ptn,1,1)
	end
	idx = self.ptn2move[move_ptn]
	
	if idx == nil then
		print 'Did not recognize move.'
		return false
	end

	return self:make_move_by_ptn(move_ptn,flag), move_ptn, idx	-- last two outputs are for debug only
end

function tak:execute_move(ptn,idx,flag)

	local start_time = os.clock()

	if self.game_over then
		if self.verbose then print 'Game is over.' end
		return false
	end

	-- on the first turn of each player, they play a piece belonging to
	-- the opposite player
	local player
	if self.ply < 2 then
		player = 2 - self.ply
	else
		player = self:get_player()
	end

	-- check to see if we have already calculated legal moves at this ply
	-- if not, do so
	-- check whether the move that has been proposed is a legal move
	-- if so, play it and increment ply
	-- otherwise, reject, and do not increment ply
	-- note: legal moves for a ply are generated before the ply is played (hence ply+1)

	if not(self.legal_moves_by_ply[self.ply+1][3][idx] > 0) then
		if self.verbose then
			print('Tried move ' .. ptn ..' with idx ' .. idx)
			print 'Move was not legal.'
		end
		return false
	end

	table.insert(self.move_history_ptn,ptn)
	table.insert(self.move_history_idx,idx)
	move_type = string.sub(ptn,1,1)
	letter = string.sub(ptn,2,2)
	local l2i = {a = 1, b = 2, c = 3, d = 4, e = 5, f = 6, g = 7, h = 8}
	i = l2i[letter]
	j = tonumber(string.sub(ptn,3,3))

	if move_type == 'f' then
		self.heights[{i,j}] = 1
		self.board[{i,j,1,player,1}] = 1
		self.player_pieces[player] = self.player_pieces[player] - 1
		self.board_top[{i,j,player,1}] = 1
	elseif move_type == 's' then
		self.heights[{i,j}] = 1
		self.board[{i,j,1,player,2}] = 1		
		self.player_pieces[player] = self.player_pieces[player] - 1
		self.board_top[{i,j,player,2}] = 1
	elseif move_type == 'c' then
		self.heights[{i,j}] = 1
		self.board[{i,j,1,player,3}] = 1
		self.player_caps[player] = self.player_caps[player] - 1	
		self.board_top[{i,j,player,3}] = 1
	else
		-- oooh this is gonna be hard
		-- welcome to index magic and duct tape... but you're reading this code, so you already knew that
		stacksum = tonumber(move_type)
		stackdir = string.sub(ptn,4,4)
		stackstr = string.sub(ptn,5,#ptn)
		stack_amts = {}
		h = self.heights[{i,j}]
		-- get the stack in your hand
		local hand = self.board[{i,j,{h-stacksum+1,h},{},{}}]:clone()
		-- clear off the original stack
		self.board[{i,j,{h-stacksum+1,h},{},{}}]:zero()
		local h_new = h - stacksum
		self.heights[{i,j}] = h_new -- h - stacksum
	
		if h_new > 0 then
			self.board_top[{i,j}] = self.board[{i,j,h_new}]	
		else
			self.board_top[{i,j}] = 0
		end

		pos_in_hand = 1

		x = i
		y = j
		for k=1,#stackstr do
			if stackdir == '+' then
				y = y + 1
			elseif stackdir == '-' then
				y = y - 1
			elseif stackdir == '>' then
				x = x + 1
			elseif stackdir == '<' then
				x = x - 1
			end

			dropno = tonumber(string.sub(stackstr,k,k))
			h = self.heights[{x,y}] + 1
			
			-- this bit actually drops things from the hand onto the board
			self.board[{x,y,{h,h+dropno-1},{},{}}]:copy(hand[{{pos_in_hand,pos_in_hand+dropno-1},{},{}}])
			self.heights[{x,y}] = h + dropno - 1
			self.board_top[{x,y}] = self.board[{x,y,self.heights[{x,y}]}]	

			-- flattening logic
			if h > 1 then
				condition = dropno == 1 and pos_in_hand == stacksum -- dropping one piece as last
				condition = self.board[{x,y,h-1,{},2}]:sum() == 1   -- last square has wall
				condition = condition and hand[{pos_in_hand,{},3}]:sum() == 1    -- last stackstone is cap
				if condition then
					-- flatten wall at (x,y,h-1)
					self.board[{x,y,h-1,{},1}] = self.board[{x,y,h-1,{},2}]
					self.board[{x,y,h-1,{},2}] = 0
				end
			end

			pos_in_hand = pos_in_hand + dropno
		end
	end

	self.ply = self.ply + 1

	self.empty_squares = torch.eq(self.board_top:sum(3):sum(4):squeeze(),0)

	self.execute_move_time = self.execute_move_time + (os.clock() - start_time)

	if not(flag) then
		self:populate_legal_moves_at_this_ply()
	else
		if #self.legal_moves_by_ply < self.ply+1 then
			table.insert(self.legal_moves_by_ply,{})
		end
	end

	self:check_victory_conditions()

	table.insert(self.board_history,self.board:clone())
	table.insert(self.heights_history,self.heights:clone())
	table.insert(self.board_top_history,self.board_top:clone())
	table.insert(self.empty_squares_history,self.empty_squares:clone())


	return true
end

function tak:check_victory_conditions()
	local player_one_remaining = self.player_pieces[1] + self.player_caps[1]
	local player_two_remaining = self.player_pieces[2] + self.player_caps[2]

	-- if the game board is full or either player has run out of pieces, trigger end
	local empty, board_top = self:get_empty_squares()
	local end_is_nigh = false
	if empty:sum() == 0 or player_one_remaining == 0 or player_two_remaining == 0 then
		end_is_nigh = true
	end

	local start_time = os.clock()

	-- let's find us some islands

	local function get_islands(player)

		local unexplored_nodes, islands, top, top_flats_and_caps

		top = board_top
		top_flats_and_caps = top[{{},{},player,1}] + top[{{},{},player,3}]

		local function flood_fill(unexplored,island,i,j)
			if top_flats_and_caps[{i,j}] == 1 and unexplored[{i,j}] == 1 then
				unexplored[{i,j}] = 0
				island[{i,j}] = 1
				if i > 1 then
					flood_fill(unexplored,island,i-1,j)
				end
				if i < self.size then
					flood_fill(unexplored,island,i+1,j)
				end
				if j > 1 then
					flood_fill(unexplored,island,i,j-1)
				end
				if j < self.size then
					flood_fill(unexplored,island,i,j+1)
				end
			end
		end

		islands = {}
		unexplored_nodes = torch.ones(self.size,self.size)
		for i=1,self.size do
			for j=1,self.size do
				if unexplored_nodes[{i,j}] == 1 and top_flats_and_caps[{i,j}] == 1 then
					table.insert(islands,torch.zeros(self.size,self.size))
					flood_fill(unexplored_nodes,islands[#islands],i,j)
				end
			end
		end
		return islands
	end


	local function check_road_wins()
		rw = {}
		local isle, a, b, c, d
		for player=1,2 do
			rw[player] = false
			local islands
			if self.isle_method == 1 then
				islands = get_islands(player)
			else
				local top_flats_and_caps = board_top[{{},{},player,1}] + board_top[{{},{},player,3}]
				islands = calculate_islands(top_flats_and_caps,1,2)
			end
			self.islands[player] = islands
			for j=1,#islands do
				isle = torch.eq(islands[j],1)
				a = torch.any(isle[{{},1}])
				b = torch.any(isle[{{},self.size}])
				c = torch.any(isle[{1,{}}])
				d = torch.any(isle[{self.size,{}}])
				rw[player] = rw[player] or (a and b) or (c and d)
			end
		end
		return rw[1], rw[2]
	end

	local p1_rw, p2_rw = check_road_wins()
	local road_win = p1_rw or p2_rw


	self.flood_fill_time = self.flood_fill_time + (os.clock() - start_time)

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
		player_one_flats = board_top[{{},{},1,1}]:sum()
		player_two_flats = board_top[{{},{},2,1}]:sum()
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
		copy:make_move_by_ptn(ptn)
		table.insert(children,copy)
	end

	return children, legal
end

function tak:generate_random_game(max_moves)
	for i=1,max_moves do
		legal = self.legal_moves_by_ply[#self.legal_moves_by_ply][2]
		move = torch.random(1,#legal)
		self:make_move_by_ptn(legal[move])
	end
end

function tak:simulate_random_game()
	while not(self.game_over) do
		legal = self.legal_moves_by_ply[#self.legal_moves_by_ply][2]
		move = torch.random(1,#legal)
		self:make_move_by_ptn(legal[move])
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
		self:accept_user_ptn(ptn_move)
	end		
end

function tak:play_game_from_file(filename,quiet)
	local f = torch.DiskFile(filename)
	local gptn = f:readString('*a')
	f:close()
	self:play_game_from_ptn(gptn,quiet)
end

return tak
