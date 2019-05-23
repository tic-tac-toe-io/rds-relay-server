#
# Copyright (c) 2019 T2T Inc. All rights reserved
# https://www.t2t.io
# https://tic-tac-toe.io
# Taipei, Taiwan
#
require! <[lodash semver]>
{DBG, ERR, WARN, INFO} = global.ys.services.get_module_logger __filename
uuid_v4 = require \uuid/v4
PROTOCOL = require \../common/protocol
{AGENT_EVENT_BASH_BY_SERVER} = PROTOCOL.events
{PROGRESS_EVENT_ACKED, PROGRESS_EVENT_INDICATED, BASH_INTERRUPT_ERROR} = PROTOCOL.constants

const DEFAULT_TIMEOUT = 180s
const SERVICE_NAME = \bash-by-server

const DEFAULT_CONFIGS =
  v1:
    timeout: DEFAULT_TIMEOUT
    configs:
      uuid: yes
    parameters:
      command: null
      args: []
      options:
        cwd: '/tmp'
        env: {}
        shell: yes


class BashByServerV1Task
  (@manager, @agent, @user, @id, @timeout, @parameters, @configs, @callback, @done) ->
    @timeout = DEFAULT_TIMEOUT unless @timeout?
    @opts = {timeout}
    {operation} = configs
    @operation = operation
    @operation = \default unless @operation?
    @start-time = (new Date!) - 0
    u = uuid_v4! .to-upper-case!
    u = u.split '-'
    u = u.pop!
    @request-id = if configs.uuid then "#{id}_#{u}_T#{@start-time}" else "#{id}_T#{@start-time}"
    @running = no
    @prefix = "#{agent.prefix} #{@request-id.gray}"
    return

  start: ->
    {agent, request-id, parameters, configs, callback, prefix} = self = @
    request-version = \v1
    self.running = yes
    agent.emit AGENT_EVENT_BASH_BY_SERVER, request-version, request-id, parameters, configs, callback
    return INFO "#{prefix}: <= #{JSON.stringify parameters} <= #{callback}"

  consolidate-report: (end) ->
    {user, parameters, configs, callback, agent, start-time, acked-time, manager, prefix} = self = @
    {method, query, body, json} = parameters
    {username} = user
    self.running = no
    id = @request-id
    agent = agent.id
    started = start-time
    acked = acked-time
    completed = new Date! - 0
    timestamps = {started, acked, completed}
    ack = acked - started
    complete = completed - started
    durations = {ack, complete}
    performance = {timestamps, durations}
    request = {id, parameters, configs, callback}
    INFO "BashByServerV1: #{username}, #{id}, #{ack}, #{complete}, #{end}"
    ack = "#{ack}ms"
    complete = "#{complete}ms"
    INFO "#{prefix}: #{end}, #{ack.yellow}, #{complete.green}, #{method}, #{username}"
    manager.remove-task id
    return {agent, request, performance}

  response-result: (result) ->
    {done} = self = @
    data = self.consolidate-report \result
    data['result'] = result
    return done null, data

  response-error: (error) ->
    {done} = self = @
    data = self.consolidate-report \error
    data['error'] = error
    {message} = error
    delete error['message']
    return done [\remote_agent_error, message, data]

  response-timeout: ->
    {done, opts} = self = @
    {constants} = PROTOCOL
    data = self.consolidate-report \timeout
    name = \BASH_BY_SERVER_ERR_AGENT_TIMEOUT
    code = constants[name]
    code = -1 unless code?
    message = "bash request takes more than #{opts.timeout}s"
    data['error'] = {name, code, message}
    return done [\remote_agent_error, message, data]

  at-progress-acked: (percentage, args, agent) ->
    @acked-time = (new Date!) - 0

  at-progress-indicated: (percentage, args, agent) ->
    {prefix, id, request-id, operation, callback} = self = @
    {profile} = agent.metadata
    uri = callback
    method = \POST
    task = request-id
    id = agent.metadata.id
    type = SERVICE_NAME
    qs = {profile, id, type, operation, task}
    json = yes
    body = {percentage, args}
    opts = {uri, method, qs, json, body}
    INFO "#{prefix}: at-progress-indicated => #{JSON.stringify qs}, #{profile}"
    (err, rsp, body) <- request opts
    return ERR err, "#{prefix}: failed to notify progress indication to #{uri}" if err?
    return ERR "#{prefix}: failed to notify progress indication to #{uri} because of non-200 response: #{rsp.statusCode}(#{rsp.statusMessage.red})" unless rsp.statusCode is 200
    return INFO "#{prefix}: informed #{uri} with percentage(#{percentage}) and args => #{(JSON.stringify args).gray}"

  process: (progress, result, error, agent) ->
    {agent, request-id, prefix} = self = @
    DBG "#{prefix}: -- progress: #{JSON.stringify progress}"
    DBG "#{prefix}: -- result: #{JSON.stringify result}"
    DBG "#{prefix}: -- error: #{JSON.stringify error}"
    return @.response-result result if result?
    return @.response-error error if error?
    return WARN "#{prefix}: process all null variables" unless progress?
    {evt, percentage, args} = progress
    return self.at-progress-acked percentage, args, agent if evt is PROGRESS_EVENT_ACKED
    return self.at-progress-indicated percentage, args, agent if evt is PROGRESS_EVENT_INDICATED
    return WARN "#{prefix}: unknown progress event => #{evt.red} => #{JSON.stringify progress}"

  at-check: ->
    {timeout, running, agent, request-id, prefix} = self = @
    return unless running
    return WARN "#{prefix} timeout value is unexpected: #{timeout}" unless timeout > 0
    self.timeout = timeout - 1
    return self.response-timeout! unless self.timeout > 0

  at-agent-restart: (new_instance_id) ->
    {agent} = self = @
    {instance_id} = agent.cc
    error =
      code: BASH_INTERRUPT_ERROR
      name: \BASH_INTERRUPT_ERROR
      err:
        instance_id: instance_id
        new_instance_id: new_instance_id
        cause: \AGENT_RESTART
      message: "agent is restarted, instance id was changed from #{instance_id} to #{new_instance_id}."
    return @.response-error error


