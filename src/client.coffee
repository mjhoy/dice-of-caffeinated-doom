# Requires underscore, zepto, raphael, backbone, and socket.io.
_        = this._
{Model} = this.Backbone
$        = this.Zepto
Raphael  = this.Raphael
io       = this.io

DoD = {}
GameBoard = undefined
paper = this.paper = {}

# Helper function duplicated. Should I bring in `dice_of_doom.coffee`?
player_letter = (num) ->
  String.fromCharCode(num + 97)

# Send the move list to the GameBoard and set up an event handler for
# when the user chooses a move.
handle_moves = (moves) ->
  GameBoard.set { moves: moves }
  GameBoard.bind 'makemove', (board, chosen_move) ->
    for n, action of moves
      if (
        # A passing move is chosen.
        (_.isEmpty action) and (_.isEmpty chosen_move)
      ) or (
        # An attacking move is chosen.
        (action[0] is chosen_move[0]) and (action[1] is chosen_move[1])
      )
        socket.send { move: n }

      # Only allow this event to be called once.
      GameBoard.unbind 'makemove'


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
    @bind 'change:player', change_player
    @bind 'change:moves', change_moves
    @bind 'click:tile', click_tile
    @bind 'change:selected', change_selected
    @bind 'change:winners', change_winners

  # Get a unique list of legitimate source tiles for moves.
  unique_sources = (moves) ->
    srcs = _.flatten _.uniq _.map moves, (m) -> 
      m[0] unless _.isEmpty(m)

  # Get a list of every possible destination for a source from
  # list of moves
  destinations = (source, moves) ->
    _.map(
      _.filter moves, (m) -> m[0] is source
      (m) -> m[1]
    )

  # Called when the board is changed
  change_board = (model, board) ->
    tiles = model.get 'tiles'
    for hex, n in board
      tiles[n].set { hex: hex }

  change_player = (model, player) ->
    if not model.get('winners')
      $('#status').html(player_letter(player) + '\'s turn...')
      if player isnt 0 
        $('#pass').html('Waiting...')

  change_moves = (model, moves) ->
    model.set { selected: false }

    if model.get('player') is 0
      # See if there exists a passing moves in `moves`.
      passing = false

      for m in moves
        if _.isEmpty m
          passing = m
          break

      el = $('#pass')
      if passing
        el.html("Your move. <a href='#'>Pass this move.</a>")
        $(el).children('a').bind 'click', () => 
          console.log('clicked!')
          model.trigger 'makemove', model, passing
          $(el).children('a').unbind 'click'
      else
        el.html("Your move. (Can't pass.)")

  change_winners = (model, winners) ->
    w = winners
    if w.length > 1
      msg = "The game is a tie between " + _.map(w, (n) -> player_letter(n)).join(", ") + "."
    else
      msg = "The winner is " + player_letter(w[0]) + "."
    msg += " <a href='/'>Reload for another.</a>"
    $('#status').html(msg)
    $('#pass').html('')

  click_tile = (board, tile) ->
    pos = tile.get 'pos'
    moves = board.get 'moves'
    selected = board.get 'selected'

    # If a tile is currently selected, check if this is a legitimate
    # destination tile.
    if selected or (selected is 0)
      dsts = destinations(selected, moves)
      if _.include dsts, pos
        board.set { selected: false }
        board.trigger 'makemove', board, [ selected, pos ]

    # If a tile hasn't been selected, check if this is a legitimate source.
    else if moves
      srcs = unique_sources(moves)
      if _.include srcs, pos
        board.set { selected: pos }

  change_selected = (board, selected) ->
    tiles = board.get 'tiles'
    for t in tiles
      pos = t.get 'pos'
      if pos is selected
        t.set { selected: true }
      else
        t.set { selected: false }


class Tile extends Model

  COLORS =  [ "green", "red" ]

  initialize: ->

    paper   = @get 'paper'
    x       = @get 'x'
    y       = @get 'y'
    board   = @get 'board'

    drawn = {
      tile: paper.tile(x, y)
      num : paper.text(x, y, '0')
    }

    for el in [ 'tile', 'num' ]
      drawn[el].click (e) => 
        board.trigger 'click:tile', board, this

    @set { drawn: drawn }

    @bind 'change:hex', change_hex
    @bind 'change:selected', change_selected

  change_hex = (model, hex) ->
    drawn = model.get 'drawn'
    player = hex[0]
    dice = hex[1]
    drawn.tile.attr({fill: COLORS[player]})
    drawn.num.attr({text: dice + ''})

  change_selected = (model, selected) ->
    drawn = model.get 'drawn'
    if selected
      drawn.tile.attr({'fill-opacity':0.3})
    else
      drawn.tile.attr({'fill-opacity':1.0})


  glow: ->
    @get('drawn').tile.attr({'fill-opacity':0.2})


# ## Socket interface
socket = new io.Socket()

socket.on 'message', (msg) =>
  if msg.DoD
    DoD = msg.DoD
    GameBoard = new Board({ paper: this.paper, board_size: DoD.board_size })
    this.GameBoard = GameBoard
  if msg.board
    GameBoard.set { board: msg.board }
  if msg.player
    GameBoard.set { player: parseInt(msg.player, 10) }
  if msg.moves
    handle_moves(msg.moves)
  if msg.message
    $('#message').text(msg.message)
  if msg.winners
    GameBoard.set { winners: msg.winners }

socket.on 'disconnect', () ->
  $('#status').text("Disconnected.")

# ## Document ready.
$ () =>
  paper = Raphael("raphael", 420, 200)
  this.paper = paper
  socket.connect()

this.socket = socket
this.Board = Board

