#
# Copyright (c) 2019 T2T Inc. All rights reserved
# https://www.t2t.io
# https://tic-tac-toe.io
# Taipei, Taiwan
#
require! <[path url]>
require! <[lodash express passport]>
{BasicStrategy} = require \passport-http
{DBG, ERR, WARN, INFO} = global.ys.services.get_module_logger __filename

const DEFAULT_SETTINGS =
  enabled: no


module.exports = exports =
  name: \webapi-agent

  attach: (name, environment, configs, helpers) ->
    INFO "configs => #{JSON.stringify configs}"
    module.configs = lodash.merge {}, DEFAULT_SETTINGS, configs
    return <[web auth agent-manager http-by-server bash-by-server]>

  init: (p, done) ->
    {configs} = module
    {web, auth} = app = @
    {REST_ERR, REST_DAT, UPLOAD} = web.get_rest_helpers!

    agent-manager = app['agent-manager']
    http-by-server = app['http-by-server']
    bash-by-server = app['bash-by-server']
    {socket_metadata_map, socket_instance_map} = agent-manager

    REMOTE_HTTP_V1 = (req, res, id, uri, query=null, json=yes, configs={}) ->
      {method, body, user} = req
      query = req.query unless query?
      (err, results) <- http-by-server.perform user, id, method, uri, query, body, json, configs
      return REST_DAT req, res, results unless err?
      return REST_ERR req, res, \general_server_error, err unless Array.isArray err
      return REST_ERR req, res, err[0], err[1] if err.length < 3
      return REST_ERR req, res, err[0], err[1], err[2]

    REMOTE_BASH_V1 = (req, res, id, operation=\default, parameters={}, configs={}) ->
      {user, body} = req
      {callback} = body
      return REST_ERR req, res, \missing_field, "callback in HTTP BODY is not specified" unless callback?
      {protocol} = xs = url.parse callback
      return REST_ERR req, res, \missing_field, "callback in HTTP BODY is invalid http or https URL" unless protocol in <[http: https:]>
      {cwd} = parameters.options
      cwd = '/tmp' unless cwd? and \string is typeof cwd
      parameters.options['cwd'] = cwd
      [err, request_id] = bash-by-server.perform user, id, operation, parameters, configs, callback, (err, result) ->
        return ERR err, "bash-by-server/#{operation}/#{id}: failed to perform: #{JSON.stringify parameters}" if err?
        return INFO "bash-by-server/#{operation}/#{id}: result => #{JSON.stringify result}"
      return REST_ERR req, res, err[0], err[1] if err?
      return REST_DAT req, res, {request_id}

    f = auth.generate-pasport-http-auth configs.authentication
    return done "failed to generate passport strategy with #{configs.authentication}" unless f? and \function is typeof f
    strategy = new BasicStrategy f
    passport.use strategy
    session = no
    authenticate = passport.authenticate \basic, {session}

    a = express!
    a.get '/agents', (req, res) ->
      {query} = req
      {format} = query
      if format is \advanced
        agents = [ (m.to-json!) for id, m of socket_metadata_map when m.online ]
        return REST_DAT req, res, agents
      else
        agents = [ m.system for id, m of socket_metadata_map when m.online ]
        return REST_DAT req, res, agents

    a.all '/agents/:id/perform-request/http/v1', authenticate, (req, res) ->
      {query, params} = req
      {id} = params
      {url, json, _uuid} = query
      return REST_ERR req, res, \missing_field, "url in query-string is not specified" unless url?
      arr = Array.isArray url
      uri = url
      uri = url.shift! if arr
      delete query['url'] unless arr
      delete query['json']
      delete query['_uuid']
      json = if json? and json in <[no false]> then no else yes
      uuid = if _uuid? and _uuid in <[no false]> then no else yes
      return REMOTE_HTTP_V1 req, res, id, uri, query, json, {uuid}

    a.post '/agents/:id/perform-request/bash/v1', authenticate, (req, res) ->
      {query, params, body} = req
      {id} = params
      {env} = query
      {command, cwd} = body
      return REST_ERR req, res, \missing_field, "command in HTTP BODY is not specified" unless command?
      env = [] unless env?
      env = [env] unless Array.isArray env
      env = [(x.split ':') for x in env]
      env = {[x[0], x[1]] for x in env}
      shell = yes
      args = []
      options = {env, shell}
      return REMOTE_BASH_V1 req, res, id, \default, {command, args, options}, {}

    web.use-api \a, a, 1
    return done!

  fini: (p, done) ->
    return done!
