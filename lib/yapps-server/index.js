//
// Copyright (c) 2018 T2T Inc. All rights reserved
// https://www.t2t.io
// https://tic-tac-toe.io
// Taipei, Taiwan
//
'use strict';

var colors = require('colors');
var debug = require('debug')('yapps-server:index');
var filepath = './src/bootstrap';
var bootstrap = null;

debug("process.argv: %o", process.argv);

// Load `@tic-tac-toe/browserify-livescript-middleware` first, in order to load
// the `livescript` that is installed in the node_modules directory of
// `@tic-tac-toe/browserify-livescript-middleware`
/**
 * FIXME: missing livescript module because of npm install with git
 *
 * `@tic-tac-toe/browserify-livescript-middleware` uses a special fork of livescript
 * that fixed source map issue:
 *      github:ischenkodv/LiveScript
 *
 * However, npm install command will install livescript at the node_modules directory
 * of @tic-tac-toe/browserify-livescript-middleware, like following structure:
 *
 *  /yapps-server
 *      /node_modules
 *          /@tic-tac-toe
 *              /browserify-livescript-middleware
 *                  /node_modules
 *                      /livescript
 *
 * Then, when `yapps-server` tries to load `livescript` before loading
 * `@tic-tac-toe/browserify-livescript-middleware`, we always get missing
 * module error. To fix it in workaround way, we need to load
 * `@tic-tac-toe/browserify-livescript-middleware`.
 *
 * In the future, if `livescript` is upgraded with source map patch, then we will
 * not need this workaround anymore.
 */
var brls = require('@tic-tac-toe/browserify-livescript-middleware');
debug("successfully load @tic-tac-toe/browserify-livescript-middleware");
debug("require.resolve(colors): %o", require.resolve('colors'));
debug("require.resolve(livescript): %o", require.resolve('livescript'));
// debug("require.cache: %o", require.cache);

var livescript = require('livescript');
debug("successfully load livescript");

/**
 * Loading from ${__dirname}/src/bootstrap.ls
 */
try {
    if (!bootstrap) {
        debug('loading %s', filepath);
        bootstrap = require(filepath);
    }
} catch (error) {
    console.dir(error);
    console.error(`${__filename.gray}: failing back to ${__dirname}/lib/bootstrap.js`);
    filepath = './lib/bootstrap';
}

/**
 * Loading from ${__dirname}/lib/bootstrap.js
 */
try {
    if (!bootstrap) {
        debug('loading %s', filepath);
        bootstrap = require(filepath);
    }
} catch (error) {
    console.dir(error);
    console.error(`${__filename.gray}: failed to load ${filepath}, and exit 1.`);
    process.exit(1);
}

module.exports = exports = bootstrap;