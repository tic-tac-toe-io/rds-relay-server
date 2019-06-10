#
# Copyright (c) 2019 T2T Inc. All rights reserved
# https://www.t2t.io
# https://tic-tac-toe.io
# Taipei, Taiwan
#
require! <[os express lodash request]>
{DBG, ERR, WARN, INFO} = global.ys.services.get_module_logger __filename
{AGENT_EVENT_COMMAND, AGENT_EVENT_REGISTER, AGENT_EVENT_REGISTER_ACKED} = (require \../common/protocol).events

const DUPLICATE_AGENT_ERROR = "duplicate agent identity"

const UNKNOWN_VERSION = \unknown
const PROTOCOL_VERSION = \0.3.0
const PROTOCOL_VERSION_LEGACY = \0.1.0

const AGENT_STATE_DISCONNECTED = 0
const AGENT_STATE_CONNECTED = 1
const AGENT_STATE_SUPERVISING = 2

const TIC_GEOIP_SERVER = "https://tic-geoip.t2t.io"

const AGENT_CONNECTION_INFO_DEFAULT =
  protocol_version: PROTOCOL_VERSION_LEGACY
  software_version: UNKNOWN_VERSION
  socketio_version: UNKNOWN_VERSION

SUM = (a, b) -> return a + b


class SocketWrapper
  (@ws, @index, @manager) ->
    self = @
    self.tty-context = paired: no, peer: null, disconnecting: no
    self.connected-at = new Date!
    self.err-duplicated-agent = no
    self.register-data = {}
    self.callbacks = {}
    self.prefix = "agents[xxxx]:xxxx"
    ws.on \disconnect, (reason) -> return self.at-disconnct reason
    ws.on AGENT_EVENT_REGISTER, (buf) -> return self.at-register buf

  on: (evt, source, callback) ->
    {prefix, callbacks, ws} = self = @
    event = evt
    x = {event, source, callback}
    c = callbacks[evt]
    return WARN "#{prefix} #{source.green} wants #{evt.magenta} event but already registered by #{c.source.green}" if c?
    callbacks[evt] = x
    ws.on evt, callback
    return INFO "#{prefix} listens #{source.green}/#{evt.magenta} event"

  emit: ->
    {ws} = self = @
    return ws.emit.apply ws, arguments

  at-disconnct: (reason) ->
    {manager, ws, prefix, callbacks} = self = @
    for evt, x of callbacks
      {callback, source} = x
      ws.removeListener evt, callback
      INFO "#{prefix} <at-disconnect> cleans #{source.green}/#{evt.magenta} event"
    ws.removeAllListeners \disconnect
    ws.removeAllListeners AGENT_EVENT_REGISTER
    return manager.remove-sw self, reason

  at-register: (buf) ->
    {manager, index, ws} = self = @
    text = "#{buf}"
    data = null
    try
      data = JSON.parse text
    catch error
      ERR error, "failed to parse buf: #{text.gray}"
      return self.err-disconnect "failed to parse registration data buffer"
    {system, id} = self.register-data = data
    {interfaces} = system
    if system.iface? and system.iface.iface?
      {ipv4, ipv4_address, mac, address} = system.iface.iface
      ipv4 = ipv4_address unless ipv4?
      mac = address unless mac?
    ipv4 = "unknown" unless ipv4?
    mac = "00:00:00:00:00:00" unless mac?
    if interfaces? and Array.isArray interfaces and ipv4 is \unknown
      xs = [ x for x in interfaces when x.ipv4_address? and x['interface'] isnt \lo ]
      if xs.length > 0
        ipv4 = xs[0].ipv4_address
        mac = xs[0].address
        ipv4 = "unknown.x" unless ipv4?
        mac = "FF:FF:FF:FF:FF:FF" unless mac?
        INFO "agents[#{index}] interface #{xs[0]['interface']} is selected (ipv4: #{ipv4}, mac: #{mac})"
    self.cc = cc = lodash.merge {}, AGENT_CONNECTION_INFO_DEFAULT, data.cc, {ipv4, mac}
    self.id = id
    # [success, metadata, sw] = manager.register-agent self, data, cc
    (success, metadata, sw) <- manager.register-agent self, data, cc
    {cc} = module
    return ws.emit \register-acked, {cc} if success
    old_ws = sw.ws
    new_ws = self.ws
    xs = JSON.stringify sw.register-data
    ys = JSON.stringify self.register-data
    INFO "agents[#{index}] #{DUPLICATE_AGENT_ERROR} with #{sw.index} (#{metadata.prefix})"
    INFO "agents[#{index}] #{DUPLICATE_AGENT_ERROR} => #{sw.index}.data: #{xs}"
    INFO "agents[#{index}] #{DUPLICATE_AGENT_ERROR} => #{index}.data: #{ys}"
    INFO "agents[#{index}] #{DUPLICATE_AGENT_ERROR} => register-data-comparison: #{xs is ys}"
    INFO "agents[#{index}] #{DUPLICATE_AGENT_ERROR} => new: #{new_ws.id}/#{new_ws.conn.remoteAddress} => #{JSON.stringify new_ws.request.headers}"
    INFO "agents[#{index}] #{DUPLICATE_AGENT_ERROR} => old: #{old_ws.id}/#{old_ws.conn.remoteAddress} => #{JSON.stringify old_ws.request.headers}"
    INFO "agents[#{index}] #{DUPLICATE_AGENT_ERROR} => #{index} to be disconnected"
    self.prefix = "agents[#{index.gray}]:duplicated(#{id})"
    self.err-duplicated-agent = yes
    self.err-disconnect DUPLICATE_AGENT_ERROR, yes
    /**
     * [TODO] Please consider to enable following codes, to force both 2 connected agents with
     *        totally same registration data, which can confirm the 2 agent websocket connections
     *        come from same machine.
     *
     *        For such situation, we shall force to disconnect both websocket connections, and then
     *        wstty-agent shall restart in 10 minutes, and come back.
     *
     *        Please note,
     *          - wstty-agent before 0.2.5 shall restart itself within 10 minutes after receiving `disconnect` event, because `restart` event is ignored by agent.
     *          - wstty-agent after 0.2.5 shall restart itself within 3 seconds after receiving `restart` event
     *
     * `index`, is the auto-incremental number for each websocket agent connection, starting from 00000001
     * `id`   , is the unique identity of each agent, e.g. F00040022, C99900013, 1626I0000014...
     *
    return unless xs is ys
    INFO "agents[#{index}] #{DUPLICATE_AGENT_ERROR} => #{sw.index} to be disconnected because of same machine (metadata to be reset)"
    sw.err-duplicated-agent = no
    sw.err-disconnect DUPLICATE_AGENT_ERROR, yes
    */


  err-disconnect: (msg, restart=no) ->
    {ws} = @
    ws.emit \err, msg
    ws.emit \restart_agent, {msg: msg, timer: 1500ms} if restart
    ws.disconnect yes

  allow-tty: ->
    {paired, peer} = @tty-context
    return not (paired or peer?)

  allow-ctrl: ->
    {paired, peer} = @tty-context
    return paired and peer?

  control-tty: (terminal, peer, params) ->
    {ws} = self = @
    return ws.emit AGENT_EVENT_COMMAND, JSON.stringify {type: \ctrl-tty, params: params}

  request-tty: (terminal, peer, params) ->
    {ws, id, prefix, tty-context, metadata} = self = @
    {user} = peer
    INFO "#{prefix} <= req-tty, params: #{JSON.stringify params}, user: #{user}"
    me = ws
    me.emit AGENT_EVENT_COMMAND, JSON.stringify {type: \req-tty, params: params}

    me-on-err = (msg) ->
      WARN "#{prefix} error from agent: #{msg}"
      peer.emit \err, msg
      peer.disconnect!
      tty-context.disconnecting = yes
      return me.emit AGENT_EVENT_COMMAND, JSON.stringify {type: \destroy-tty}

    me-on-pair = ->
      INFO "#{prefix} paired (#{user})"
      tty-context.paired = yes
      tty-context.peer = peer
      metadata.state-updater.set AGENT_STATE_SUPERVISING
      return peer.emit \paired, "paired"

    me-on-tty-data = (chunk) ->
      peer.emit \tty, chunk unless tty-context.disconnecting
      size = chunk.length
      DBG "#{prefix} => #{size} bytes"
      metadata.log-data-transmission user, \from, size

    me-on-depair = (chunk) ->
      INFO "#{prefix} depair (#{user})"
      metadata.state-updater.set AGENT_STATE_CONNECTED
      tty-context.paired = no
      tty-context.peer = null
      tty-context.disconnecting = no
      try
        data = JSON.parse "#{chunk}"
        {code, signal} = data
        peer.emit \exit, code, signal
      catch error
        WARN "#{prefix} try to parse at depair but failed: #{chunk}, #{error}"
      peer.disconnect!
      me.removeListener \err, me-on-err
      me.removeListener \pair, me-on-pair
      me.removeListener \tty, me-on-tty-data
      me.removeListener \depair, me-on-depair

    me-on-disconnect = ->
      INFO "#{prefix} unexpected __disconnect__ event before __pair__ event"
      me.removeListener \err, me-on-err
      me.removeListener \pair, me-on-pair
      me.removeListener \tty, me-on-tty-data
      me.removeListener \depair, me-on-depair
      me.removeListener \disconnect, me-on-disconnect
      if tty-context.peer?
        INFO "#{prefix} inform web-terminal (tty-context.peer) to exit"
        tty-context.paired = no
        tty-context.peer = null
        tty-context.disconnecting = no
        peer.emit \exit, 257, "unexpected disconnection"
        peer.disconnect!
      else
        INFO "#{prefix} inform web-terminal (peer) to exit"
        peer.emit \exit, 256, "unexpected disconnection"
        peer.disconnect!

    me.on \err, me-on-err
    me.on \pair, me-on-pair
    me.on \depair, me-on-depair
    me.on \tty, me-on-tty-data
    me.on \disconnect, me-on-disconnect

    peer.on \tty, (chunk) ->
      me.emit \tty, chunk unless tty-context.disconnecting
      size = chunk.length
      DBG "#{prefix} <= #{size} bytes"
      metadata.log-data-transmission user, \to, size

    peer.on \disconnect, ->
      INFO "#{prefix} web-terminal is disconnected (#{user})"
      me.emit AGENT_EVENT_COMMAND, JSON.stringify {type: \destroy-tty}


