http         = require 'http'
io           = require 'socket.io'
fs           = require 'fs'
coffeescript = require 'coffee-script'
_            = require 'underscore'
{
  gen_board       : gen_board
  game_tree       : game_tree
  get_moves       : get_moves
  winners         : winners
  player_letter   : player_letter
  handle_computer : handle_computer
  DoD             : DoD
} = require './dice_of_doom.coffee'


# ## A really silly server
server = http.createServer (req, res) ->

  #  Compile the client coffeescript.
  if req.url is '/client.js'
    res.writeHead 200, {'Content-Type': 'text/javascript'}
    fs.readFile './src/client.coffee', (status, data) ->
      res.end coffeescript.compile(data + '')
  else 
    if req.url is '/zepto.js'
      res.writeHead 200, {'Content-Type': 'text/javascript'}
      file = './public/zepto.js'
    else if req.url is '/underscore.js'
      res.writeHead 200, {'Content-Type': 'text/javascript'}
      file = './public/underscore.js'
    else
      res.writeHead 200, {'Content-Type': 'text/html'}
      file = './public/index.html'
    fs.readFile file, (status, data) ->
      res.end data

server.listen 8124, "127.0.0.1"
console.log "Server running at 127.0.0.1:8124"

# ## Socket interface

# Socket for handling game client connections.
socket = io.listen(server)

socket.on 'connection', (client) ->

  # Client connected. Start a new game!
  tree = game_tree(gen_board(), 0, 0, true)

  # Send the client game constants.
  client.send({DoD: DoD})

  
  # Handle client actions.
  client.on 'message', (msg) ->
    console.log('message: ' + msg)
  client.on 'disconnect', ->
    console.log("disconnect!")

  # Start the game.
  play_vs_computer tree, client

# ## Game server logic

# Simplify an array of moves into just an array of action descriptions 
# (i.e., don't include the game trees).
client_moves = (moves) ->
  for move in moves
    move[0]

# Send game information to the client.
print_info = (tree, client) ->
  board = tree[1]
  player = player_letter tree[0]
  client.send {
    board:  board
    player: player
  }

# Run a turn.
play_vs_computer = (tree, client) ->
  print_info tree, client
  if _.isEmpty get_moves(tree)
    announce_winner(tree[1], client)
  else
    if (tree[0] == 0)
      handle_web_human tree, client
    else
      handle_web_computer tree, client

# Handle the web computer's turn. Set a second timeout for the move to get played,
# so the user can see what's going on.
handle_web_computer = (tree, client) ->
  setTimeout(
    () ->
      client.send {
        message: player_letter(tree[0]) + ' moved.'
      }
      play_vs_computer handle_computer(tree), client
    1000
  )

# Handle the human web client. Send a list of
# possible moves.
handle_web_human = (tree, client) ->
  moves = get_moves(tree)
  client.send {
    moves: client_moves(moves)
  }
  client.removeAllListeners 'message'
  client.on 'message', (msg) ->
    if msg.move
      newTree = moves[parseInt(msg.move,10)][1]
      play_vs_computer newTree, client

# Announce winner. Some of this should go in client.coffee.
announce_winner = (board, client) ->
  w = winners(board)
  if w.length > 1
    msg = "The game is a tie between " + _.map(w, (n) -> player_letter(n)).join(", ")
  else
    msg = "The winner is " + player_letter(w[0])
  client.send {
    message: msg
  }
