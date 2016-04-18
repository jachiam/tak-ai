 _____      _        _     _____ 
/__   \__ _| | __   /_\    \_   \
  / /\/ _` | |/ /  //_\\    / /\/
 / / | (_| |   <  /  _  \/\/ /_  
 \/   \__,_|_|\_\ \_/ \_/\____/  
                                 
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
+ a1<, 1a1<1 are acceptable. 1a1< is not acceptable.

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
