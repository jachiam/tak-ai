# Solution to 3x3 Tak: Opening by Putting Black in a Corner
by Joshua Achiam

Note: this solution makes extensive use of Ben Wochinski's [Portable Tak Notation (PTN)](https://www.reddit.com/r/Tak/wiki/portable_tak_notation). 

In this solution variant for 3x3 Tak, we explore what happens when white opens the game by playing a1 -- that is, when white puts black in a corner. A current consensus among Tak players is that this is a strong move for the first player on almost any board size, and this pans out on 3x3: it guarantees a win. (Although, interestingly, not the fastest win for white!) 

At the time of writing this document (5/10/16), the solver used to generate this solution can think 9 plies ahead in ~1 minute on a 3x3 Tak board. It turns out that this branch of the game tree goes 15 plies deep. As a result, a mix of expert knowledge and computer solving was used to generate this solution. 

The expert knowledge comes into play in figuring out the first few moves for white, up through ply 5 in some cases, and the first few moves for black, up through ply 6 in some cases. The computer solver is then used to generate the rest of the game tree.

Below, we'll explain some of the details of the solver, describe the organization of the solution files, and explain where and how expert knowledge was applied.

## Solver

The solver uses a minimax search with alpha-beta pruning and the killer heuristic to determine the optimal move for white when it is white's turn to play. The value function used in the search returns a discounted version of the game-theoretic value of the game: 1 - epsilon*ply if the maximizing player (white) has won, 0 if the minimizing player (black) has won, and 0.5 otherwise (which, at terminal nodes, indicates a draw). The value of epsilon is set to 10<sup>-16</sup>, so any node where the maximizer has won has higher value than any node where the maximizer has not won. The discount factor guarantees that the solver will always choose the move that leads most quickly to a win for the maximizing player. 

Trial and error was used to determine the depth of search necessary to guarantee a win for white from each variant on the opening moves. 

When it is black's turn to play, the solver enumerates the legal moves for black, and then eliminates all moves which are either

* doomed (they allow white to win on the next turn),
* or duplicates (they result in a board state which is symmetrically equivalent to a board state which results from some other move). 

Doomed moves are discovered by depth 1 minimax. Duplicates are discovered by maintaining a table of board states which result from black's moves, and checking a new move's successor state against the table; when a board state is added to the table, its rotational and reflected equivalents are also added (three rotations of 90 degrees, reflection of the original board, and three 90 degree rotations of that reflection). 

Once black's unique legal moves have been enumerated, the sub-tree corresponding to each move is explored.


## Organization of Solution Files

Each solution file is organized into *slides*, where each slide describes a board state, what branch of the game tree it belongs to, and what slides are its children. Example:

```
=============================================================


Ply:	7
Branch:	/1
Player to move: Black

[Size "3"]

1. Fa1 Fa2 
2. Fb2 1a1+1 
3. Fb3 Fb1 
4. Fa3 

   +----+---+---+
3  | w  | w |   | 
   +----+---+---+
2  | wb | w |   | 
   +----+---+---+
1  |    | b |   | 
   +----+---+---+
     a    b   c  



Unique non-losing moves for black at this state: 

1	2a2+2



=============================================================
```

In this section, we will explain the contents of the slide.


### Branch Notation

The 'Branch' field indicates the location of this board state in the game tree *relative to the file in which it is written*. 

This example slide comes from 'game1cc,' which begins at ply 6. At the starting state of this game variant, it is white's turn to move; we only consider one move for white, and follow it. Thus, we wind up in branch /1, at ply 7.

At this state, there is only one unique non-losing move for black, which is given the number 1. When we follow it, we wind up in branch /1/1, at ply 8.

If black had more than one move - for example, if it had two - its other child would lead us to branch /1/2. 


### How to Read the Board State

* 'w': white flat stone
* 'b': black flat stone
* '[w]': white wall
* '[b]': black wall

Stacks are written so that the bottom piece is on the *left* and the top piece is on the *right*. A stack 'wb' means that there is a black stone on top of a white stone.


### Other Details

The history of the game which led to the current state is given in PTN as a convenience. 



## Expert Knowledge

Supposing that white's first move is a1, black has five unique responses (accounting for symmetries and reflections): it can place white at a2, b2, a3, b3, or c3. It is then white's turn. We consider a family of responses that lead to three board states in particular which allow white to make road threats immediately. The board states, and corresponding move histories, are:

**Game 1**

By following (1. a1 a2, 2. b2) or (1. a1 b2, 2. a2): 
```
   +---+---+---+
3  |   |   |   | 
   +---+---+---+
2  | w | w |   | 
   +---+---+---+
1  | b |   |   | 
   +---+---+---+
     a   b   c 
```

**Game 2**

By following (1. a1 a3, 2. b3) or (1. a1 b3, 2. a3): 
```
   +---+---+---+
3  | w | w |   | 
   +---+---+---+
2  |   |   |   | 
   +---+---+---+
1  | b |   |   | 
   +---+---+---+
     a   b   c 
```

**Game 3**

By following (1. a1 c3, 2. a3):
```
   +---+---+---+
3  | w |   | w | 
   +---+---+---+
2  |   |   |   | 
   +---+---+---+
1  | b |   |   | 
   +---+---+---+
     a   b   c 
```

