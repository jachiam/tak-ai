require 'tak_AI'

game1 = '[Size "3"] 1. Fa1 Fa2   2. Fb2'	-- have to go deeper
game2 = '[Size "3"] 1. Fa1 Fa3   2. Fb3'	-- 8
game3 = '[Size "3"] 1. Fa1 Fc3   2. Fa3'	-- have to go deeper

game1a = '[Size "3"] 1. Fa1 Fa2   2. Fb2 Fc2'	-- 7
game1b = '[Size "3"] 1. Fa1 Fa2   2. Fb2 Sc2'	-- 7
game1c = '[Size "3"] 1. Fa1 Fa2   2. Fb2 1a1+1'	-- have to go deeper

game1ca = '[Size "3"] 1. Fa1 Fa2   2. Fb2 1a1+1   3. Fb3 1a2>1'	-- 3
game1cb = '[Size "3"] 1. Fa1 Fa2   2. Fb2 1a1+1   3. Fb3 2a2>2'	-- 9
game1cc = '[Size "3"] 1. Fa1 Fa2   2. Fb2 1a1+1   3. Fb3 Fb1'	-- 5
game1cd = '[Size "3"] 1. Fa1 Fa2   2. Fb2 1a1+1   3. Fb3 Sb1'	-- 5

game3a = '[Size "3"] 1. Fa1 Fc3   2. Fa3 Fb3   3. Fc1'	-- 8
game3b = '[Size "3"] 1. Fa1 Fc3   2. Fa3 Sb3   3. Fc1'	-- 10

local node = torch.class('node')

function node:__init(game,sequence)
	self.state = game
	self.ply = game.ply
	self.player = game:get_player()
	self.board = game.board
	self.sequence = deepcopy(sequence) or {{self.state.ply,game:print_tak_board(true)}}
	self.child_moves = {}
	self.children = {}
end

