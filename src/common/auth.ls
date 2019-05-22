#
# Copyright (c) 2019 T2T Inc. All rights reserved
# https://www.t2t.io
# https://tic-tac-toe.io
# Taipei, Taiwan
#
require! <[lodash url]>
{DBG, ERR, WARN, INFO} = global.ys.services.get_module_logger __filename


const DEFAULT_CONFIGS = userdb: {}


class AuthManager
  (@environment, configs, @helpers, @app) ->
    @configs = lodash.merge {}, DEFAULT_CONFIGS, configs
    @userdb = @configs.userdb
    INFO "configs => #{JSON.stringify @configs}"
    return

  init: (done) ->
    return done!

  fini: (done) ->
    return done!

  generate-pasport-http-auth: (uri) ->
    {userdb} = self = @
    {protocol, hostname, pathname} = tokens = url.parse uri
    return null unless protocol is \userdb:
    users = userdb[hostname]
    WARN "no such user group #{hostname.yellow}" unless users?
    return null unless users?
    f = (username, password, done) ->
      u = users[username]
      return done null, no unless u?
      return done null, no unless u is password
      return done null, {username}
    return f

  resolve-socketio: (uri) ->
    {userdb} = self = @
    {protocol, hostname, pathname} = tokens = url.parse uri
    return userdb[hostname] if protocol is \userdb:
    return pathname if protocol is \file:
    WARN "unsupported authenticator uri: #{uri}"
    return null


module.exports = exports =
  name: \auth

  attach: (name, environment, configs, helpers) ->
    app = @
    app[name] = auth = new AuthManager environment, configs, helpers, app
    return null

  init: (p, done) ->
    return p.init done

  fini: (p, done) ->
    return p.fini done!
