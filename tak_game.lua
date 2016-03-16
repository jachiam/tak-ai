require 'torch'
require 'math'
require 'move_enumerator'

local tak = torch.class('tak')

function tak:__init(size)
	self.size = size or 5
	if self.size == 3 then
		self.piece_count = 12
		self.cap_count = 0
	elseif self.size == 4 then
		self.piece_count = 15
		self.cap_count = 0
	elseif self.size == 5 then
		self.piece_count = 20 
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
	self.legal_moves_by_ply = {}

	self.move2ptn, self.ptn2move, self.stack_moves_by_pos, self.stack_sums, self.stack_moves = ptn_moves(self.carry_limit)

	self:populate_legal_moves_at_this_ply()

	self.game_over = false
	self.winner = 0
	self.win_type = 'NA'

	self.islands = {{},{}}

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
	self.board:copy(self.board_history[#self.board_history])
	self.heights:copy(self.heights_history[#self.heights_history])
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
	copy = tak.new(self.size)
	copy.board = self.board:clone()
	copy.heights = self.heights:clone()
	copy.ply = self.ply
	copy.player_pieces = deepcopy(self.player_pieces)
	copy.player_caps = deepcopy(self.player_caps)
	copy.move_history_ptn = deepcopy(self.move_history_ptn)
	copy.move_history_idx = deepcopy(self.move_history_idx)
	copy.legal_moves_by_ply = deepcopy(self.legal_moves_by_ply)
	copy.game_over = self.game_over
	copy.winner = self.winner
	copy.win_type = self.win_type
	return copy
end

function tak:deep_clone()
	copy = tak.new(self.size)
	copy:play_game_from_ptn(self:game_to_ptn())
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

function tak:get_board_top()
	board_top = torch.zeros(self.size,self.size,2,3):float()
	-- top_heights are 'n' if there is a stack of size 'n' or 1 if empty
	top_heights = (self.heights + torch.eq(self.heights,0):long()):long()
	for i=1,self.size do
		for j=1,self.size do
			board_top[{i,j}] = self.board[{i,j,top_heights[{i,j}]}]
		end
	end
	return board_top
end

function tak:get_empty_squares()
	board_top = self:get_board_top()
	return torch.eq(board_top:sum(3):sum(4):squeeze(),0), board_top
end

function tak:is_board_valid()
	return torch.le(self.board:sum(3):sum(4):sum(5):squeeze(),1):sum()
end

function tak:get_legal_moves(player)

	local function check_stack_move(i,j,pos,stack_move_index)
		-- how do we check whether a stack move is valid?
		-- well: we already know, from the fact that this one is in stack_moves_by_pos,
		-- that it is /legal/ in the sense that it does not put pieces off the board.
		-- but it could run into walls. that is what we are here to check.
		-- is there a wall or a cap somewhere in its way? 
		-- and if so, do we flatten the wall with a capstone, or not?
		stack_move = self.stack_moves[stack_move_index]

		-- also, do we have enough stones to make the move?
		if (self.stack_sums[stack_move_index] > self.heights[{i,j}]) then
			return false
		end

		dir = string.sub(stack_move,1,1)
		dist = #stack_move - 1	-- -1 for dir
		x = i
		y = j
		if dir == '+' then
			y = y + dist
		elseif dir == '-' then
			y = y - dist
		elseif dir == '>' then
			x = x + dist
		elseif dir == '<' then
			x = x - dist
		end

		-- woo ugly array slicing
		top_walls = board_top:sum(3):squeeze()[{{},{},{2}}]:squeeze()
		top_caps  = board_top:sum(3):squeeze()[{{},{},{3}}]:squeeze()
		if i > x then
			xrange = {x,i-1}
			yrange = {j,j}
		elseif x > i then
			xrange = {i+1,x}
			yrange = {j,j}
		elseif j > y then
			yrange = {y,j-1}
			xrange = {i,i}
		elseif y > j then
			yrange = {j+1,y}
			xrange = {i,i}
		end
		walls_on_path = top_walls[{ xrange, yrange }]
		caps_on_path  = top_caps[{ xrange, yrange }]
		walls_in_way = walls_on_path:sum() > 0
		caps_in_way = caps_on_path:sum() > 0
		if caps_in_way then
			return false
		elseif walls_in_way then
			-- if there is /only one/ wall and our stack is topped by a cap, and
			-- the stack flow ends with the cap flatting the wall...
			joint_condition = walls_on_path:sum() == 1
			joint_condition = joint_condition and self.board[{i,j,self.heights[{i,j}],player,3}] == 1
			joint_condition = joint_condition and top_walls[{x,y}] == 1
			last_digit = tonumber(string.sub(stack_move,#stack_move,#stack_move))
			joint_condition = joint_condition and last_digit == 1
			return joint_condition
		else
			return true
		end
	end

	local function check_stack_moves(i,j,pos)
		for k=1,#self.stack_moves_by_pos[pos] do
			stack_move_index = self.stack_moves_by_pos[pos][k]
			stack_move_legal = check_stack_move(i,j,pos,stack_move_index)
			if stack_move_legal then
				stack_move_ptn = self.stack_sums[stack_move_index] .. pos .. self.stack_moves[stack_move_index]
				table.insert(legal_moves_ptn, stack_move_ptn)
			end
		end
	end

	legal_moves_ptn = {}
	empty_squares, board_top = self:get_empty_squares()
	letters = {'a','b','c','d','e','f','g','h'}
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
			elseif (self.ply > 1) then
				control = self.board[{i,j,self.heights[{i,j}],player}]:sum()
				if control > 0 then
					check_stack_moves(i,j,pos)
				end
			elseif empty_squares[{i,j}]==1 then
				table.insert(legal_moves_ptn,'f' .. pos)
			end
		end
	end

	legal_move_mask = torch.zeros(#self.move2ptn)
	for i=1,#legal_moves_ptn do
		legal_move_mask[self.ptn2move[legal_moves_ptn[i]]] = 1
	end
	
	return legal_moves_ptn, legal_move_mask
end

function tak:get_player()
	-- on the first turn of each player, they play a piece belonging to
	-- the opposite player
	local player
	if self.ply < 2 then
		player = 2 - self.ply
	else
		-- self.ply says how many plys have been played, starts at 0
		player = self.ply % 2 + 1
	end
	return player
end

function tak:populate_legal_moves_at_this_ply()
	local player = self:get_player()
	if #self.legal_moves_by_ply < self.ply+1 then
		legal_moves_ptn, legal_moves_mask = self:get_legal_moves(player)
		table.insert(self.legal_moves_by_ply,{player,legal_moves_ptn,legal_moves_mask})
	end
end

function tak:make_move_by_idx(move_idx)
	return self:make_move(self.move2ptn[move_idx],move_idx)
end

function tak:make_move_by_ptn(move_ptn)
	return self:make_move(move_ptn,self.ptn2move[move_ptn])
end

function tak:accept_user_ptn(move_ptn)
	move_ptn = string.lower(move_ptn)
	if move_ptn == string.match(move_ptn,'%a%d') then
		move_ptn = 'f' .. move_ptn
	elseif move_ptn == string.match(move_ptn,'%a%d[<>%+%-]') then
		move_ptn = '1' .. move_ptn .. '1'
	end
	idx = self.ptn2move[move_ptn]
	
	if idx == nil then
		print 'Did not recognize move.'
		return false
	end

	return self:make_move_by_ptn(move_ptn), move_ptn, idx	-- last two outputs are for debug only
end

function tak:make_move(ptn,idx)

	if self.game_over then
		print 'Game is over.'
		return false
	end

	player = self:get_player()

	-- check to see if we have already calculated legal moves at this ply
	-- if not, do so
	-- check whether the move that has been proposed is a legal move
	-- if so, play it and increment ply
	-- otherwise, reject, and do not increment ply
	-- note: legal moves for a ply are generated before the ply is played (hence ply+1)

	if not(self.legal_moves_by_ply[self.ply+1][3][idx] > 0) then
		print 'Move was not legal.'
		return false
	end

	table.insert(self.move_history_ptn,ptn)
	table.insert(self.move_history_idx,idx)
	move_type = string.sub(ptn,1,1)
	letter = string.sub(ptn,2,2)
	l2i = {a = 1, b = 2, c = 3, d = 4, e = 5, f = 6, g = 7, h = 8}
	i = l2i[letter]
	j = tonumber(string.sub(ptn,3,3))

	if move_type == 'f' then
		self.heights[{i,j}] = 1
		self.board[{i,j,1,player,1}] = 1
		self.player_pieces[player] = self.player_pieces[player] - 1
	elseif move_type == 's' then
		self.heights[{i,j}] = 1
		self.board[{i,j,1,player,2}] = 1		
		self.player_pieces[player] = self.player_pieces[player] - 1		
	elseif move_type == 'c' then
		self.heights[{i,j}] = 1
		self.board[{i,j,1,player,3}] = 1
		self.player_caps[player] = self.player_caps[player] - 1		
	else
		-- oooh this is gonna be hard
		-- welcome to index magic and duct tape... but you're reading this code, so you already knew that
		stacksum = tonumber(move_type)
		stackdir = string.sub(ptn,4,4)
		stackstr = string.sub(ptn,5,#ptn)
		stack_amts = {}
		h = self.heights[{i,j}]
		-- get the stack in your hand
		hand = self.board[{i,j,{h-stacksum+1,h},{},{}}]:clone()
		-- clear off the original stack
		self.board[{i,j,{h-stacksum+1,h},{},{}}]:zero()
		self.heights[{i,j}] = h - stacksum
	
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

	self:check_victory_conditions()

	self:populate_legal_moves_at_this_ply()

	table.insert(self.board_history,self.board:clone())
	table.insert(self.heights_history,self.heights:clone())

	return true
end

function tak:check_victory_conditions()
	local player_one_remaining = self.player_pieces[1] + self.player_caps[1]
	local player_two_remaining = self.player_pieces[2] + self.player_caps[2]

	-- if the game board is full or either player has run out of pieces, trigger end
	empty, board_top = self:get_empty_squares()
	end_is_nigh = false
	if empty:sum() == 0 or player_one_remaining == 0 or player_two_remaining == 0 then
		end_is_nigh = true
	end

	-- let's find us some islands
	local function get_islands(player)
		top = self:get_board_top()
		top_flats_and_caps = top[{{},{},player,1}] + top[{{},{},player,3}]
		top_walls = top[{{},{},player,2}]

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
		unexplored_nodes = top_flats_and_caps:clone():fill(1)
		for i=1,self.size do
			for j=1,self.size do
				if unexplored_nodes[{i,j}] == 1 and top_flats_and_caps[{i,j}] == 1 then
					table.insert(islands,top_flats_and_caps:clone():zero())
					flood_fill(unexplored_nodes,islands[#islands],i,j)
				end
			end
		end
		return islands
	end

	local function check_road_wins()
		rw = {}
		for player=1,2 do
			rw[player] = false
			local islands = get_islands(player)
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

	p1_rw, p2_rw = check_road_wins()
	road_win = p1_rw or p2_rw

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

function tak:generate_random_game(max_moves)
	for i=1,max_moves do
		legal = self.legal_moves_by_ply[#self.legal_moves_by_ply][2]
		move = torch.random(1,#legal)
		self:make_move_by_ptn(legal[move])
	end
end

function tak:game_to_ptn()
	game_ptn = '[Size "' .. self.size .. '"]\n\n'

	for i=1,#self.move_history_ptn do
		if (i+1) % 2 == 0 then
			j = (i + 1)/2
			game_ptn = game_ptn .. j .. '. '
		end
		ptn = self.move_history_ptn[i]

		ptn_tail = string.sub(ptn,2,#ptn)
		ptn_head = string.upper(string.sub(ptn,1,1))

		game_ptn = game_ptn .. ptn_head .. ptn_tail .. ' '
		if (i+1) % 2 == 1 then
			game_ptn = game_ptn .. '\n'
		end
	end
	return game_ptn
end

function tak:play_game_from_ptn(ptngame)
	print 'Playing the following game: '
	print(ptngame)
	l,u = string.find(ptngame,"Size")
	size = tonumber(string.sub(ptngame,u+3,u+3))
	self:__init(size)
	iterator = string.lower(ptngame):gmatch("%w%a%d[<>%+%-]?%d*")
	for ptn_move in iterator do
		self:make_move_by_ptn(ptn_move)
	end		
end
