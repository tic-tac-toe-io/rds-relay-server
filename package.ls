#!/usr/bin/env lsc -cj
#

# Known issue:
#   when executing the `package.ls` directly, there is always error
#   "/usr/bin/env: lsc -cj: No such file or directory", that is because `env`
#   doesn't allow space.
#
#   More details are discussed on StackOverflow:
#     http://stackoverflow.com/questions/3306518/cannot-pass-an-argument-to-python-with-usr-bin-env-python
#
#   The alternative solution is to add `envns` script to /usr/bin directory
#   to solve the _no space_ issue.
#
#   Or, you can simply type `lsc -cj package.ls` to generate `package.json`
#   quickly.
#

# package.json
#
name: \rds-relay-server

author:
  name: \yagamy
  email: \yagamy@t2t.io

description: "WebSocket Relay Server for Remote Device Diagnosis"

version: \0.1.0

repository:
  type: \git
  url: \https://github.com/tic-tac-toe-io/rds-relay-server

main: \index

license: \MIT

dependencies:
  \@tic-tac-toe/yapps-server : \*
  \request : \*
  \moment-timezone : \*
  \passport : \*
  \passport-http : \*

devDependencies: {}

optionalDependencies: {}
