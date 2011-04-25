#
# Coffeescript adaptation of the Dice of Doom implementation in *Land of Lisp*.
#
# mjhoy | michael.john.hoy@gmail.com


# Use underscore.js.
_ = require 'underscore'

# Lazy evaluation functions.
{ lazy: lazy, force: force } = require './lazy'


# Game parameter object.
DoD = {}

# Define some initial parameters.
DoD.num_players = 4
DoD.max_dice = 5
DoD.board_size = 5
DoD.num_hexes = (DoD.board_size * DoD.board_size)
DoD.ai_level = 2

# ## A helper function

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
  for n in [0...DoD.num_hexes]
    player = randInt(DoD.num_players)
    dice = randInt(DoD.max_dice) + 1
    [player, dice]

# Return the player name for the number (0 -> a, 1 -> b, etc).
player_letter = (num) ->
  String.fromCharCode(num + 97)

# ## Rules

# ### The game tree

# Helper functions to get the player and dice data.
get_player = (pos, board) -> board[pos][0]
get_dice   = (pos, board) -> 
  board[pos][1]

# The moves in a tree may be lazily evaluated; force in this case.
get_moves = (tree) ->
  if _.isFunction tree[2]
    force tree[2]
  else
    tree[2] || []

# In LoL a game tree is generated recursively with all possible
# moves. The "tree" is an array composed of three parts: the
# player whose turn it is, the board, and an array of possible
# moves, which themselves point to new game trees.

