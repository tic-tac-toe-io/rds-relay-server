#
# Copyright (c) 2019 T2T Inc. All rights reserved
# https://www.t2t.io
# https://tic-tac-toe.io
# Taipei, Taiwan
#
require! <[lodash url querystring uuid]>
{DBG, ERR, WARN, INFO} = global.ys.services.get_module_logger __filename


const DEFAULT_CONFIGS = userdb: {}


RETURN_AUTH_CB = (done, message="", authenticated=no) ->
  ERR "failed to authenticate, err => #{message}" if message?
  return done message, authenticated


class AuthToken
  (@manager, @username) ->
    @id = uuid.v4!.toUpperCase!.substring 24
    @created_at = new Date!


class AuthManager
  (@environment, configs, @helpers, @app) ->
    @configs = lodash.merge {}, DEFAULT_CONFIGS, configs
    @userdb = @configs.userdb
    @tokens = {}
    INFO "configs => #{JSON.stringify @configs}"
    return

  init: (done) ->
    return done!

  fini: (done) ->
    return done!

  create-token: (username) ->
    {tokens} = self = @
    {id} = t = new AuthToken self, username
    tokens[id] = t
    return t

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
      token = self.create-token username
      return done null, {username, token}
    return f

  resolve-socketio: (uri) ->
    {userdb} = self = @
    {protocol, hostname, pathname} = tokens = url.parse uri
    sioAuth = (socket, username, password, done) ->
      if password is ""
        uri = username
        INFO "authenticating #{socket.id} => #{uri}"
        {protocol, hostname, pathname, query} = xs = url.parse uri
        qs = querystring.parse query
        INFO "username/#{qs.username} is parsed to #{JSON.stringify xs}"
        return RETURN_AUTH_CB done, "unsupported method: #{protocol}" unless protocol is "token:"
        id = hostname.toUpperCase!
        token = self.tokens[id]
        return RETURN_AUTH_CB done, "no such token #{id}" unless token?
        return RETURN_AUTH_CB done, "the token #{id} is not used for user/#{username}" unless token.username is qs.username
        INFO "authenticated #{qs.username} with token/#{id}"
        return done null, yes
      else
        INFO "authenticating #{socket.id}, #{username}, #{password}"
        db = userdb[tokens.hostname]
        return RETURN_AUTH_CB done, "no such #{tokens.hostname} in userdb to authenticate #{username}/#{password}" unless db?
        pswd = db[username]
        return RETURN_AUTH_CB done, "no such user #{username} in userdb/#{hostname}" unless pswd?
        return RETURN_AUTH_CB done, "password #{password} is not matched to #{username}" unless password == pswd
        INFO "authenticated #{username} with password"
        return done null, yes
    # return userdb[hostname] if protocol is \userdb:
    return sioAuth if protocol is \userdb:
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