function node:update_sequence()
	self.sequence[#self.sequence + 1] = {self.state.ply,self.state:print_tak_board(true)}
end

function node:expand(a)
	if self.state:is_terminal() then return end
	local copy = self.state:clone(true)
	copy:make_move(a)
	table.insert(self.children,node.new(copy,self.sequence))
	table.insert(self.child_moves,a)
	self.children[#self.children]:update_sequence()
end

function node:is_terminal()
	return self.state:is_terminal()
end

function discounted_default_value(node,player)
	if node:is_terminal() and node.winner == player then
		return 1 -(1e-16)*node.ply
	elseif node:is_terminal() and node.winner == 3 - player then
		return 0
	else
		return 0.5
	end
end

function compute_game_tree(game,dep,to_the_end)
	local root = node.new(game)
	local complete_sequences = {}
	local dep = dep or 5


	local function tree_step(game_node,depth)
		if game_node.state:is_terminal() then
			table.insert(complete_sequences,game_node.sequence)
			print(game_node.sequence)
			return
		end
		if game_node.player == 1 then
			local v, a = minimax_move3(game_node.state,depth,discounted_default_value)
			game_node:expand(a)
			tree_step(game_node.children[1],depth-1)
		end
		if game_node.player == 2 then
			local um
			if to_the_end then
				local non_losing = false

				local v = minimax_move2(game_node.state,2,default_value)
				if not(v == 0) then non_losing = true end

				um = get_unique_black_moves(game_node.state,non_losing)
			else
				um = get_unique_black_moves(game_node.state,true)
			end
			for _, a in pairs(um) do
				game_node:expand(a)
				tree_step(game_node.children[#game_node.children],depth-1)
			end
		end
		if #game_node.children == 0 then
			game_node.sequence[#game_node.sequence+1] = 'white wins next round.'
			table.insert(complete_sequences,game_node.sequence)
			print(game_node.sequence)
			return
		end
	end

	tree_step(root,dep)

	return root, complete_sequences	
end


local rotator = torch.class('rotator')

function rotator:__init()
	z = torch.zeros(9,9):float()
	local j=0
	for i=1,9 do
		z[i][ 3*((i-1)%3 + 1) - j] = 1
		if i % 3 == 0 then j = j + 1 end
	end
	z = z:reshape(1,9,9)
	self.z = z:expand(126,9,9)
end

function rotator:rotate_board(board)
	local rb = board:reshape(3,3,126):permute(3,1,2):reshape(126,9,1)
	rb = torch.bmm(self.z,rb)
	rb = rb:reshape(126,3,3):permute(2,3,1):reshape(3,3,21,2,3)
	return rb
end

function rotator:get_board_dihedral(board)
	local dh = {}
	dh[1] = board:clone()
	for j=2,4 do dh[j] = self:rotate_board(dh[j-1]) end
	dh[5] = dh[1]:transpose(1,2)
	for j=6,8 do dh[j] = self:rotate_board(dh[j-1]) end
	return dh
end

r = rotator.new()




-- assuming white has just moved...
-- what moves do not permit white to immediately win on next turn?
function get_black_moves(game)
	if game:get_player() == 1 then
		return false
	end

	local moves = game:get_legal_move_table()
	local non_losing_moves = {}
	local v

	for i, move in pairs(moves) do
		game:make_move(move)
		v = minimax_move2(game,1,default_value)
		if not(v == 1) then
			table.insert(non_losing_moves,move)
		end
		game:undo()
	end
	return non_losing_moves
end




function is_board_in_dh(board,dihedrals)
	for j, dh in pairs(dihedrals) do 
		for k, seen_board in pairs(dh) do
			if torch.all(torch.eq(board,seen_board)) then
				return true
			end
		end
	end
	return false
end

function get_unique_black_moves(game,non_losing)
	if game:get_player() == 1 then
		return false
	end

	local moves = game:get_legal_move_table()
	local non_losing_moves = {}
	local v

	local dihedrals = {}
	local seen

	local function consider_add(move)
		local tensor_board = torch.FloatTensor(game.board)
		seen = is_board_in_dh(tensor_board,dihedrals)
		if not(seen) then
			table.insert(non_losing_moves,move)
			table.insert(dihedrals,r:get_board_dihedral(tensor_board))
		end
	end

	for i, move in pairs(moves) do
		game:make_move(move)
		if non_losing then
			v = minimax_move2(game,1,default_value)
			if not(v == 1) then consider_add(move) end
		else
			consider_add(move)
		end
		game:undo()
	end
	return non_losing_moves, dihedrals
end


function print_tree_recursion(node,f,branch_string)
	local infostring = '============================================================='
	infostring = infostring .. '\n\n\nPly:\t' .. node.ply .. '\nBranch:\t' .. branch_string .. '\n'
	if node.player == 1 then 
		infostring = infostring .. 'Player to move: White\n\n' 
	else
		infostring = infostring .. 'Player to move: Black\n\n'
	end
	infostring = infostring .. node.state:game_to_ptn() .. '\n\n'
	infostring = infostring .. node.state:print_tak_board(true) .. '\n\n\n'
	if node.player == 2 then
		if #node.children == 0 then
			infostring = infostring .. 'Black has no non-losing moves at this state. White wins next round.\n\n\n'
		else
			infostring = infostring .. 'Unique non-losing moves for black at this state: \n\n'
			for i, move in pairs(node.child_moves) do
				infostring = infostring .. i .. '\t' .. move .. '\n'
			end
			infostring = infostring .. '\n\n\n'
		end
	end
	if node.player == 1 then
		if #node.children == 0 then
			infostring = infostring .. 'Game over, white wins.\n\n\n'
		else
			infostring = infostring .. 'White\'s optimal move in this state: \n\n\t' .. node.child_moves[1] .. '\n\n\n'
		end

	end
	f:writeString(infostring) --[[print everything about this node]]
	for i, child in pairs(node.children) do
		print_tree_recursion(child,f,branch_string .. '/' .. i)
	end
end

function print_tree(node,filename)
	local f = torch.DiskFile(filename .. '.txt','rw')
	print_tree_recursion(node,f,'')
	f:close()
end
