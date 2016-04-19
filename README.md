# TAK AI

by Joshua Achiam

Hello! Welcome to my Tak AI library! Currently the library does not support a graphical interface, and the AI can only be played against on the command line. I recommend you use the PTN viewer by Ben Wochinski to view games. 

The library supports two main AI variants. One AI uses a minimax search with alpha-beta pruning and a heuristic value function I've devised by trial and error. This variant is Takai. The other AI uses a flat Monte Carlo method for evaluating possible moves. This variant is Takarlo.


## Dependencies:

The Tak AI library is written in Lua. 

To use it, you need to install...

1. The 'Torch' package (from torch.ch, which will also install Lua)

2. The 'threads' package (run 'luarocks install threads' after you have installed Torch).

That should be everything.


## How to Play:

1. Navigate to the tak-ai directory and fire up Torch with the 'th' command in the command line.

2. Run the following commands to begin a game against the AI:

```lua
require 'tak_AI'

game = tak.new(5)	-- creates a new game of Tak on a board of size 5


-- let's load a partially played game
game:play_game_from_file('game.txt')


-- create a new minimax AI agent doing a depth 3 search
-- the second arg is the debug flag, so it'll give some info with each move
takai = make_takai(3,true)


-- create a flat Monte Carlo agent that takes 75s per move to think
takarlo = make_takarlo_01(75,true)	


-- begin a match against takai with 'debug' on, to get full PTN readouts of game as you go
AI_vs_AI(game,human,takai,true)	

```


Regarding the AI_vs_AI command: the first argument is the game node, the second argument is the first player, the third argument is the second player, and the fourth argument is 'debug,' which controls how much text readout there is. If you do not have 'debug' on, you will not be able to see anything. 

To issue commands to the game when it is your turn, give your move in PTN. PTN admits some ambiguity, so here is what is permitted:
+ a1, fa1, Fa1 are all acceptable. (the first letter may be lowercase for placing walls or caps also.)
+ a1<, 1a1>1 are acceptable. 1a1< is not acceptable.

If you'd like to control the game more directly, I recommend you check out the source code, but the snippets you will be most interested in are:

```lua
game:make_move(a)
```

which tells the Tak game object to execute the move 'a' (which should be in PTN, but may also be an index corresponding to the PTN move -- but don't worry about that! there is some magic and duct tape here). 

Also,

```lua
agent:move(game)
```

which tells the AI agent object to make a move in the game. 


## Misc.

Some thoughts on Takai: 

You probably should not play at depths greater than 3. The current implementation of the minimax search is quick but not lightning fast. From my experience, it takes somewhere on the order of 30 seconds to make a move on the 5x5 board, on average. But for games with many stacks, this can go up. (I have one test instance where it takes about 90 seconds to move.) On 4x4 boards, it only seems to take around 10 seconds per move, with 30 seconds at the longest. I am actively working on speeding this up.

Once you have played enough games with this AI, you will see that it is somewhat predictable. Hopefully still strong enough to be a worthy opponent. It can give you a run for your money if you aren't careful, though.

Future versions of this are planned, and a wrapper for it to interface to PlayTak.com is imminent. (Although if anyone beats me to the punch, I'll have no objections - just open source your code, please! :) )


Some thoughts on Takarlo:

Takarlo will make better moves if you give it longer to think. As a point of reference, I find that Takarlo seems to win about 50% of the time on the 4x4 board against Takai (depth 3) when you give Takarlo 75 seconds per move. For a 5x5 board, you might want to give it a bit longer - maybe 120 seconds? 180 even? 

Takarlo gets creative in ways that Takai doesn't. But it also sometimes misses what seems like the obvious move to make, and even makes clearly poor moves from time to time. I imagine that Takarlo will hold up poorly against human opponents, but I am not sure yet. Time will tell.
