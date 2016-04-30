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


-- begin a match against takai where the human goes first
-- arg1: game object
-- arg2: first player 
-- arg3: second player
fight_takai(game,human,takai)	

```

To issue commands to the game when it is your turn, give your move in PTN. PTN admits some ambiguity, so here is what is permitted:
+ a1, fa1, Fa1 are all acceptable. (the first letter may be lowercase for placing walls or caps also.)
+ a1>, 1a1>1 are acceptable. 1a1> is not acceptable.

The game outputs a visual to the command line that looks like this:

```lua
th> require 'tak_AI'
true	
                                                                      [0.0014s]
th> fight_takai(tak.new(3),human,make_takai(3,true))
fa1
   +---+---+---+
3  |   |   |   | 
   +---+---+---+
2  |   |   |   | 
   +---+---+---+
1  | b |   |   | 
   +---+---+---+
     a   b   c  
	
AI move: fa2, Value: 0.5, Num Leaves: 270, Time taken: 0.082605	
   +---+---+---+
3  |   |   |   | 
   +---+---+---+
2  | w |   |   | 
   +---+---+---+
1  | b |   |   | 
   +---+---+---+
     a   b   c  

a2-
   +----+---+---+
3  |    |   |   | 
   +----+---+---+
2  |    |   |   | 
   +----+---+---+
1  | bw |   |   | 
   +----+---+---+
     a    b   c  

```

Here, we see an exchange over three plies: the human enters fa1, placing a black stone at a1; the AI responds with fa2; the human then captures by moving its white stone at a2 on top of the black stone at a1. Stacks are written so that the bottom is on the left. Flats are denoted by 'b' or 'w'; walls by '[b]' or '[w]'; caps by '{b}' or '{w}'. 

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

###Some thoughts on Takai: 

You probably should not play at depths greater than 3. The current implementation of the minimax search is fast enough to compete well on depth 3: from my experience, it takes somewhere on the order of 15 seconds to make a move on the 5x5 board, on average, and rarely more than a minute. But for games with many stacks, this can go up. On 4x4 boards, it only seems to take less than 3 seconds per move.

Once you have played enough games with this AI, you will see that it is somewhat predictable. Hopefully still strong enough to be a worthy opponent. It can give you a run for your money if you aren't careful, though.

Future versions of Takai with different value functions are imminent, and some of them are under active development in the code here.

###Some thoughts on Takarlo:

Takarlo will make better moves if you give it longer to think. As a point of reference, I find that Takarlo seems to win about 50% of the time on the 4x4 board against Takai (depth 3) when you give Takarlo 75 seconds per move. For a 5x5 board, you might want to give it a bit longer - maybe 120 seconds? 180 even? 

Takarlo gets creative in ways that Takai doesn't. But it also sometimes misses what seems like the obvious move to make, and even makes clearly poor moves from time to time. I imagine that Takarlo will hold up poorly against human opponents, but I am not sure yet. Time will tell.

## Last Thoughts

This is very much under active development! It's also extremely messy right now, and the README is only accurate as of 4/28/16. Cleaner code and a more useful readme will be made available in the future.
