# Requires underscore, zepto, raphael, backbone, and socket.io.
_        = this._
{Model}  = this.Backbone
$        = this.Zepto
Raphael  = this.Raphael
io       = this.io

DoD = {}
GameBoard = undefined
paper = this.paper = {}

# Helper function, duplicated. Should I bring in `dice_of_doom.coffee`?
player_letter = (num) ->
  String.fromCharCode(num + 97)

# ## Drawing

# ### Raphael definitions

# Function to draw a die.
Raphael.fn.die = (x, y) ->
  set = this.set()
  set.push(
    this.path("M0.591-38.858c0,0-18.941,6.964-20.056,8.356c-1.114,1.393-0.418,20.195,0,21.309S-0.244,0,0.591,0s18.854-8.148,19.22-8.774c0.365-0.627,0.313-21.1,0-21.727C19.498-31.128,0.591-38.858,0.591-38.858z")
    this.path("M-19.388-30.581C-19.423-30.249,0-22.354,0-22.354s19.796-7.839,19.812-8.147c0.015-0.308-19.22-8.356-19.22-8.356S-19.353-30.913-19.388-30.581z")
    this.path("M0.591,0C0.853,0,0-22.354,0-22.354S0.33,0,0.591,0z")
  )
  set.attr({fill:'white'})
  set.translate(x, y)

# Function to draw a hexagonal tile.
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

# ## Game models

# ### The game board 
class Board extends Model

  initialize: ->

    # Generate an array of tile objects.
    tiles = []
    bs = @get 'board_size'
    xoffset = bs * 50 + 10
    yoffset = 80

    for y in [0...bs]
      for x in [0...bs]
        xx = (x * 100) - (y * 50) + xoffset
        yy = (y * 44) + yoffset
        tiles.push new Tile({
          pos: (y * bs) + x
          paper: @get 'paper'
          x: xx
          y: yy
          board: this
        })

    @set { tiles: tiles }, { silent: true }

    # Set up the event bindings.
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
  # list of moves.
  destinations = (source, moves) ->
    _.map(
      _.filter moves, (m) -> m[0] is source
      (m) -> m[1]
    )

  # The board has changed. Tell the tiles.
  change_board = (model, board) ->
    tiles = model.get 'tiles'
    for hex, n in board
      tiles[n].set { hex: hex }

  # Current player changed.
  change_player = (model, player) ->
    if not model.get('winners')
      if player isnt 0 
        $('#status').html('Computer\'s move. Waiting...')
      else
        $('#status').html('')

  # The permissible moves have changed. Set up board behaivor and status.
  change_moves = (model, moves) ->
    model.set { selected: false }

    if model.get('player') is 0
      # See if there exists a passing moves in `moves`.
      passing = false

      for m in moves
        if _.isEmpty m
          passing = m
          break

      el = $('#status')
      if passing
        el.html("Your move. <a href='#'>Pass this move.</a>")
        $(el).children('a').bind 'click', () => 
          console.log('clicked!')
          model.trigger 'makemove', model, passing
          $(el).children('a').unbind 'click'
      else
        el.html("Your move.")

  # A tile has been clicked by the user.
  click_tile = (board, tile) ->
    pos = tile.get 'pos'
    moves = board.get 'moves'
    selected = board.get 'selected'

    # If a tile is currently selected, check if this is a legitimate
    # destination tile.
    if selected or (selected is 0)

      # If the player clicked on the same tile, deselected.
      if selected is pos
        board.set { selected: false}
      else
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

  # Game over.
  change_winners = (model, winners) ->
    w = winners
    if w.length > 1
      msg = "The game is a tie between " + _.map(w, (n) -> player_letter(n)).join(", ") + "."
    else
      if w[0] is 0
        msg = "You won."
      else
        msg = "The computer won."
    msg += " <a href='/'>Reload for another.</a>"
    $('#status').html(msg)


# ### The tile
class Tile extends Model

  COLORS =  [ "green", "red" ]

  initialize: ->

    paper   = @get 'paper'
    x       = @get 'x'
    y       = @get 'y'
    board   = @get 'board'

    drawn = {
      tile: paper.tile(x, y)
    }

    for el in [ 'tile' ]
      drawn[el].click (e) => 
        board.trigger 'click:tile', board, this

    @set { drawn: drawn }

    @bind 'change:hex', change_hex
    @bind 'change:selected', change_selected

  # The hex that the tile represents has changed. A hex is an
  # array with two pieces of information: player number, and number of dice.
  change_hex = (model, hex) ->
    player = hex[0]
    dice = hex[1]

    drawn = model.get 'drawn'
    paper = model.get 'paper'
    board = model.get 'board'
    x = model.get 'x'
    y = model.get 'y'

    # Set the tile color.
    drawn.tile.attr({fill: COLORS[player]})

    # [Re]draw the dice.
    _.each(drawn.dice, (d) -> d.remove()) if drawn.dice
    drawn.dice = []
    for n in [0...dice]
      die = paper.die(x, (y - (n * 20) + 10))
      die.attr({fill: COLORS[player]})
      die.click (e) =>
        board.trigger 'click:tile', board, this
      drawn.dice.push die

  # Fade in or out the tile if it's been selected or deselected.
  change_selected = (model, selected) ->
    drawn = model.get 'drawn'
    if selected
      drawn.tile.animate({'fill-opacity':0.3}, 50)
    else
      drawn.tile.animate({'fill-opacity':1.0}, 50)

# ## Socket interface
socket = new io.Socket()

# Receive a message from the server. 
# Kind of a control flow mess right now, needs cleanup.
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
    moves = msg.moves
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

  if msg.winners
    GameBoard.set { winners: msg.winners }

# If the server disconnects.
socket.on 'disconnect', () ->
  $('#status').text("Disconnected.")

# ## Document ready. 
# Set up the Raphael paper object and connect.
$ () =>
  paper = Raphael("raphael", 420, 240)
  this.paper = paper
  socket.connect()

this.socket = socket
this.Board = Board
