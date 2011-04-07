# Requires underscore, zepto, raphael, backbone, and socket.io.
_        = this._
{Model, Collection, Events} = this.Backbone
$        = this.Zepto
Raphael  = this.Raphael
io       = this.io

DoD = {}
GameBoard = undefined
paper = this.paper = {}

# Helper function duplicated. Should I bring in `dice_of_doom.coffee`?
player_letter = (num) ->
  String.fromCharCode(num + 97)

# Present a list of move choices to the player and set up event handling.
handle_moves = (moves) ->
  GameBoard.set { moves: moves }
  $container = $('#moves').html('')
  for n, action of moves
    $el = $('<a href="#"></a>')
    text = n + '. '
    if _.isEmpty(action)
      text += "end turn"
      end = true
    else
      text += action[0] + ' ~> ' + action[1]
    $el.text(text)
    $container.append($el)
    $container.append($('<br>'))
    do (n) ->
      $el.bind 'click', () ->
        socket.send {
          move: n
        }
        if end
          $container.html('')
        false

# This should go elsewhere.
handle_player = (player) ->
  $('#status').html(player + '\'s turn to move.')

# Draw the board.
handle_board  = (board) ->
  GameBoard.set { board: board }
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
  $('#world').html(buf)

# ## Drawing

# ### Raphael definitions

Raphael.fn.die = (x, y) ->
  set = this.set()
  set.push(
    this.path("M-31.143-49.248L0.667-36.692l20.09-12.556c0,0-26.537-6.674-28.042-6.278S-31.143-49.248-31.143-49.248z")
    this.path("M0.667-36.692V0c0,0-30.552-18.103-31.391-18.957c-0.838-0.854-0.418-30.292-0.418-30.292L0.667-36.692z")
    this.path("M0.667-36.692l20.09-12.556c0,0,1.22,30.158,0,31.251S0.667,0,0.667,0V-36.692z")
  )
  set.translate(x, y)

Raphael.fn.tile = (x, y) ->
  set = this.set()
  set.push(
    this.path(
      "M3.2,32l-49.8-14.376l0-28.752L3.2-25.504L53-11.128c0,0,0.749,27.126-0.001,28.752S3.2,32,3.2,32z"
    ).attr({fill:'white'})
    this.path(
      "M3.2,25.968c-1.396-0.403-49.8-14.376-49.8-14.376l0-28.752L3.2-31.536L53-17.16L53,11.592C53,11.592,4.596,26.371,3.2,25.968z"
    ).attr({fill:'white'})
  ).translate(x, y)

# ### The game board

class Board extends Model

  initialize: ->

    # Construct an array of tile objects.
    tiles = []
    bs = @get 'board_size'
    xoffset = bs * 50

    for y in [0...bs]
      for x in [0...bs]
        xx = (x * 100) - (y * 50) + xoffset
        yy = (y * 44) + 50
        tiles.push new Tile({
          pos: (y * bs) + x
          paper: @get 'paper'
          x: xx
          y: yy
          board: this
        })

    @set { tiles: tiles }, { silent: true }

    @bind 'change:board', change_board
    @bind 'change:moves', change_moves
    @bind 'click:tile', click_tile

  # Called when the board is changed
  change_board = (model, board) ->
    tiles = model.get 'tiles'
    for hex, n in board
      tiles[n].set { hex: hex }

  change_moves = (model, moves) ->
    srcs = _.uniq _.map moves, (m) -> 
      if _.isEmpty(m)
        "end" # An empty move is a turn end.
      else
        m[0]
    tiles = model.get 'tiles'
    for s in srcs
      if s isnt "end"
        tiles[s].set {
          moves: _.filter moves, (m) -> m[0] is s
        }

  click_tile = (model, tile) ->
    # To fill...
    console.log("tile " + tile.get('pos') + " clicked!")
        
class Tile extends Model

  COLORS =  [ "red", "green" ]

  initialize: ->

    paper   = @get 'paper'
    player  = @get 'player'
    x       = @get 'x'
    y       = @get 'y'
    pos     = @get 'pos'
    board   = @get 'board'

    drawn = {
      tile: paper.tile(x, y)
      num : paper.text(x, y, pos + '' + ' x: ' + x + ' y: ' + y)
    }

    for el in [ 'tile', 'num' ]
      drawn[el].click (e) => 
        board.trigger 'click:tile', board, this

    @set { drawn: drawn }

    @bind 'change:player', change_player
    @bind 'change:dice', change_dice

  change_player = (model, player) ->
    drawn = @get 'drawn'
    drawn.tile.attr({fill: COLORS[@player]})

  change_dice = (model, dice) ->
    drawn = @get 'drawn'
    drawn.num.attr({ text: @get('dice') + ''})

  glow: ->
    @get('drawn').tile.attr({'fill-opacity':0.2})


# ## Socket interface
socket = new io.Socket()

socket.on 'message', (msg) ->
  if msg.DoD
    DoD = msg.DoD
  if msg.board
    handle_board(msg.board)
  if msg.player
    handle_player(msg.player)
  if msg.moves
    handle_moves(msg.moves)
  if msg.message
    $('#message').text(msg.message)

socket.on 'disconnect', () ->
  $('#status').text("Disconnected.")

# ## Document ready.
$ () =>
  paper = Raphael("raphael", 600, 600)
  this.paper = paper
  socket.connect()
  GameBoard = new Board({ paper: this.paper, board_size: 3 })

this.socket = socket
this.Board = Board