class SocketMetadata
  (@id, @system, @cc, @manager) ->
    @counter = 0
    @online = no
    return

  initiate-state-updater: ->
    {iwc} = module
    {state-updater, profile, id, prefix} = self = @
    if state-updater?
      if state-updater.db is profile
        INFO "#{prefix} set existed state-updater: #{profile}/#{id}/tic/wstty/agent/state to AGENT_STATE_CONNECTED(#{AGENT_STATE_CONNECTED})"
        state-updater.set AGENT_STATE_CONNECTED
        return
      else
        INFO "#{prefix} stop the existed state-updater: #{state-updater.db}/#{id}/tic/wstty/agent/state"
        state-updater.stop!
    INFO "#{prefix} initiate new state-updater: #{profile}/#{id}/tic/wstty/agent/state with AGENT_STATE_CONNECTED(#{AGENT_STATE_CONNECTED})"
    self.state-updater = iwc.create-updater \StateValue, profile, id, \tic, \wstty, \agent, \state, AGENT_STATE_CONNECTED, 60s
    return

  initiate-duplication-updater: ->
    {iwc} = module
    {duplication-updater, profile, id, prefix} = self = @
    if duplication-updater?
      if duplication-updater.db is profile
        INFO "#{prefix} set existed duplication-updater: #{profile}/#{id}/tic/wstty/agent/duplication to 0"
        return
      else
        INFO "#{prefix} stop the existed duplication-updater: #{duplication-updater.db}/#{id}/tic/wstty/agent/duplication"
        duplication-updater.stop!
    INFO "#{prefix} initiate new duplication-updater: #{profile}/#{id}/tic/wstty/agent/duplication with 0"
    self.duplication-updater = iwc.create-updater \StateValue, profile, id, \tic, \wstty, \agent, \duplication, 0, 60s
    return

  at-connected: (@system, @cc, @geoip) ->
    {iwc} = module
    {id, counter, state-updater} = self = @
    self.counter = counter + 1
    p1 = lodash.padStart id, 12, ' '
    p2 = lodash.padStart self.counter, 4, '0'
    self.prefix = "#{p1.yellow}.#{p2.cyan}"
    # self.prefix = "#{(ADD_PADDINGS id, 12, yes, yes).yellow}.#{(ADD_PADDINGS self.counter, 4, no, yes).cyan}"
    self.online = yes
    self.last-connected = new Date!
    {profile} = system.ttt
    self.profile = profile
    self.uptime-updater = iwc.create-updater \UptimeValue, profile, id, \tic, \wstty, \agent, \uptime
    self.initiate-state-updater!
    self.initiate-duplication-updater!
    return self

  at-disconnected: ->
    {prefix, profile, id} = self = @
    self.last-disconnected = new Date!
    self.online = no
    INFO "#{prefix} set existed state-updater: #{profile}/#{id}/tic/wstty/agent/state to AGENT_STATE_DISCONNECTED(#{AGENT_STATE_DISCONNECTED})"
    self.state-updater.set AGENT_STATE_DISCONNECTED
    self.uptime-updater.stop!
    return self

  log-data-transmission: (user, direction, bytes) ->
    {iwc} = module
    {id, profile} = self = @
    iwc.write-data profile, id, \tic, \wstty, "user.#{user}", direction, bytes

  to-json: ->
    {system, id, cc, geoip, last-connected} = self = @
    uptime = (new Date!) - last-connected
    return {id, system, cc, uptime, geoip}



