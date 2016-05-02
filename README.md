# TAK A.I. G.U.I.
*Solving the party before it's even started*

Chiseled from the bedrock of primordial chaos by Tobias Akira

AI engine made by [Joshua Achiam](github.com/jachiam/tak-ai): If you lose, it's his fault.

Special thanks to the [LOVE game engine team](love2d.org), in tandem with [vrld's SUIT library](https://github.com/vrld/SUIT), without whom you would probably still be playing an actually-entertaining game.                        

### Installation
|Linux|Mac|Windows|
|-----|---|-------|
|works|totally|oops|


**Linux/Mac Install:** 
```
curl https://asgardiator.github.io/tak-ai-ghpage/ | sh
```

**Windows Users:** Sorry, but until [torch](torch.ch) makes their library available for Windows, you're going to have to sit tight. Alternatively, you can fight the AI using a prettier interface on [playtak](playtak.com). You can also switch to [Ubuntu](ubuntu.com/download).

### People?
If you want to play against real people instead: [playtak.com](playtak.com)! They also have other, less difficult bots that you can fight.

### Community??
For only the finest bantz and advice on how to git gud: [Tak forums](reddit.com/r/tak)! 

### Freedom???
Finally, if you're a nerd who enjoys freedom, & you also make too much money, you can show your appreciaton with a bitcoin donation:

![Enable a Dude to Continue Being Radical](https://chart.googleapis.com/chart?cht=qr&chs=200x200&chl=141XmwzWyXu7VEahTjKpHTFVq4CKT9BLZ2)
```
bitcoin://141XmwzWyXu7VEahTjKpHTFVq4CKT9BLZ2
```

If it helps, try to imagine a puppy begging for kibbles. But instead of kibbles,it's magic internet money that fights the system, then goes and starts its own system, with blackjack and hookers.  

## How to play
If you manage to start the game, congratulations, you've qualified for a CS degree. But don't build the next Facebook yet; we've got games to lose to weak heuristics.

Once the game begins, you will see a hideous technicolor board and some kitschy 8bit typography. This is good; it means it's working. Now we have to interface with the only controller in the game: the textbox. Physically click it in the lower-left corner to get started. Yes, I tried to autofocus. The GUI library was not forgiving.

|Command|Action|
|-------|------|
|[A move in [Portable Tak Notation](https://www.reddit.com/r/Tak/wiki/portable_tak_notation)]|Make that move in the current game, if legal.|
|help|list commands in a popup|
|[escape key]|close help menu|
|quit|...|
|export [filename]|save game to filename.ptn|
|import [filename]|load from filename.ptn *not implemented yet; please use [PTN Viewer](https://jsfiddle.net/bwochinski/043hpzwu/embedded/result/)|
|new|start new game|
|undo|undo your last move|
|name [username]|set your name|
|level [1-3]|set AI level|
|win|immediately win the game|
|resign|wave the white flag|
|ai|have the AI move for you this turn|
|opp [opponent_name]|set the opponent's name (takai, takei, takarlo)|
|fs|toggle fullscreen (content warning: hideous)|