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
    return <[web auth agent-manager http-by-server bash-by-server file-mgr]>

  init: (p, done) ->
    {configs} = module
    {web, auth} = app = @
    {REST_ERR, REST_DAT, UPLOAD} = web.get_rest_helpers!

    agent-manager = app['agent-manager']
    http-by-server = app['http-by-server']
    bash-by-server = app['bash-by-server']
    file-mgr = app['file-mgr']
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

    a.get '/agents/:id/filemgr/readdir', authenticate, (req, res) ->
      {query, params, user} = req
      {field} = query
      {id} = params
      uuid = yes
      operation = \readdir
      configs = {uuid}
      parameters = {operation, field}
      return REST_ERR req, res, \missing_field, "path in query-string is not specified" unless query.path?
      parameters['path'] = query.path
      field = \compact unless field?
      return REST_ERR req, res, \missing_field, "field (#{field}) in query-string is unsupported" unless field in <[full compact]>
      [err] = file-mgr.perform user, id, parameters, configs, null, (err, results) ->
        return REST_ERR req, res, err[0], err[1] if err?
        return REST_DAT req, res, results
      return REST_ERR req, res, err[0], err[1] if err?

    a.get '/agents/:id/filemgr/readFile', authenticate, (req, res) ->
      {query, params, user} = req
      {format} = query
      {id} = params
      uuid = yes
      operation = \readFile
      format = \raw unless format?
      configs = {uuid}
      parameters = {operation}
      INFO "#{req.path}: query => #{JSON.stringify query}"
      INFO "#{req.path}: params => #{JSON.stringify params}"
      return REST_ERR req, res, \missing_field, "path in query-string is not specified" unless query.path?
      parameters['path'] = query.path
      return REST_ERR req, res, \missing_field, "format (#{format}) in query-string is unsupported" unless format in <[raw text lines json]>
      parameters['format'] = format
      [err] = file-mgr.perform user, id, parameters, configs, null, (err, results) ->
        return REST_ERR req, res, err[0], err[1] if err?
        return REST_DAT req, res, results
      return REST_ERR req, res, err[0], err[1] if err?

    a.post '/agents/:id/filemgr/downloadFile', authenticate, (req, res) ->
      {query, params, user, body} = req
      {retry, timeout, sha256} = query
      {callback, uri, username, password, ua, dir} = body
      {id} = params
      uuid = yes
      operation = \downloadFile
      configs = {uuid}
      parameters = {operation}
      return REST_ERR req, res, \missing_field, "uri in HTTP BODY is not specified" unless uri?
      return REST_ERR req, res, \missing_field, "uri in HTTP BODY is a string" unless \string is typeof uri
      return REST_ERR req, res, \missing_field, "dir in HTTP BODY is not specified" unless dir?
      return REST_ERR req, res, \missing_field, "dir in HTTP BODY is a string" unless \string is typeof dir
      return REST_ERR req, res, \missing_field, "callback in HTTP BODY is not specified" unless callback?
      return REST_ERR req, res, \missing_field, "callback in HTTP BODY is a string" unless \string is typeof callback
      {protocol} = xs = url.parse callback
      return REST_ERR req, res, \missing_field, "callback in HTTP BODY is invalid http or https URL" unless protocol in <[http: https:]>
      {protocol} = xs = url.parse uri
      return REST_ERR req, res, \missing_field, "uri in HTTP BODY is invalid http or https URL" unless protocol in <[http: https:]>
      ua = false unless ua?
      ua = false unless \boolean is typeof ua
      retry = DEFAULT_DOWNLOAD_FILE_RETRIES unless retry?
      retry = parseInt retry if \string is typeof retry
      retry = DEFAULT_DOWNLOAD_FILE_RETRIES if retry === NaN
      timeout = DEFAULT_DOWNLOAD_TIMEOUT unless timeout?
      timeout = parseInt timeout if \string is typeof timeout
      timeout = DEFAULT_DOWNLOAD_TIMEOUT if timeout === NaN
      parameters <<< {uri, username, password, ua, dir}
      configs['retry'] = retry
      configs['sha256'] = sha256
      prefix = "file-mgr/#{operation}/#{id}"
      [err, request_id] = file-mgr.perform user, id, parameters, configs, callback, (err, result) ->
        if err?
          ERR "#{prefix}: failed to perform: #{JSON.stringify parameters} => #{err[0]} => #{err[1]} => #{JSON.stringify err[2]}" if err?
          data = err[2]
          code = 1
        else
          INFO "#{prefix}: result => #{JSON.stringify result}"
          data = result
          code = 0
        uri = callback
        method = \POST
        task = data.request.id
        id = data.agent
        profile = data.profile
        type = \file-mgr
        qs = {profile, id, type, operation, task}
        json = yes
        percentage = 100
        body = {percentage, code, data}
        opts = {uri, method, qs, json, body}
        INFO "#{prefix}: completed => #{JSON.stringify qs}, #{profile}"
        (err, rsp, body) <- request opts
        return ERR err, "#{prefix}: failed to notify completion to #{uri}" if err?
        return ERR "#{prefix}: failed to notify completion to #{uri} because of non-200 response: #{rsp.statusCode}(#{rsp.statusMessage.red})" unless rsp.statusCode is 200
        return INFO "#{prefix}: informed #{uri} with completion"
      return REST_ERR req, res, err[0], err[1] if err?
      return REST_DAT req, res, {request_id}

    a.get '/agents/:id/filemgr/env', authenticate, (req, res) ->
      {query, params, user} = req
      {field} = query
      {id} = params
      uuid = yes
      operation = \env
      configs = {uuid}
      parameters = {operation, field}
      [err] = file-mgr.perform user, id, parameters, configs, null, (err, results) ->
        return REST_ERR req, res, err[0], err[1] if err?
        return REST_DAT req, res, results
      return REST_ERR req, res, err[0], err[1] if err?


    toe = express!
    toe.use '/:id/sensor-web/v3', authenticate, (req, res, next) ->
      return REMOTE_HTTP_V1 req, res, req.params.id, "http://localhost:6020/api/v3#{req.path}"

    toe.use '/:id/sensor-web/v1', authenticate, (req, res, next) ->
      return REMOTE_HTTP_V1 req, res, req.params.id, "http://localhost:6020/api/v1#{req.path}"

    toe.use '/:id/toe-agent/v3', authenticate, (req, res, next) ->
      return REMOTE_HTTP_V1 req, res, req.params.id, "http://localhost:6040/api/v3#{req.path}"

    toe.post '/:id/yapps-scripts/v3/apply-image', authenticate, (req, res) ->
      {query, params, body} = req
      {id} = params
      {argv} = query
      argv = [] unless argv?
      argv = [argv] unless Array.isArray argv
      {image} = body
      return REST_ERR req, res, \missing_field, "image in HTTP BODY is not specified" unless image?
      env = {}
      shell = no
      args = ["apply_image", "{{PROFILE_MNT_DAT_DIR}}/images/#{image}.sqfs"] ++ argv
      command = "{{YAC_BIN_DIR}}/yac"
      options = {env, shell}
      return REMOTE_BASH_V1 req, res, id, \yac-apply-image, {command, args, options}, {}


    conf = express!
    conf.post '/', (req, res) ->
      {body, hostname, protocol} = req
      host = req.get \host
      INFO "#{req.originalUrl}: host => #{host}, req.ip => #{req.ip}"
      INFO "#{req.originalUrl}: #{protocol.cyan}://#{hostname.yellow}"
      INFO "#{req.originalUrl}: body => #{JSON.stringify body}"
      url = "#{protocol}://#{host}"
      return REST_DAT req, res, {url}


    tty = express!
    tty.get '/', (req, res) -> return res.render \dashboard

    web.use-api \a, a, 1
    web.use-api \toe, toe, 1
    web.use-api \config, conf, 1
    web.use \tty, tty
    return done!

  fini: (p, done) ->
    return done!
