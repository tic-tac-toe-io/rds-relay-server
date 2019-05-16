# rds-relay-server

WebSocket Relay Server for Remote Device Diagnosis

## Rename from "wstty-server"

[wstty-server](https://github.com/tic-tac-toe-io/wstty-server) was originally developed for embedded linux environment (running on the IoT gateway to manage many other IoT devices in the same subnet), so its codes are heavily dependent on [yapps](https://github.com/yagamy4680/yapps) and produce single bundle js file for execution with [browserify](http://browserify.org/). However, [yapps](https://github.com/yagamy4680/yapps) does not support cluster, which will be an obvious limitation to wstty-server at larger scale deployment. So, in the roadmap of wstty-server, we are planning to rewrite it from scratch by considering cloud native environment and scability since v2.0.

To align with v2.0 plan of wstty-server and our official service RDS (**Remote Diagnosis Service**) publish, we rename `wstty-server` to `rds-relay-server` and starts its first rollout version `v2.0.0`.