Games are either solved directly from these states (Game 2) or are further subdivided by expert knowledge (Games 1 and 3), depending on their depth. Games 1 and 3 both have maximum depth of 15 plies, whereas Game 2 has maximum depth of 11 plies. 


### Subdividing Game 1

Blach has three non-losing moves at ply 4: c2, Sc2, and a1+. We term these games 1a, 1b, and 1c:

**Game 1a**

By following (1. a1 a2, 2. b2 c2):
```
   +---+---+---+
3  |   |   |   | 
   +---+---+---+
2  | w | w | b | 
   +---+---+---+
1  | b |   |   | 
   +---+---+---+
     a   b   c 
```


**Game 1b**

By following (1. a1 a2, 2. b2 Sc2):
```
   +---+---+-----+
3  |   |   |     | 
   +---+---+-----+
2  | w | w | [b] | 
   +---+---+-----+
1  | b |   |     | 
   +---+---+-----+
     a   b   c 
```


**Game 1c**

By following (1. a1 a2, 2. b2 a1+):
```
   +----+---+---+
3  |    |   |   | 
   +----+---+---+
2  | wb | w |   | 
   +----+---+---+
1  |    |   |   | 
   +----+---+---+
     a    b   c 
```

Games 1a and 1b go to a maximum depth of 11 plies, and so the solver handles them directly with a 7-ply-lookahead search. Game 1c is more complex, so expert knowledge is used to pick b3 as white's move at ply 5. 


### Subdividing Game 1c

After picking b3 at ply 5, black has four non-losing moves: a2>, 2a2>, b1, and Sb1. We term these games 1ca, 1cb, 1cc, and 1cd. 

**Game 1ca**

By following (1. a1 a2, 2. b2 a1+, 3. b3 a2>):
```
   +---+----+---+
3  |   | w  |   | 
   +---+----+---+
2  | w | wb |   | 
   +---+----+---+
1  |   |    |   | 
   +---+----+---+
     a   b    c 
```

**Game 1cb**

By following (1. a1 a2, 2. b2 a1+, 3. b3 2a2>):
```
   +---+-----+---+
3  |   | w   |   | 
   +---+-----+---+
2  |   | wwb |   | 
   +---+-----+---+
1  |   |     |   | 
   +---+-----+---+
     a   b     c 
```

**Game 1cc**

By following (1. a1 a2, 2. b2 a1+, 3. b3 b1):
```
   +----+---+---+
3  |    | w |   | 
   +----+---+---+
2  | wb | w |   | 
   +----+---+---+
1  |    | b |   | 
   +----+---+---+
     a    b   c 
```

**Game 1cd**

By following (1. a1 a2, 2. b2 a1+, 3. b3 Sb1):
```
   +----+-----+---+
3  |    | w   |   | 
   +----+-----+---+
2  | wb | w   |   | 
   +----+-----+---+
1  |    | [b] |   | 
   +----+-----+---+
     a    b     c 
```

All of these game states are solved by the solver with (at most) a 9-ply-lookahead search, so the depth of this branch of the gametree is 15 (6+9). Game 1ca is solved by ply 9, Game 1cb is solved by ply 15, Game 1cc is solved by ply 11, and Game 1cd is solved by ply 11.


### Subdividing Game 3

Black has two non-losing moves at ply 4: b3 or Sb3. In either case, expert knowledge is used to select c1 as white's move at ply 5. We term these two games 3a and 3b.

**Game 3a**

By following (1. a1 c3, 2. a3 b3, 3. c1):
```
   +---+---+---+
3  | w | b | w | 
   +---+---+---+
2  |   |   |   | 
   +---+---+---+
1  | b |   | w | 
   +---+---+---+
     a   b   c 
```

**Game 3b**

By following (1. a1 c3, 2. a3 Sb3, 3. c1):
```
   +---+-----+---+
3  | w | [b] | w | 
   +---+-----+---+
2  |   |     |   | 
   +---+-----+---+
1  | b |     | w | 
   +---+-----+---+
     a   b     c 
```

Both of these games are solved by the solver with a 9-ply-lookahead search for white's moves. The maximum depth of Game 3a is 13, and the maximum depth of Game 3b is 15.


## Solutions for the Opening Variants

[Solution for Game 1a](https://github.com/jachiam/tak-ai/blob/master/3x3/black-in-corner/game1a.txt)

[Solution for Game 1b](https://github.com/jachiam/tak-ai/blob/master/3x3/black-in-corner/game1b.txt)

[Solution for Game 1ca](https://github.com/jachiam/tak-ai/blob/master/3x3/black-in-corner/game1ca.txt)

[Solution for Game 1cb](https://github.com/jachiam/tak-ai/blob/master/3x3/black-in-corner/game1cb.txt)

[Solution for Game 1cc](https://github.com/jachiam/tak-ai/blob/master/3x3/black-in-corner/game1cc.txt)

[Solution for Game 1cd](https://github.com/jachiam/tak-ai/blob/master/3x3/black-in-corner/game1cd.txt)

[Solution for Game 2](https://github.com/jachiam/tak-ai/blob/master/3x3/black-in-corner/game2.txt)

[Solution for Game 3a](https://github.com/jachiam/tak-ai/blob/master/3x3/black-in-corner/game3a.txt)

[Solution for Game 3b](https://github.com/jachiam/tak-ai/blob/master/3x3/black-in-corner/game3b.txt)
