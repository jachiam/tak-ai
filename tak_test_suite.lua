require 'tak_game'
require 'tak_tree_AI'
t = tak.new(5)
--[[t:make_move_by_ptn('fa2')	-- white plays a black flat at a2
t:make_move_by_ptn('fa1')	-- black plays a white flat at a1
t:make_move_by_ptn('fa3')     -- white plays flat at a3
t:make_move_by_ptn('cb2')	-- black plays cap at b2
t:make_move_by_ptn('fb3')	-- white plays flat at b3
t:make_move_by_ptn('1a2+1')   -- black moves flat from a2 to a3 ]]
t:generate_random_game(6)
--t:make_move_by_ptn('fe1')
--t:make_move_by_ptn('fd1')
--t:make_move_by_ptn('fe2')
--t:make_move_by_ptn('fd2')
--t:make_move_by_ptn('fe3')
--t:make_move_by_ptn('fd3')
--t:make_move_by_ptn('fe4')
--t:make_move_by_ptn('fd4')
--t:make_move_by_ptn('fe5')
go, w, wt, p1rw, p2rw, p1p, p2p = t:check_victory_conditions()

--s = t:clone() 
gameptn = "[Size \"5\"]\n" ..
"\n1. Fa3 Fd1 " ..
"\n2. Sd2 Se5 " ..
"\n3. Ca4 Sb1 " ..
"\n4. Fe1 1e5-1 " ..
"\n5. Fe2 Ce5 " ..
"\n6. Fe3 1e5-1 " ..
"\n7. Fd3 Se5 " ..
"\n8. Fd4 1e5<1 " ..
"\n9. Fc4 Se5 " ..
"\n10. Fb4 	"
-- t:play_game_from_ptn(gameptn)

--generate_game_by_alphabeta(t,1,2,5,true,true)

require 'tak_policy.lua'

tp = tak_policy.new(t.size,t.max_height,#t.move2ptn)
p = tp.network:getParameters()
print(p:size())
