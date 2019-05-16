#
# Copyright (c) 2018 T2T Inc. All rights reserved
# https://www.t2t.io
# https://tic-tac-toe.io
# Taipei, Taiwan
#
require! <[path zlib lodash express]>
{DBG, ERR, WARN, INFO} = global.ys.services.get_module_logger __filename

module.exports = exports =
  name: \test1

  attach: (name, environment, configs, helpers) ->
    INFO "configs => #{JSON.stringify configs}"
    INFO "environment => #{JSON.stringify environment}"
    # module.configs = lodash.merge {}, DEFAULT_SETTINGS, configs
    return <[web]>

  init: (p, done) ->
    {web} = context = @
    {REST_ERR, REST_DAT, UPLOAD} = web.get_rest_helpers!
    module.context = context
    return done!
    /*
    hub = new express!
    hub.post '/:id/:profile', (UPLOAD.single \sensor_data_gz), (req, res) ->
      received = (new Date!) - 0
      {file, params, query} = req
      {id, profile} = params
      return NG "invalid file upload form", -1, 400, req, res unless file?
      {fieldname, originalname, size, buffer, mimetype} = file
      return NG "missing sensor_data_gz field", -1, 400, req, res unless fieldname == \sensor_data_gz
      return PROCESS_EMPTY_DATA id, profile, originalname, req, res if size is 0
      file.buffer = null
      filename = originalname
      bytes = buffer.length

      {tz} = query
      now = (new Date!) - 0
      time = PARSE_TIMESTAMP 1, filename, profile, id, tz, req
      diff = now - (time - 0)
      text = "#{diff}"
      DBG "#{req.originalUrl.yellow}: #{filename} (#{mimetype}) with #{bytes} bytes (time => #{time.format 'YYYY/MM/DD HH:mm:ss'}; diff => #{text.magenta}; local => #{req.query.local})"

      return PROCESS_EMPTY_DATA id, profile, filename, req, res if size is 0
      (zerr, raw) <- zlib.gunzip buffer
      return PROCESS_CORRUPT_COMPRESSED_DATA id, profile, filename, zerr, req, res if zerr?
      (jerr, data) <- PARSE_JSON raw
      return PROCESS_CORRUPT_JSON_DATA id, profile, filename, jerr, req, res if jerr?
      res.status 200 .json { code: 0, message: null, result: {id, profile, filename, bytes} }
      {items} = data
      INFO "#{req.originalUrl.yellow}: #{filename} (#{items.length} points) is decompressed from #{bytes} to #{raw.length} bytes"

      compressed-size = bytes
      raw-size = raw.length
      measured = time.valueOf!
      return context.emit APPEVT_TIME_SERIES_V1_DATA_POINTS, profile, id, items, do
        source: \toe1-upload
        upload: {filename, compressed-size, raw-size}
        timestamps: {measured, received}

    web.use-api \hub, hub, 1
    return done!
    */

  fini: (p, done) ->
    return done!
