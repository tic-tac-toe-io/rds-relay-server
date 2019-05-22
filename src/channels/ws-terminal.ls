#
# Copyright (c) 2019 T2T Inc. All rights reserved
# https://www.t2t.io
# https://tic-tac-toe.io
# Taipei, Taiwan
#
require! <[lodash]>
{DBG, ERR, WARN, INFO} = global.ys.services.get_module_logger __filename

const NAMESPACE = \terminal


class SocketWrapper
  (@ws, @prefix, @user, @index, @manager, @agent-manager) ->
    self = @
    self.connected-at = new Date!
    ws.on \disconnect, -> return self.on-disconnct!
    ws.on \command, (buf) -> return self.on-command "#{buf}"

  on-disconnct: ->
    @manager.remove @
    return

  err-disconnect: (msg) ->
    {ws} = @
    ws.emit \err, msg
    ws.disconnect!

  on-command: (text) ->
    {ws, prefix} = @
    cmd = null
    try
      cmd = JSON.parse text
    catch error
      msg = "failed to parse command: #{text}"
      ERR error, msg
      ws.emit \err, msg
      ws.disconnect!
      return
    return @.on-tty-request cmd if cmd.type is \req-tty
    return @.on-tty-control cmd if cmd.type is \ctrl-tty
    return WARN "#{prefix} unexpected command request: #{cmd.type.red} (#{text.gray})"

  on-tty-request: (cmd) ->
    {ws, prefix, user, agent-manager} = self = @
    {type, id, params} = cmd
    agent = agent-manager.find-agent id
    INFO "#{prefix}.#{user}: on-tty-request => #{JSON.stringify cmd}"
    return ws.emit \err, "no such #{id}" unless agent?
    return ws.emit \err, "#{id} is already paired with another terminal" unless agent.allow-tty!
    self.prefix = prefix = "#{prefix}:#{id.yellow}:#{user.magenta}"
    INFO "#{prefix} paired successfully"
    return agent.request-tty @, ws, params

  on-tty-control: (cmd) ->
    {ws, prefix, agent-manager} = @
    {type, id, params} = cmd
    agent = agent-manager.find-agent id
    INFO "#{prefix} on-tty-control: #{JSON.stringify cmd}"
    return ws.emit \err, "no such #{id}" unless agent?
    return ws.emit \err, "unexpected ctrl-tty before paired" unless agent.allow-ctrl!
    return agent.control-tty @, ws, params


class TerminalManager
  (@environment, @configs, @helpers, @app) ->
    @sockets = []
    @total = 0
    return

  init: (@agent-manager, done) ->
    return done!

  fini: (done) ->
    return done!

  add: (s, user) ->
    {total, sockets, agent-manager} = self = @
    self.total = total + 1
    xri = s.request.headers['x-real-ip']
    xff = s.request.headers['x-forwarded-for']
    ua = s.request.headers['user-agent']
    ua = \unknown unless ua?
    ip = s.handshake.address
    ip = xri if xri?
    ip = xff if xff?
    index = lodash.padStart self.total, 8, '0'
    prefix = "terms [#{index.gray}]"
    INFO "#{prefix}.#{user}: incoming connection (from #{ip.green}, agent => #{ua.magenta})"
    sw = new SocketWrapper s, prefix, user, index, @, agent-manager
    sockets.push sw

  remove: (sw) ->
    {sockets} = self = @
    {prefix, connected-at} = sw
    now = new Date!
    duration = Math.floor ((now - connected-at) / 1000)
    idx = lodash.findIndex sockets, sw
    sockets.splice idx, 1 unless idx is -1
    INFO "#{prefix} disconnected. session lifetime => #{duration}s, removed from pool[#{idx}]."


module.exports = exports =
  name: "ws-#{NAMESPACE}"

  attach: (name, environment, configs, helpers) ->
    app = @
    app[name] = tm = new TerminalManager environment, configs, helpers, app
    module.configs = configs
    return <[web auth agent-manager]>

  init: (p, done) ->
    {app} = p
    {web, auth} = app
    {configs} = module
    INFO "configs => #{JSON.stringify configs}"
    authenticator = auth.resolve-authenticator configs.authentication
    handler = (s, username) -> return p.add s, username
    web.use-ws NAMESPACE, handler, authenticator
    return p.init app['agent-manager'], done

  fini: (p, done) ->
    return p.fini done!
