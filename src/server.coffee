http = require 'http'
io   = require 'socket.io'
fs   = require 'fs'
coffeescript = require 'coffee-script'
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
    else
      res.writeHead 200, {'Content-Type': 'text/html'}
      file = './public/index.html'
    fs.readFile file, (status, data) ->
      res.end data

server.listen 8124, "127.0.0.1"
console.log "Server running at 127.0.0.1:8124"

# Socket for handling game client connections.

socket = io.listen(server)

socket.on 'connection', (client) ->

  # Client connected. Start a new game!
  tree = game_tree(gen_board(), 0, 0, true)
  client.send({DoD: DoD})
  play_vs_computer tree, client
  
  client.on 'message', (msg) ->
    console.log('message: ' + msg)
  client.on 'disconnect', ->
    console.log("disconnect!")

# Print game info.
print_info = (tree, client) ->
  board = tree[1]
  player = player_letter tree[0]
  client.send {
    board:  board
    player: player
  }

ascii_board = (board) ->
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
  buf.join("")

play_vs_computer = (tree, client) ->
  print_info tree, client
  if _.isEmpty get_moves(tree)
    announce_winner(tree[1])

  # If not, handle the tree.
  else
    if (tree[0] == 0)
      true
      #handle_human(tree, play_vs_computer)
    else
      play_vs_computer handle_computer(tree), client

# Announce the winner.
announce_winner = (board, client) ->
  w = winners(board)
  if w.length > 1
    msg = "The game is a tie between" + _.map(w, (n) -> player_letter(n)).join(", ")
  else
    msg = "The winner is" + player_letter(w[0])
  client.send {
    message: msg
  }
