{
  gen_board       : gen_board
  game_tree       : game_tree
  get_moves       : get_moves
  winners         : winners
  player_letter   : player_letter
  handle_computer : handle_computer
  DoD             : DoD
} = require './dice_of_doom.coffee'
_ = require 'underscore'

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

# ## Playing against another human

# Text-based; open up stdin.
stdin = process.openStdin()

# Begin game.
startNewGame = () ->
  play_vs_computer game_tree(gen_board(), 0, 0, true)

# Start a play versus a human for game tree `tree`.
play_vs_human = (tree) ->
  print_info tree

  # The third "slot" in a tree structure is a list of available
  # moves. If there are none left, someone is a winner.
  if _.isEmpty get_moves(tree)
    announce_winner(tree[1])

    console.log("Hit any key for a new game, or control-d to stop.")
    stdin.once 'data', (chunk) -> 
      startNewGame()

  # If not, handle the tree.
  else
    handle_human(tree, play_vs_human)

# Announce the winner.
announce_winner = (board) ->
  console.log("")
  w = winners(board)
  if w.length > 1
    console.log("The game is a tie between", _.map(w, (n) -> player_letter(n)) )
  else
    console.log("The winner is", player_letter(w[0]))

# ## Text interface

# Print game info.
# Remember that the `tree` data structure is [ player, board, moves ].
print_info = (tree) ->
  console.log "current player = ", player_letter(tree[0])
  draw_ascii_board tree[1]

# Handle input from humans. The callback is called after the user
# has made a choice.
handle_human = (tree, callback) ->
  console.log("")
  console.log("choose your move:")
  buf = ["\n"]
  moves = get_moves(tree)
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
  do () ->
    handleChunk = (chunk) ->
      selection = parseInt chunk, 10
      if (moves[selection])
        newTree = moves[selection][1]
        callback(newTree)
      else
        console.log("unknown command.")
        stdin.once 'data', handleChunk

    stdin.once 'data', handleChunk

play_vs_computer = (tree) ->
  print_info tree
  if _.isEmpty get_moves(tree)
    announce_winner(tree[1])

    console.log("Hit any key for a new game, or control-d to stop.")
    stdin.once 'data', (chunk) -> 
      startNewGame()

  # If not, handle the tree.
  else
    if (tree[0] == 0)
      handle_human(tree, play_vs_computer)
    else
      play_vs_computer handle_computer(tree)

# Begin!
startNewGame()
