_   = this._
$   = this.Zepto
io  = this.io
DoD = {}

# Helper function duplicated. Should I bring in `dice_of_doom.coffee`?
player_letter = (num) ->
  String.fromCharCode(num + 97)

# Present a list of move choices to the player and set up event handling.
handle_moves = (moves) ->
  console.log(moves)
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
$ () ->
  socket.connect()

this.socket = socket
