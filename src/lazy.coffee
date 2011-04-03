lazy = (fn) ->
  value = undefined
  forced = false
  () ->
    if forced
      value
    else
      forced = true
      value = fn()
      value

force = (lazy_fn) ->
  lazy_fn()

exports.lazy = lazy
exports.force = force
