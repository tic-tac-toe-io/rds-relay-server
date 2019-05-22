#
# Copyright (c) 2019 T2T Inc. All rights reserved
# https://www.t2t.io
# https://tic-tac-toe.io
# Taipei, Taiwan
#
require! <[path lodash express]>
{DBG, ERR, WARN, INFO} = global.ys.services.get_module_logger __filename

const DEFAULT_SETTINGS =
  enabled: no


module.exports = exports =
  name: \webapi-agent

  attach: (name, environment, configs, helpers) ->
    INFO "configs => #{JSON.stringify configs}"
    module.configs = lodash.merge {}, DEFAULT_SETTINGS, configs
    return <[web agent-manager]>

  init: (p, done) ->
    {configs} = module
    {enabled} = configs
    if not enabled
      WARN "disabled!!"
      return done!
    {web} = context = @
    {REST_ERR, REST_DAT, UPLOAD} = web.get_rest_helpers!

    agent-manager = context['agent-manager']
    {socket_metadata_map, socket_instance_map} = agent-manager

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

    web.use-api \a, a, 1
    return done!

  fini: (p, done) ->
    return done!
