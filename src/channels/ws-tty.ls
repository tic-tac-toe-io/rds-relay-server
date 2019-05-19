#
# Copyright (c) 2019 T2T Inc. All rights reserved
# https://www.t2t.io
# https://tic-tac-toe.io
# Taipei, Taiwan
#
require! <[express lodash request]>
{DBG, ERR, WARN, INFO} = global.ys.services.get_module_logger __filename

const NAMESPACE = \tty


module.exports = exports =
  name: "ws-#{NAMESPACE}"

  attach: (name, environment, configs, helpers) ->
    return <[web agent-manager]>

  init: (p, done) ->
    app = @
    am = app['agent-manager']
    app.web.use-ws NAMESPACE, (s) -> return am.add-ws s
    return done!

  fini: (p, done) ->
    return done!
