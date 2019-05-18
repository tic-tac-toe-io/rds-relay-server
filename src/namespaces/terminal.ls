#
# Copyright (c) 2019 T2T Inc. All rights reserved
# https://www.t2t.io
# https://tic-tac-toe.io
# Taipei, Taiwan
#
require! <[lodash]>
{DBG, ERR, WARN, INFO} = global.ys.services.get_module_logger __filename

class SocketWrapper
  (@ws, @user, @index, @manager, @agent-mgr) ->
    self = @
    self.prefix = "terms [#{index.gray}]"
    self.connected-at = new Date!
    ws.on \disconnect, -> return self.on-disconnct!
    ws.on \command, (buf) -> return self.on-command "#{buf}"

  on-disconnct: ->
    @manager.remove-sw @
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
    {ws, prefix, user, agent-mgr} = self = @
    {type, id, params} = cmd
    agent = agent-mgr.find-agent id
    INFO "#{prefix}: on-tty-request => #{JSON.stringify cmd}"
    return ws.emit \err, "no such #{id}" unless agent?
    return ws.emit \err, "#{id} is already paired with another terminal" unless agent.allow-tty!
    self.prefix = prefix = "#{prefix}:#{id.yellow}:#{user.magenta}"
    INFO "#{prefix} paired successfully"
    return agent.request-tty @, ws, params

  on-tty-control: (cmd) ->
    {ws, prefix, agent-mgr} = @
    {type, id, params} = cmd
    agent = agent-mgr.find-agent id
    INFO "#{prefix} on-tty-control: #{JSON.stringify cmd}"
    return ws.emit \err, "no such #{id}" unless agent?
    return ws.emit \err, "unexpected ctrl-tty before paired" unless agent.allow-ctrl!
    return agent.control-tty @, ws, params


class TerminalManager
  (@environment, @configs, @helpers, @app) ->
    @sockets = []
    @total = 0
    return

  init: (@agent-mgr, done) ->
    return done!

  fini: (done) ->
    return done!

  add-ws: (s, user) ->
    {total, sockets, agent-mgr} = self = @
    self.total = total + 1
    index = lodash.padStart self.total, 8, '0'
    INFO "terms [#{index}]: incoming connection ..."
    sw = new SocketWrapper s, user, index, @, agent-mgr
    sockets.push sw

  remove-sw: (sw) ->
    {sockets} = self = @
    {prefix, connected-at} = sw
    now = new Date!
    duration = Math.floor ((now - connected-at) / 1000)
    idx = lodash.findIndex sockets, sw
    sockets.splice idx, 1 unless idx is -1
    INFO "#{prefix} disconnected. session lifetime => #{duration}s, removed from pool[#{idx}]."


module.exports = exports =
  name: \terminal

  attach: (name, environment, configs, helpers) ->
    app = @
    app[name] = tm = new TerminalManager environment, configs, helpers, app
    module.configs = configs
    return <[web agent-mgr]>

  init: (p, done) ->
    {app} = p
    {web} = app
    {configs} = module
    INFO "configs => #{JSON.stringify configs}"
    handler = (s, username) -> return p.add-ws s, username
    web.use-ws \terminal, handler, configs.authentication
    return p.init app['agent-mgr'], done

  fini: (p, done) ->
    return p.fini done!