class ServiceManager
  (@environment, configs, @helpers, @app) ->
    @agents = {}
    @tasks = {}
    @configs = lodash.merge {}, DEFAULT_CONFIGS, configs
    INFO "configs => #{JSON.stringify @configs}"
    return

  init: (@am, done) ->
    INFO "init"
    {app} = self = @
    app.on \agent-disconnected, (id) -> return self.at-agent-disconnected id
    app.on \agent-connected, (id, sw, sm) -> return self.at-agent-connected id, sw, sm
    f = -> return self.at-timeout!
    self.timer = setInterval f, 1000ms
    return done!

  fini: (done) ->
    return done!

  perform: (user, id, operation=\default, parameters={}, configs={}, hook=null, done=null) ->
    {agents, tasks, configs} = self = @
    {timeout} = configs.v1
    a = agents[id]
    return [[\resource_unavailable, "#{id} does not exist"]] unless a?
    {protocol_version} = a.cc
    return [[\resource_not_implemented, "#{id}(v#{protocol_version} <= 0.3.0) does not support bash api"]] if semver.lt protocol_version, \0.3.0
    configs = lodash.merge {}, configs.v1.configs, configs
    configs['operation'] = operation
    parameters = lodash.merge {}, configs.v1.parameters, parameters
    INFO "timeout: #{timeout}"
    {request-id} = t = new BashByServerV1Task self, a, user, id, timeout, parameters, configs, hook, done
    tasks[request-id] = t
    t.start!
    return [null, request-id]

  at-agent-connected: (id, sw, sm) ->
    {agents, tasks} = self = @
    agents[id] = a = sw
    {instance_id} = a.cc
    sw.on AGENT_EVENT_BASH_BY_SERVER, SERVICE_NAME, (id, p, res, err) -> return self.at-agent-data sw, id, p, res, err
    xs = [ t for rid, t of tasks when a.id is t.agent.id ]
    ys = [ x for x in xs when x.agent.cc.instance_id isnt instance_id ]
    INFO "#{sw.prefix} connected, #{xs.length} pending tasks exist... (#{ys.length} tasks to be dropped)"
    [ (y.at-agent-restart instance_id) for y in ys ]

  at-agent-disconnected: (id) ->
    {agents, tasks} = self = @
    delete agents[id]

  at-agent-data: (agent, request-id, progress, result, error) ->
    {tasks} = self = @
    t = tasks[request-id]
    return ERR "no such #{request-id} in tasks, from agent #{agent.prefix}" unless t?
    return t.process progress, result, error, agent

  at-timeout: ->
    {tasks} = self = @
    [(task.at-check!) for id, task of tasks]

  remove-task: (request-id) ->
    {tasks} = @
    t = tasks[request-id]
    return WARN "No such #{request-id} in tasks to be removed." unless t?
    delete tasks[request-id]


module.exports = exports =
  attach: (configs, helpers) ->
    module.helpers = helpers
    module.sm = @agent-bash-service = new ServiceManager configs, @

  init: (done) ->
    {agent-manager} = app = @
    {sm} = module
    am = agent-manager
    return done new Error "service-bash depends on plugin #{'agent-manager'.yellow} but missing" unless am?
    return sm.init am, done


module.exports = exports =
  name: SERVICE_NAME

  attach: (name, environment, configs, helpers) ->
    app = @
    app[name] = new ServiceManager environment, configs, helpers, app
    return <[agent-manager]>

  init: (p, done) ->
    app = @
    am = app['agent-manager']
    return p.init am, done

  fini: (p, done) ->
    return p.fini done!