# The function to build a tree.
game_tree = (board, player, spare_dice, first_move) ->
  [ 
    player
    board

    # The `moves` array is evaluated lazily. See
    # [lazy.coffee](lazy.html) for the implementation of `lazy`.
    lazy () -> 
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

# Add a "pass" move to the tree.
add_passing_move = (board, player, spare_dice, first_move, moves) ->
  if first_move

    # If this is the first move, a pass isn't a allow. Return the `moves` list unchanged.
    # (i.e., a "passing move" is not added to the possible moves list.)
    moves

  else

    # Append a passing move to the `moves` list.
    moves.push(

      # Create the move. A move is represented by an array. The
      # first element is a description of the move. In the case of a pass,
      # it is an empty array.
      [ 
        []

        # The second element of a move is a game tree representing what happens
        # after this move.
        game_tree(

          # Call the `add_new_dice` function to determine whether any reinforcements
          # should be given to the player at the end of her turn.
          add_new_dice(
            board
            player
            (spare_dice - 1)
          )

          # Because this is a pass, it's the next player's turn.
          ((player + 1) % DoD.num_players)

          # No spare dice for the new player.
          0

          # It is the first turn now.
          true
        )
      ]
    )

    moves

# ### Attacking

# Return a list of possible attacking moves for the given board, current player, and
# also keep track of the spare dice (since spare dice are given for capturing the
# opponents' dice.)
attacking_moves = (board, cur_player, spare_dice) ->


  # We will return the `moves` array at the end, fully populated.
  moves = []

  # Loop through each possible `src` and `dst` tile: the source must
  # be owned by `cur_player`, and the destination must not. The destination
  # tile must also be neighboring; we ensure this with the `neighbors` function.
  for src in [0...DoD.num_hexes]
    if cur_player is get_player(src, board)
      for dst in neighbors(src)
        if (cur_player isnt get_player(dst, board)) and (get_dice(src, board) > get_dice(dst, board))

          # This attack is legitimate for the given tile. Create the move.
          move = [

            # The description of an attacking move is an array which
            # contains the source of the attack and the destination
            # of the attack.
            [ src, dst ]

            # Construct the game tree that would result from a successful attack.
            game_tree(

              # Call the `board_attack` function to change the board
              # itself.
              board_attack(
                board
                cur_player
                src
                dst
                get_dice(src, board)
              )

              # Still the current player's move.
              cur_player

              # Add the number of dice destroyed to the spare pile.
              (spare_dice + get_dice(dst, board))

              # It's still the attacker's move, so it can't be the
              # first move.
              false
            )

            # Construct the game tree that would result from a failed attack.
            # Exactly the same as the above game tree except we call
            # `board_attack_fail` instead.
            game_tree(
              board_attack_fail(
                board
                cur_player
                src
                dst
                get_dice(src, board)
              )
              cur_player
              (spare_dice + get_dice(dst, board))
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

# A failed attack move.
board_attack_fail = (board, player, src, dst, dice) ->
  for index, hex of board
    n = parseInt index, 10

    # The source of the attack is left with one die.
    if n is src
      [ player, 1 ]

    # Otherwise, the board is unchanged.
    else
      hex

# Roll the dice.
roll_dice = (diceNum) ->
  _.inject(
    [0...diceNum]
    (a, b) -> a + randInt(6)
    0
  )

# Make a roll, one pile of dice against another; see if it wins.
roll_against = (srcDice, dstDice) ->
  (roll_dice srcDice) > (roll_dice dstDice)

# Rolling the dice means picking a “chance” branch on a move,
# based on the outcome of the roll of the dice.
pick_chance_branch = (board, move) ->
  [src, dst] = move[0]
  if !src? or roll_against(board[src][1], board[dst][1])
    # This is a passing move, or the attack succeeded.
    move[1]
  else
    # The attack failed.
    move[2]

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

# Calculate the winner[s]. Loop through all the hexes and
# tally up the score for each player. Return an array of
# winners (more than one in case of a tie.)
winners = (board) ->
  score = {}
  for hex in board
    player = hex[0]
    dice = hex[1]
    score[player] or= 0
    score[player] += dice
  max = _.max(score)
  winners = _.map(
    _.select _.keys(score), (key) ->
      score[key] is max
    (n) ->
      parseInt n, 10
  )

# ## Computer AI

# Dice odds: the chance that an attack will succeed. The columns of
# the multi-dimensional array represent the # of attacking dice; the
# rows defending. Used to calculate the rating for attack moves.
DICE_ODDS = 
  [ 
    [ 0.84, 0.97, 1.00, 1.00 ]
    [ 0.44, 0.78, 0.94, 0.99 ]
    [ 0.15, 0.45, 0.74, 0.91 ]
    [ 0.04, 0.19, 0.46, 0.72 ]
    [ 0.01, 0.06, 0.22, 0.46 ]
  ]

# Rate the position for a player and a given tree.
rate_position = (tree, player) ->
  moves = get_moves(tree)
  if moves and (not _.isEmpty(moves))

    # Basic minimax algorithm; the position is the
    # *low* score if this is the opponent's turn.
    if (tree[0] == player)
      _.max get_ratings(tree, player)
    else
      _.min get_ratings(tree, player)

  # No moves remain: calculate the winners.
  else
    score_board tree[1], player

get_ratings = (tree, player) ->
  _.map get_moves(tree), (move) ->
    [src, dst] = move[0]
    board = tree[1]
    if src?
      odds = DICE_ODDS[board[dst][1] - 1][board[src][1] - 2]
      ratings = (odds * rate_position(move[1], player)) +
        ((1 - odds) * rate_position(move[2], player))
      ratings
    else
      rate_position move[1], player

# To handle larger game boards, we need to limit how far ahead the
# computer looks. Then the "unseen" nodes will not need to be
# evaluated, due to the lazily evaluated game tree.
limit_tree_depth = (tree, depth) ->
  [
    tree[0]
    tree[1]
    do () ->
      if depth is 0
        []
      else
        _.map get_moves(tree), (move) ->
          [].concat(
            # Rebuild the move, calling `limit_tree_depth` recursively.
            # A move is composed of a description, and one or two game trees
            # that result (two for an attack, either succeeding or failing).
            [ move[0] ]
            _.map move.slice(1, move.length), (chance_node) ->
              limit_tree_depth chance_node, (depth - 1)
          )
  ]

# Because we limit the game tree for the computer, the leaf nodes are
# not *really* leaf nodes in the game, so we need a better way of rating
# it.
score_board = (board, player) ->
  _.reduce( 
    board
    (memo, hex, pos) ->
      v =
        if hex[0] is player
          if threatened pos, board

            # Player-owned hex is threatened.
            1
          else

            # Player-owned hex is unthreatened.
            2
        else

          # Opponent-owned hex.
          -1
      memo + v
    0
  )

# Is `pos` a threatened hex?
threatened = (pos, board) ->
  hex = board[pos]
  player = hex[0]
  dice = hex[1]
  _.any neighbors(pos), (n) ->
    nhex = board[n]
    nplayer = nhex[0]
    ndice = nhex[1]
    (nplayer isnt player) and (ndice > dice)

# ### Handle the computer game loop

# Returns the tree of the move that the computer decides.
handle_computer = (tree) ->
  player = tree[0]
  ratings = get_ratings limit_tree_depth(tree, DoD.ai_level), player
  move = get_moves(tree)[ratings.indexOf(_.max ratings)]
  pick_chance_branch tree[1], move


# Public functions.
exports.gen_board          = gen_board
exports.game_tree          = game_tree
exports.get_moves          = get_moves
exports.winners            = winners
exports.player_letter      = player_letter
exports.handle_computer    = handle_computer
exports.pick_chance_branch = pick_chance_branch

exports.DoD = DoD
