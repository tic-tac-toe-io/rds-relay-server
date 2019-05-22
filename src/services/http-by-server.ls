require! <[prettyjson semver lodash]>
{DBG, ERR, WARN, INFO} = global.ys.services.get_module_logger __filename
uuid_v4 = require \uuid/v4

PROTOCOL = require \../common/protocol
{AGENT_EVENT_HTTP_BY_SERVER} = PROTOCOL.events
{PROGRESS_EVENT_ACKED, HTTP_INTERRUPT_ERROR} = PROTOCOL.constants

const DEFAULT_TIMEOUT = 180s
const SERVICE_NAME = \http-service

const DEFAULT_CONFIGS =
  v1:
    timeout: DEFAULT_TIMEOUT

const DEFAULT_TASK_CONFIGS =
  uuid: yes

class HttpByServerV1Task
  (@manager, @agent, @user, @id, @uri, @parameters, @configs, @callback) ->
    {configs} = manager
    {timeout} = configs.v1
    {uuid} = @configs = lodash.merge {}, DEFAULT_TASK_CONFIGS, configs
    @start-time = (new Date!) - 0
    u = uuid_v4! .to-upper-case!
    u = u.split '-'
    u = u.pop!
    @request-id = if uuid then "#{id}_#{u}_T#{@start-time}" else "#{id}_T#{@start-time}"
    @configs = configs.v1
    @timeout = timeout
    @running = no
    @prefix = "#{agent.prefix} #{@request-id.gray}"
    return

  start: ->
    {agent, request-id, uri, parameters, prefix} = self = @
    {method} = parameters
    request-version = \v1
    self.running = yes
    agent.emit AGENT_EVENT_HTTP_BY_SERVER, request-version, request-id, uri, parameters
    return INFO "#{prefix}: #{method} #{uri} <= #{JSON.stringify parameters}"

  consolidate-report: (end) ->
    {user, uri, parameters, agent, start-time, acked-time, manager, prefix, configs} = self = @
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
    request = {id, uri, method, query, body, json, configs}
    INFO "HttpByServerV1: #{username}, #{id}, #{method}, #{uri}, #{ack}, #{complete}, #{end}"
    ack = "#{ack}ms"
    complete = "#{complete}ms"
    INFO "#{prefix}: #{end}, #{ack.yellow}, #{complete.green}, #{method}, #{uri}, #{username}"
    manager.remove-task id
    return {agent, request, performance}

  response-result: (result) ->
    {callback} = self = @
    data = self.consolidate-report \result
    data['result'] = result
    return callback null, data

  response-error: (error) ->
    {callback} = self = @
    data = self.consolidate-report \error
    data['error'] = error
    {message} = error
    delete error['message']
    return callback [\remote_agent_error, message, data]

  response-timeout: ->
    {callback, configs} = self = @
    {constants} = PROTOCOL
    data = self.consolidate-report \timeout
    name = \HTTP_BY_AGENT_ERR_SERVER_TIMEOUT
    code = constants[name]
    code = -1 unless code?
    message = "http request takes more than #{configs.timeout}s"
    data['error'] = {name, code, message}
    return callback [\remote_agent_error, message, data]

  process: (progress, result, error) ->
    {agent, request-id, prefix} = self = @
    # INFO "#{prefix}: progress: #{JSON.stringify progress}"
    # INFO "#{prefix}: result: #{JSON.stringify result}"
    # INFO "#{prefix}: error: #{JSON.stringify error}"
    return @.response-result result if result?
    return @.response-error error if error?
    return WARN "#{prefix}: process all null variables" unless progress?
    {evt, percentage} = progress
    self.acked-time = (new Date!) - 0 if evt is PROGRESS_EVENT_ACKED
    return INFO "#{prefix}: progress => #{progress.evt}/#{progress.percentage}"

  at-check: ->
    {timeout, running, agent, request-id, configs} = self = @
    return unless running
    return WARN "#{prefix} timeout value is unexpected: #{timeout}" unless timeout > 0
    self.timeout = timeout - 1
    return self.response-timeout! unless self.timeout > 0

  at-agent-restart: (new_instance_id) ->
    {agent} = self = @
    {instance_id} = agent.cc
    error =
      code: HTTP_INTERRUPT_ERROR
      name: \HTTP_INTERRUPT_ERROR
      err:
        instance_id: instance_id
        new_instance_id: new_instance_id
        cause: \AGENT_RESTART
      message: "agent is restarted, instanc id was changed from #{instance_id} to #{new_instance_id}."
    return @.response-error error


class ServiceManager
  (@environment, configs, @helpers, @app) ->
    @agents = {}
    @tasks = {}
    @configs = lodash.merge {}, DEFAULT_CONFIGS, configs
    INFO "configs => #{JSON.stringify @configs}"
    return

  init: (@am, done) ->
    {app} = self = @
    app.on \agent-disconnected, (id) -> return self.at-agent-disconnected id
    app.on \agent-connected, (id, sw, sm) -> return self.at-agent-connected id, sw, sm
    f = -> return self.at-timeout!
    self.timer = setInterval f, 1000ms
    return done!

  fini: (done) ->
    return done!

  perform: (user, id, method, uri, query, body, json, configs, done) ->
    {agents, tasks} = self = @
    a = agents[id]
    return done [\resource_unavailable, "#{id} does not exist"] unless a?
    {protocol_version} = a.cc
    return done [\resource_not_implemented, "#{id}(v#{protocol_version} <= 0.2.0) does not support http api"] if semver.lt protocol_version, \0.2.0
    {request-id} = t = new HttpByServerV1Task self, a, user, id, uri, {method, query, body, json}, configs, done
    tasks[request-id] = t
    t.start!

  at-agent-connected: (id, sw, sm) ->
    {agents, tasks} = self = @
    agents[id] = a = sw
    {instance_id} = a.cc
    sw.on AGENT_EVENT_HTTP_BY_SERVER, SERVICE_NAME, (id, p, res, err) -> return self.at-agent-data sw, id, p, res, err
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
    return t.process progress, result, error

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
    module.sm = @agent-http-service = new ServiceManager configs, @

  init: (done) ->
    {agent-manager} = app = @
    {sm} = module
    am = agent-manager
    return done new Error "service-http depends on plugin #{'agent-manager'.yellow} but missing" unless am?
    return sm.init am, done



module.exports = exports =
  name: \http-by-server

  attach: (name, environment, configs, helpers) ->
    app = @
    app[name] = new ServiceManager environment, configs, helpers, app
    return <[web agent-manager]>

  init: (p, done) ->
    app = @
    am = app['agent-manager']
    return p.init am, done

  fini: (p, done) ->
    return p.fini done!
