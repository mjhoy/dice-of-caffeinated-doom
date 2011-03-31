# Dice of Doom
# mjhoy | michael.john.hoy@gmail.com
#
# Adaptation of the implementation in *Land of Lisp*.

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

# In our game we will simply use an array of an array; e.g.,
#
#     [ [ 1, 1 ],
#       [ 1, 1 ],
#       [ 0, 1 ],
#       [ 1, 3 ],
#       [ 0, 2 ] ]
# 
# and so on.

# Generate a board for `n_hexes` number of hexes, `n_players` number
# of players, `max_dice` maximum number of dice allowed.
gen_board = (n_hexes, n_players, max_dice) ->
  for n in [0..n_hexes]
    player = randInt(n_players)
    dice = randInt(max_dice) + 1
    [player, dice]

# Return the player name for the number (0 -> a, 1 -> b, etc).
player_letter = (num) ->
  String.fromCharCode(num + 97)

# Output an ascii representation of the board.
draw_ascii_board = (board, board_size) ->
  buf = []
  for y in [0...board_size]
    buf.push("\n")
    do (y) ->
      for n in [0...(board_size - y)]
        buf.push("  ")
    for x in [0...board_size]
      hex = board[x + (y * board_size)]
      buf.push(player_letter(hex[0]) + "-" + hex[1] + " ")
  buf = buf.join("")

  # Just use console.log for output now.
  console.log(buf)

# Test.
draw_ascii_board(gen_board(4, 2, 3), 2)
