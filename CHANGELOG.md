# Changelog

All notable changes to this project will be documented in this file. See [standard-version](https://github.com/conventional-changelog/standard-version) for commit guidelines.

### [2.0.5](https://github.com/tic-tac-toe-io/rds-relay-server/compare/v2.0.4...v2.0.5) (2019-10-06)


### Bug Fixes

* **dep:** missing livescript module ([9c42109](https://github.com/tic-tac-toe-io/rds-relay-server/commit/9c42109))

### 2.0.4 (2019-09-14)


### Bug Fixes

* **depds:** udpate package dependencies ([0d9fd1a](https://github.com/tic-tac-toe-io/rds-relay-server/commit/0d9fd1a))

## [2.0.3] - 2019-06-12
### Changed
- Attach service metadata when requesting geolocation info
- Breaking: use `yapps-server` v0.2.0 that support structural CLI commands

## [2.0.2] - 2019-06-10
### Changed
- Apply `yapps-server` v0.1.9

## [2.0.1] - 2019-06-09
### Fixed
- Fix startup failure due to missing `livescript` module in the NODE_PATH that `yapps-server` can load, by workaround methodology

## [2.0.0] - 2019-06-06
### Changed
- Migrate from `yapps` architecture (with browserify) to `yapps-server` architecture (v0.1.7)
- Change repository from https://github.com/tic-tac-toe-io/wstty-server to https://github.com/tic-tac-toe-io/rds-relay-server (treated as **WsttyServer2**)
- Better source-code-map support in frontend javascript


## [1.0.4] - 2019-05-16
### Changed
- upgrade `socket.io` from 2.0.4 to 2.2.0 (rollback from `uws` to `ws` engine)

### Fixed
- upgrade handlebars from 4.0.12 to 4.1.2 for vulnerability warning
- upgrade js-yaml from 3.11.0 to 3.13.1 for vulnerability warning

## [1.0.3] - 2019-05-15
### Changed
- upgrade `term.js` to `xterm.js` with better maintainabilitiy

### Fixed
- #1, blank screen because of missing geolocation information

## [1.0.2] - 2019-05-13
### Added
- Apply [CHANGELOG](https://keepachangelog.com/en/1.0.0/) format in repository

### Fixed
- Fix server url retrieval for localhost connections
- Server statistical metrics submitting to InfluxDB via `iw-client` is disabled by default

### Changed
- Fix server url retrieval for localhost connections
- Disable server statistical report (iw-client) to legacy influxdb (v0.8.8) by default

## [1.0.1] - 2019-04-23
### Changed
- Improve Terminal Web UI
- Retrieve geolocation information for each connected agent

## [1.0.0] - 2019-04-19
### Added
- v1.0 with `lookup-next-server` feature

## [0.9.9] - 2019-04-18
### Fixed
- fix connection info update issue

## [0.9.8] - 2019-02-02
### Added
- `filemgr`: support downloadFile operation

## [0.9.7] - 2019-01-31
### Added
- `bash-by-server`: refactorying web api implementation, and add `operation` to _configs_
- `bash-by-server`: move `apply-image` to TOE specific api: `/:id/yapps-scripts/v3/apply-image`

## [0.9.6] - 2019-01-31
### Added
- `bash-by-server`: support alias operation `apply-image`

## [0.9.5] - 2019-01-29
### Added
- `filemgr`: support readFile operation

## [0.9.4] - 2019-01-29
### Added
- `filemgr`: support env operation

## [0.9.3] - 2019-01-29
### Added
- `filemgr`: support readdir operation

## [0.9.2] - 2019-01-28
### Fixed
- Fix command-sock typo issue

## [0.9.1] - 2019-01-26
### Added
- `bash-by-server`: support progress indication to receiver server (http callback) via UnixSock server specified by environment variable: `WSTTY_AGENT_UNIXSOCK`
- `bash-by-server`: use **PUT** method to send execution log to receiver server (http callback) via multipart form
- `bash-by-server`: use **POST** method to forward progress indication event to receiver server (http callback)

## [0.9.0] - 2019-01-26
### Added
- Implement `bash-by-server` service

## [0.8.2] - 2018-10-30
### Changed
- Find other ipv4 address from all available interfaces when ipv4 is `unknown`

## [0.8.1] - 2018-10-30
### Changed
- Apply `uuid-v4` to generate request-id by default in HTTP-Relay. (Or specify `_uuid==false` to disable uuid)

## [0.8.0] - 2018-10-30
### Added
- Add `_uuid` option to query string of HTTP Relay APIs, to force to use uuid-v4 as task id to avoid gateway timeout issue

## [0.7.7] - 2018-05-01
### Added
- Add `instance_id` to communication context (cc) object when sending back to agent after registration

## [0.7.6] - 2018-04-27
### Changed
- Unify output logs for `agent-http-service`
- Implement `HTTP_BY_AGENT_ERR_SERVER_TIMEOUT`

## [0.7.5] - 2018-04-26
### Added
- Implement RPC for HTTP/REST apis of TOE apps based on `AGENT_EVENT_HTTP_BY_SERVER`: `/api/v1/toe/[id]/toe-agent/v3`, `/api/v1/toe/[id]/sensor-web/v3`, and `/api/v1/toe/[id]/sensor-web/v1`

## [0.7.4] - 2018-04-25
### Changed
- Use yapps to load `package.json` instead of pkginfo

## [0.7.3] - 2018-04-25
### Added
- Implement `AGENT_EVENT_HTTP_BY_SERVER`

## [0.7.1] - 2018-04-20
### Changed
- Improve pkginfo detection with directly-access to `module` variable by skipping browserify manipulation (storing `module` in the `global.yac-context` variable)

## [0.7.0] - 2018-04-19
### Changed
- Implement protocol 0.2.0
- Improve mac address and ip address detection
- Improve web UI with humanized uptime and protocol information

## [0.6.3] - 2018-04-19
### Added
- Add passport for HTTP Basic Authentication

## [0.6.2] - 2018-04-18
### Changed
- Replace `prelude-ls` with lodash
- Remove unused module dependencies: `jade`, `serve-favicon`, `multer`, `method-override`, and `express-partial-response`
- Upgrade `pug` from 2.0.0-rc4 to 2.0.3

## [0.6.1] - 2017-12-16
### Changed
- Upgrade socketio-auth from 0.0.4 to 0.1.0
- Replace [jade](http://jade-lang.com/) with [pug](https://github.com/pugjs/pug)

## [0.6.0] - 2017-12-16
### Changed
- Upgrade [socket.io](https://github.com/socketio/socket.io) from 1.3.7 to 2.0.4

## [0.5.6] - 2017-07-04
### Added
- Update system metrics to sysadmin database

## [0.5.4] - 2017-05-29
### Changed
- WebUI: `SourceCodePro-ExtraLight` is added to the 1st element of default fonts
- WebUI: change font size to 10px
- WebUI: Change FG and BG colors for terminal

## [0.5.3] - 2017-05-02
### Fixed
- Correctly clean up resources for duplicate agent error
- Submit `[db]:/[id]/tic/wstty/agent/duplicate` data every 60s

## [0.5.2] - 2017-04-22
### Changed
- Use incremental uptime updater
- Force underlying socket connection to be closed when duplicated agent exists (close the newer one)
- Dump more information when duplicate agent takes place

## [0.5.1] - 2017-04-22
### Fixed
- Fix state-updater bug

## [0.5.0] - 2017-04-21
### Added
- Add more metrics with `iw-client` to update influxdb: `[db]:/[id]/tic/wstty/user.[username]/uptime`, `[db]:/[id]/tic/wstty/user.[username]/state`, `api:/[site]/wstty/system/agents/total`, `api:/[site]/wstty/system/agents/onlines`, and `api:/[site]/wstty/system/agents/offlines`
- Improve verbose messages

## [0.4.3] - 2017-01-08
### Fixed
- Ensure the index of short-connection instance is printed out when disconnection.

## [0.4.2] - 2017-01-08
### Fixed
- Fix short disconnection issue

## [0.4.1] - 2017-01-08
### Added
- Add index and username of web terminal pairing

## [0.4.0] - 2017-01-08
### Changed
- Improve logging messages
- Add system websocket channel for monitoring and management purpose
- Add sensorweb-client to update number of connected agents and the uptime of each agent session

## [0.2.2] - 2016-09-05
### Fixed
- Fix a critical bug that is caused by mis-deleting the listener `me-on-depair` in agent-mgr

## [0.2.1] - 2016-09-02
### Changed
- Improve state consistency when `disconnect` event takes place before `pair` event

## [0.2.0] - 2016-08-15
### Changed
- Refactor packet protocol in order to support both `pty.spawn` and `child_process.spawn`

## [0.1.6] - 2016-07-12
### Changed
- Disable pretty-json outputs
- Replace uart-board with communicator
- Replace parser with legacy.ls

## [0.1.0] - 2015-10-31
### Added
- Initial version of SensorWeb on yapps-tt framework.
