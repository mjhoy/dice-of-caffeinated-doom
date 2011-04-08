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


# ## Asset server
staticServer = http.createServer (req, res) ->

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
    else if req.url is '/backbone.js'
      res.writeHead 200, {'Content-Type': 'text/javascript'}
      file = './public/backbone.js'
    else if req.url is '/raphael.js'
      res.writeHead 200, {'Content-Type': 'text/javascript'}
      file = './public/raphael.js'
    else
      res.writeHead 200, {'Content-Type': 'text/html'}
      file = './public/index.html'
    fs.readFile file, (status, data) ->
      res.end data

staticServer.listen 8124, "127.0.0.1"
console.log "Server running at 127.0.0.1:8124"

# ## Socket server

socketServer = http.createServer (req, res) ->
  res.writeHead 200, { 'Content-Type': 'text/plain' }
  res.end "Socket server up."

socketServer.listen 9989


# ## Socket interface

# Socket for handling game client connections.
socket = io.listen(socketServer)

socket.on 'connection', (client) ->

  # Client connected. Start a new game!
  tree = game_tree(gen_board(), 0, 0, true)

  # Send the client game constants.
  client.send({DoD: DoD})

  
  # Handle client actions.
  client.on 'message', (msg) ->
  client.on 'disconnect', ->

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
  player = tree[0]
  client.send {
    board:  board
    # Can't send a 0, make a string.
    player: player + ''
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
  client.send {
    winners: w
  }
