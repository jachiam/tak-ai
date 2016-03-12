function ptn_moves(carry_limit)
	if carry_limit > 8 then
		print 'no'
		return
	end


	local function seq2str(seq)
		s = ''
		for i=1,#seq do
			s = s .. seq[i]
		end
		return s
	end

	local function stacksum(stack_move)
		s = 0
		for i=2,#stack_move do
			s = s + string.sub(stack_move,i,i)
		end
		return s
	end

	seqs = {}
	for i=1,carry_limit do
		tab = additive_combos(i,carry_limit)
		for j=1,#tab do
			table.insert(seqs,seq2str(tab[j]))
		end
	end

	stack_moves = {}
	dirs = {'<', '>', '+', '-'}
	for i=1,4 do
		for j=1,#seqs do
			table.insert(stack_moves,dirs[i] .. seqs[j])
		end
	end

	posits = {}
	letters = {'a','b','c','d','e','f','g','h'}
	for i=1,carry_limit do
		for j=1, carry_limit do
			table.insert(posits,letters[i] .. j)
		end
	end

	l2i = {}
	for i=1,#letters do
		l2i[letters[i]] = i
	end

	local function is_move_valid(pos,stack_move)
		x = l2i[string.sub(pos,1,1)]
		y = tonumber(string.sub(pos,2,2))
		dist = #stack_move - 1
		dir = string.sub(stack_move,1,1)
		if dir == '+' then
			y = y + dist
		elseif dir == '-' then
			y = y - dist
		elseif dir == '>' then
			x = x + dist
		elseif dir == '<' then
			x = x - dist
		end
		return x <= carry_limit and x >= 1 and y <= carry_limit and y >= 1
	end

	moves2ptn = {}
	stack_moves_by_pos = {}	-- valid stack moves at this position
	stack_sums = {}		-- how many get picked up at each stack move
	for i=1,#posits do
		table.insert(moves2ptn,'f' .. posits[i])
		table.insert(moves2ptn,'c' .. posits[i])
		table.insert(moves2ptn,'s' .. posits[i])
		stack_moves_by_pos[posits[i]] = {}
		for j=1,#stack_moves do
			stack_sums[j] = stacksum(stack_moves[j])
			move_candidate = stack_sums[j] .. posits[i] .. stack_moves[j]
			if is_move_valid(posits[i],stack_moves[j]) then
				table.insert(moves2ptn, move_candidate)
				stack_moves_by_pos[posits[i]][#stack_moves_by_pos[posits[i]]+1] = j
			end
		end
	end

	ptn2moves = {}
	for i=1,#moves2ptn do
		ptn2moves[moves2ptn[i]] = i
	end

	return moves2ptn, ptn2moves, stack_moves_by_pos, stack_sums, stack_moves, posits, seqs
end


function additive_combos(num,limit)
	
	local function recurse(num,left,tab,hist,level)
		if left == 0 then --and #hist > 1 then
			table.insert(tab,hist)
		end

		for i=1,left do
			if level < limit - 1 then
				local histcopy = deepcopy(hist)
				histcopy[#histcopy+1] = i
				recurse(num,left-i,tab,histcopy,level+1)
			end
		end
	end

	tab = {}
	recurse(num,num,tab,{},0)

	return tab
end

function deepcopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[deepcopy(orig_key)] = deepcopy(orig_value)
        end
        setmetatable(copy, deepcopy(getmetatable(orig)))
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end