class AgentManager
  (@environment, @configs, @helpers, @app) ->
    @sockets = []
    @socket_metadata_map = {}
    @socket_instance_map = {}
    @total = 0
    return

  init: (done) ->
    {environment, configs, helpers, app} = self = @
    {PRETTIZE_KVS} = helpers
    {app_package_json} = environment
    {web} = app
    instance_id = environment.service_instance_id
    protocol_version = PROTOCOL_VERSION
    software_version = app_package_json.version
    socketio_version = (require "socket.io/package.json").version
    module.cc = self.cc = cc = {protocol_version, software_version, socketio_version, instance_id} # connection-context
    INFO "environment => #{PRETTIZE_KVS environment}"
    INFO "running with Protocol #{protocol_version.yellow} on #{instance_id.cyan} with socket.io #{socketio_version.red}"
    INFO "cc => #{JSON.stringify cc}"
    return done!

  update-stats: ->
    {configs, socket_metadata_map} = self = @
    {name} = configs
    {iwc} = module
    xs = [ k for k, v of socket_metadata_map ]
    ys = [ (if socket_metadata_map[x].online then 1 else 0) for x in xs ]
    total = xs.length
    onlines = ys.reduce SUM, 0
    offlines = total - onlines
    now = (new Date!) - 0
    INFO "agents: onlines(#{onlines}) + offlines(#{offlines}) => #{total}"
    return iwc.submit-service-stats \agents, {value: total, onlines: onlines, offlines: offlines}

  add-ws: (s) ->
    {total, sockets, helpers} = self = @
    {PRETTIZE_KVS} = helpers
    self.total = total + 1
    index = lodash.padStart self.total, 8, '0'
    INFO "agents[#{index}] incoming connection ... (#{PRETTIZE_KVS s.request.headers})"
    sw = new SocketWrapper s, index, self
    sockets.push sw

  find-agent: (id) ->
    return @socket_instance_map[id]

  register-agent: (sw, reg-data, cc, done) ->
    {socket_metadata_map, socket_instance_map, app, sockets, helpers} = self = @
    {PRETTIZE_KVS} = helpers
    {id, system} = reg-data
    sm = socket_metadata_map[id]
    swo = socket_instance_map[id]
    return done no, sm, swo if swo?
    sm = new SocketMetadata id, system, cc, self unless sm?
    xri = sw.ws.request.headers['x-real-ip']
    xff = sw.ws.request.headers['x-forwarded-for']
    ip = sw.ws.handshake.address
    ip = xri if xri?
    ip = xff if xff?
    site = sw.ws.request.headers['host']
    host = os.hostname!
    instance = cc.instance_id
    service = \rds-relay-server
    qs = {site, host, instance, service}
    method = \GET
    uri = "#{TIC_GEOIP_SERVER}/by-ip/#{ip}"
    opts = {method, uri, qs}
    INFO "requesting geolocation information for #{ip} with #{PRETTIZE_KVS qs}"
    geoip = {ip}
    (err, rsp, body) <- request opts
    if not err? and rsp.statusCode is 200
      json = JSON.parse body
      {data} = json
      geoip = {ip, data}
      INFO "agents[#{sw.index.gray}] geoip => #{PRETTIZE_KVS geoip}"
    sm.at-connected system, cc, geoip
    socket_metadata_map[id] = sm
    socket_instance_map[id] = sw
    sw.prefix = prefix = "agents[#{sw.index.gray}]:#{sm.prefix}"
    sw.metadata = sm
    {profile, profile_version, ethernet_ip_addr} = system.ttt
    {ipv4, mac} = cc
    INFO "#{prefix} registered/geoip => #{ip.yellow}"
    INFO "#{prefix} registered/meta => #{profile.green}/#{profile_version.magenta}/#{ipv4.red}/#{mac.gray}"
    INFO "#{prefix} registered/conn => #{(JSON.stringify cc).gray}"
    INFO "#{prefix} registered/system.iface => #{(JSON.stringify system.iface).gray}" if system.iface?
    app.emit \agent-connected, id, sw, sm
    self.update-stats!
    return done yes, sm, sw

  remove-sw: (sw, reason) ->
    {socket_metadata_map, socket_instance_map, app, sockets} = self = @
    {id, prefix, index, connected-at, err-duplicated-agent} = sw
    now = new Date!
    duration = now - connected-at
    duration = if duration > 10000ms then "#{Math.floor (duration/1000)}s" else "#{duration}ms"
    INFO "#{prefix} remove-sw => total lifetime: #{duration}, reason: #{reason}"
    sm = socket_metadata_map[id]
    if err-duplicated-agent
      if sm?
        {duplication-updater} = sm
        duplication-updater.set (1 + duplication-updater.value)
        INFO "#{prefix} remove-sw => duplicated-agent, no changes but counter: #{duplication-updater.value}"
      else
        ERR "#{prefix} remove-sw => fatal error, duplicate agent, but failed to find related socket-metadata"
    else
      socket_instance_map[id] = null
      if sm?
        INFO "#{prefix} remove-sw => metadata.at-disconnected!"
        sm.at-disconnected!
        app.emit \agent-disconnected, id
      else
        WARN "agents[#{index}]/#{id}/#{prefix} missing socket-metadata instance because of registration failure or early-disconnection, with lifetime #{duration}ms"
    idx = lodash.findIndex sockets, sw
    sockets.splice idx, 1 unless idx is -1
    INFO "agents[#{index}]/#{id}/#{prefix} removed from sockets[#{idx}]..."
    self.update-stats!



##
# Dummy codes, to be removed soon.
#
class DummyUpdater
  ->
    return

  set : -> return
  stop : -> return
  start : -> return


##
# Dummy codes, to be removed soon.
#
class DummyIWC
  (@configs) ->
    return

  create-updater: -> return new DummyUpdater!
  write-data: -> return
  submit-service-stats: -> return




module.exports = exports =
  name: \agent-manager

  attach: (name, environment, configs, helpers) ->
    module.iwc = new DummyIWC {}
    app = @
    app[name] = am = new AgentManager environment, configs, helpers, app
    return <[web]>

  init: (p, done) ->
    return p.init done

  fini: (p, done) ->
    return p.fini done!
