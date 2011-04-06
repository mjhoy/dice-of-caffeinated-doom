$   = this.Zepto
io  = this.io
DoD = {}

player_letter = (num) ->
  String.fromCharCode(num + 97)

handle_player = (player) ->
  $('#status').html(player)

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

socket = new io.Socket()
socket.on 'message', (msg) ->
  if msg.DoD
    DoD = msg.DoD
  if msg.board
    handle_board(msg.board)
  if msg.player
    handle_player(msg.player)

# Document is ready.
$ () ->
  socket.connect()

this.socket = socket
