require! <[moment lodash]>
{DBG, ERR, WARN, INFO} = global.ys.services.get_module_logger __filename


const NAMESPACE = \system


class SocketWrapper
  (@ws, @index, @manager) ->
    self = @
    self.prefix = "#{NAMESPACE}[#{(lodash.padStart index, 4, '0').gray}]"
    self.connected-at = moment!
    INFO "#{self.prefix} incoming connection ..."
    ws.on \disconnect, -> return self.on-disconnct!
    ws.on \command, (buf) -> return self.on-command "#{buf}"

  on-disconnct: ->
    {manager, prefix, connected-at} = self = @
    now = moment!
    INFO "#{prefix} disconnected. session lifetime => #{(now - connected-at)/1000}s"
    manager.remove-sw self
    return

  on-command: (text) ->
    {ws} = @
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
    return WARN "unexpected command request: #{cmd.type.red} (#{text.gray})"

  send-event: (evt, data) ->
    @ws.emit \data, {evt: evt, data: data}



class SystemManager
  (@environment, @configs, @helpers, @app) ->
    self = @
    self.sockets = []
    self.counter = 0
    app.on \agent-connected, -> return self.at-agent-connected.apply self, arguments
    app.on \agent-disconnected, -> return self.at-agent-disconnected.apply self, arguments
    return

  init: (@agent-manager, done) ->
    return done!

  add-ws: (s) ->
    {counter} = self = @
    agents = self.get-agents!
    self.counter = counter + 1
    sw = new SocketWrapper s, self.counter, self
    sw.send-event \all-agents, agents
    self.sockets.push sw

  remove-sw: (sw) ->
    {sockets} = self = @
    {prefix} = sw
    idx = lodash.findIndex sockets, sw
    sockets.splice idx, 1 unless idx is -1
    INFO "#{prefix} removed from sockets[#{idx}]..."

  get-agents: ->
    {agent-manager} = self = @
    {socket_metadata_map} = agent-manager
    agents = [ m.to-json! for id, m of socket_metadata_map when m.online ]
    return agents

  broadcast: (evt, data) ->
    {sockets} = self = @
    [ (s.send-event evt, data) for s in sockets ]

  at-agent-connected: (id, socket-wrapper, socket-metadata) ->
    return @.broadcast \agent-connected, socket-metadata.to-json!

  at-agent-disconnected: (id) ->
    return @.broadcast \agent-disconnected, {id: id}



module.exports = exports =
  name: "ws-#{NAMESPACE}"

  attach: (name, environment, configs, helpers) ->
    app = @
    app[name] = tm = new SystemManager environment, configs, helpers, app
    return <[web auth agent-manager]>

  init: (p, done) ->
    {app} = p
    {web, auth} = app
    authenticator = auth.resolve-authenticator p.configs.authentication
    handler = (s, username) -> return p.add-ws s, username
    web.use-ws NAMESPACE, handler, authenticator
    return p.init app['agent-manager'], done

  fini: (p, done) ->
    return p.fini done!


