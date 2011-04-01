# Dice of Doom
# mjhoy | michael.john.hoy@gmail.com
#
# Adaptation of the implementation in *Land of Lisp*.


# Use underscore.js
_ = require 'underscore'

# Game parameter object.
DoD = {} unless DoD?

# Define some initial parameters.
DoD.num_players = 2
DoD.max_dice = 3
DoD.board_size = 2
DoD.num_hexes = (DoD.board_size * DoD.board_size)

# ## Little helper functions.

# Return a random integer between 0 and n, not inclusive.
randInt = (n) ->
  Math.floor(Math.random() * n)

# ## Representing the game board
#
# In LoL, the game board was represented as an array of lists with
# a length of two: `#((0 3) (0 3) (1 3) (1 1))`. Each list represents
# a "tile" on the game. The first number is the player number, and
# the second is the number of dice.

# In our game we will simply use an array of arrays; e.g.,
#
#     [ [ 1, 1 ],
#       [ 1, 1 ],
#       [ 0, 1 ],
#       [ 1, 3 ],
#       [ 0, 2 ] ]
# 
# and so on.

# Generate a the board data structure.
gen_board = () ->
  for n in [0..DoD.num_hexes]
    player = randInt(DoD.num_players)
    dice = randInt(DoD.max_dice) + 1
    [player, dice]

# Return the player name for the number (0 -> a, 1 -> b, etc).
player_letter = (num) ->
  String.fromCharCode(num + 97)

# Output an ascii representation of the board.
draw_ascii_board = (board) ->
  bs = DoD.board_size
  buf = []
  for y in [0...bs]
    buf.push("\n")
    do (y) ->
      for n in [0...(bs - y)]
        buf.push("  ")
    for x in [0...bs]
      hex = board[x + (y * bs)]
      buf.push(player_letter(hex[0]) + "-" + hex[1] + " ")
  buf = buf.join("")

  # Just use console.log for output now.
  console.log(buf)

# ## Rules

# ### The game tree

# In LoL a game tree is generated recursively with all possible
# moves. The "tree" is an array composed of three parts: the
# player whose turn it is, the board, and an array of possible
# moves, which themselves point to new game trees.

# The function to build a tree. Coffeescript does not format nicely here...
game_tree = (board, player, spare_dice, first_move) ->
  [ 
    player
    board
    add_passing_move( 
      board 
      player 
      spare_dice 
      first_move 
      attacking_moves( 
        board 
        player 
        spare_dice
      )
    ) 
  ]

# Add a "pass" move to the tree, unless it is the first move.
add_passing_move = (board, player, spare_dice, first_move, moves) ->
  if first_move

    # Return the `moves` list unchanged.
    moves

  else

    # Append to the `moves` list.
    moves.push(

      # Create the "passing" move. A move is represented by an array. The
      # first element is a description of the move. In the case of a pass,
      # it is an empty array.
      [ 
        []
        # The second element of a move is a game tree representing what happens
        # if this move were to be 
        game_tree(
          add_new_dice(
            board
            player
            (spare_dice - 1)
          )

          # Next player
          ((player + 1) % DoD.num_players)

          # No spare dice.
          0

          # It is the new player's first turn.
          true
        )
      ]
    )

    moves

# ### Attacking

# Calculating attacking moves.
attacking_moves = (board, cur_player, spare_dice) ->

  # Helper functions to get the player and dice data.
  player = (pos) -> board[pos][0]
  dice   = (pos) -> board[pos][1]

  moves = []
  for src in [0...DoD.num_hexes]
    if cur_player is player(src)
      for dst in neighbors(src)
        if (cur_player isnt player(dst)) and (dice(src) > dice(dst))

          # This attack is legitimate. Create the move.
          move = [

            # The description of an attacking move is an array which
            # contains the source of the attack and the destination
            # of the attack.
            [ src, dst ]

            # Now construct the new game tree that would result from
            # the attack.
            game_tree(

              # Call the `board_attack` function to change the board
              # itself.
              board_attack(
                board
                cur_player
                src
                dst
                dice(src)
              )

              # Still the current player's move.
              cur_player

              # Add the number of dice destroyed to the spare pile.
              (spare_dice + dice(dst))

              # It's still the attacker's move, so it can't be the
              # first move.
              false
            )
          ]
          moves.push(move)
  moves

# Return an array of positions that are neighbors (on the hexagonal grid).
neighbors = (pos) ->
  bs = DoD.board_size
  up = pos - bs
  down = pos + bs
  lst = [
    up
    down
  ]

  # Add nearby hexes, and don't wrap around the board.
  lst.push(up - 1, pos - 1) if pos % bs
  lst.push(pos + 1, down + 1) if (pos + 1) % bs

  # Filter out any hexes that aren't on the board.
  _.filter lst, (n) ->
    (n >= 0) and (n < DoD.num_hexes)

# Play out an attack move on the board.
board_attack = (board, player, src, dst, dice) ->
  for index, hex of board
    n = parseInt index, 10

    # The source of the attack is left with one die.
    if n is src
      [ player, 1 ]

    # The destination of the attack is left with the
    # rest of the dice.
    else if n is dst
      [ player, (dice - 1) ]

    # Otherwise, the board is unchanged.
    else
      hex

# ### Reinforcements

# Reinforce the board after play is done. The `spare_dice` counter is kept
# as a turn progresses; it increases as a player captures enemy dice.
add_new_dice = (board, player, spare_dice) ->
  # Keep track of remaining dice as we give them out.
  remaining_dice = spare_dice
  for hex in board
    cur_player = hex[0]
    cur_dice = hex[1]
    # If this square can receive dice, give one and continue on.
    if (remaining_dice > 0) and (cur_player is player) and (cur_dice < DoD.max_dice)
      remaining_dice -= 1
      [ cur_player, cur_dice + 1 ]
    else
      hex



# ## Playing against another human

# Text-based; open up stdin.
stdin = process.openStdin()

# Start a play versus a human for game tree `tree`.
play_vs_human = (tree) ->
  print_info tree

  # The third "slot" in a tree structure is a list of available
  # moves. If there are none left, someone is a winner.
  if _.isEmpty tree[2]
    announce_winner(tree[1])

  # If not, handle the tree.
  else
    handle_human(tree)

# Calculate the winner[s].
winners = (board) ->
  "foo"

announce_winner = (board) ->
  "bar."


# ## Text interface

# Print game info.
# Remember that the `tree` data structure is [ player, board, moves ].
print_info = (tree) ->
  console.log "current player = ", player_letter(tree[0])
  draw_ascii_board tree[1]

# Handle input from humans
handle_human = (tree) ->
  console.log("")
  console.log("choose your move:")
  buf = ["\n"]
  moves = tree[2]
  for n, move of moves

    # The first element of a `move` is a description of the action.
    action = move[0] 
    buf.push n, ". "

    # If the action is an empty list, it's a passing move.
    if _.isEmpty(action)
      buf.push "end turn \n"
    else
      buf.push action[0] + " -> " + action[1] + "\n"
  console.log(buf.join("") + "\n")

  # Handle user input. Node requires here that `stdin` be non-blocking, so unlike the
  # implementation in *Land of Lisp* we generate a callback function to run when the
  # user makes a choice.
  #
  # TODO: error handling.
  stdin.once 'data', (chunk) -> 
    selection = parseInt chunk, 10
    newTree = moves[selection][1]
    play_vs_human(newTree)


# Begin play on a 2x2 board.
play_vs_human game_tree(gen_board(), 0, 0, true)
