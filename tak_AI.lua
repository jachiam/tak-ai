require 'tak_AI_utils'
require 'lib_AI'

------------------------------
-- TAKAI : A MINIMAX TAK AI --
------------------------------

function make_takai(depth,debug)
	return minimax_AI.new(depth,normalized_value_of_node,debug)
end

function make_takai_01(depth,debug)
	return minimax_AI.new(depth,normalized_value_of_node2,debug)
end

function make_takarlo_00(time,debug)
	return async_flat_mc_AI.new(time,true,default_rollout_policy.new(), 
				false,10,nil,4,{'tak_game','tak_AI_utils'},debug)
end

function make_takarlo_01(time,debug)
	return async_flat_mc_AI.new(time,true,
				epsilon_greedy_policy.new(0.5,normalized_value_of_node), 
				true,8,normalized_value_of_node,4,{'tak_game','tak_AI_utils'},debug)
end


-----------------------------------
-- FIGHT IT ON THE COMMAND LINE! --
-----------------------------------

function fight_takai(node,AI1,AI2)
	while not(node:is_terminal()) do
		AI1:move(node)
		print(print_tak_board_from_game(node,true))
		if node:is_terminal() then break end
		AI2:move(node)
		print(print_tak_board_from_game(node,true))
	end
end


function print_tak_board_from_game(game,mark_squares)
	return print_tak_board(game.board,mark_squares)
end

function print_tak_board(board, mark_squares)
	local board = board

	local size = board:size()[1]
	local max_height = board:size()[3]
	local stacks = {}
	local widest_in_col = torch.zeros(size)

	local function notation_from_piece(piece)
		if piece[1]:sum() > 0 then
			--white piece
			if piece[1][1] == 1 then
				return 'w'
			elseif piece[1][2] == 1 then
				return '[w]'
			elseif piece[1][3] == 1 then
				return '{w}'
			end
		else
			--black piece
			if piece[2][1] == 1 then
				return 'b'
			elseif piece[2][2] == 1 then
				return '[b]'
			elseif piece[2][3] == 1 then
				return '{b}'
			end
		end
		return ''
	end

	local function notation_from_stack(stack)
		local stacknot = ''
		for k=1,max_height do
			stacknot = stacknot .. notation_from_piece(stack[k])
		end
		return stacknot
	end

	for i=1,size do
		stacks[i] = {}
		for j=1, size do
			if board[{i,j}]:sum() > 0 then
				stacks[i][j] = notation_from_stack(board[{i,j}])
			else
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


