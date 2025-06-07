#
# Copyright (c) 2018 T2T Inc. All rights reserved
# https://www.t2t.io
# https://tic-tac-toe.io
# Taipei, Taiwan
#

require! <[path]>
require! <[mkdirp bunyan bunyan-debug-stream bunyan-rotating-file-stream lodash debug]>
debug = debug \yapps-server:common:logger


const DEFAULT_PREFIXERS =
  \base : (base) ->
    {process_name, source_type, filename} = base
    source_type = lodash.padEnd source_type, 12
    filename = lodash.padEnd filename, 32
    if source_type is \yapps-server
      source_type = source_type.blue
      filename = filename.gray
    process_name = if \mst is process_name then process_name.red else process_name.cyan
    return "#{process_name}:#{source_type}:#{filename}"


class ModuleLogger
  (@filepath) ->
    {index, environment, logger} = module
    {process_name, app_dir} = environment
    dir = path.dirname path.dirname __dirname
    exdir = "#{app_dir}/externals/yapps-server"
    if filepath.startsWith exdir
      source_type = "yapps-server"
      filename = filepath.substring exdir.length
    else if filepath.startsWith app_dir
      source_type = "--app--"
      filename = filepath.substring app_dir.length
      # filename = filename.substring 1 if filename.startsWith "/"
    else if filepath.startsWith dir
      source_type = "yapps-server"
      filename = filepath.substring dir.length
      # filename = filename.substring 1 if filename.startsWith "/"
    else
      source_type = "NONE"
      filename = filepath
    @log = logger.child base: {process_name, source_type, filename}

  error: -> return @log.error.apply @log, arguments
  warn : -> return @log.warn.apply  @log, arguments
  info : -> return @log.info.apply  @log, arguments
  debug: -> return @log.debug.apply @log, arguments


GET_LOGGER = (filepath=null) ->
  return {logger: module.logger} unless filepath?
  logger = new ModuleLogger filepath
  produce_func = (logger, level) -> return -> logger[level].apply logger, arguments
  return do
    logger: logger.stream
    DBG : produce_func logger, \debug
    ERR : produce_func logger, \error
    WARN: produce_func logger, \warn
    INFO: produce_func logger, \info


module.exports = exports =
  init: (index, environment, configs, prefixers, stringifiers, done) ->
    {app_name, process_name, app_dir, work_dir, logs_dir, startup_time, verbose} = environment
    debug "index: %o", index
    debug "environment: %o", environment
    debug "configs: %o", configs
    debug "process_name: %o", process_name
    prefixers = lodash.merge {}, DEFAULT_PREFIXERS, prefixers
    stringifiers = lodash.merge {}, stringifiers
    module.environment = environment
    module.index = index
    logging_dir = "#{logs_dir}/#{startup_time}"
    debug "logging_dir: %o", logging_dir
    (mkdirp-err) <- mkdirp logging_dir
    return done mkdirp-err if mkdirp-err?
    name = app_name
    streams = []
    {serializers} = bunyan-debug-stream
    opts = {name, streams, serializers}
    opts.streams.push do
      level: if verbose then \debug else \info
      type: \raw
      stream: bunyan-debug-stream.create do
        out: process.stderr
        basepath: app_dir
        forceColor: yes
        showProcess: no
        showDate: (time) -> return time.toISOString!.substring 2
        colors: debug: \gray, info: \white
        prefixers: prefixers
        stringifiers: stringifiers
    opts.streams.push do
      level: \debug
      stream: new bunyan-rotating-file-stream do
        path: "#{logging_dir}/#{name}.#{process_name}.%y-%m-%d.log"
        period: \daily
        rotateExisting: no
        threshold: \1g        # The maximum size for a log file to reach before it's rotated.
        totalFiles: 60        # Keep 60 days (2 months) of log files.
        totalSize: 0
        startNewFile: no
        gzip: yes
    logger = module.logger = bunyan.createLogger opts
    return done null, GET_LOGGER
