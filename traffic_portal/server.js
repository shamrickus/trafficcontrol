/*
 * Licensed to the Apache Software Foundation (ASF) under one
 * or more contributor license agreements.  See the NOTICE file
 * distributed with this work for additional information
 * regarding copyright ownership.  The ASF licenses this file
 * to you under the Apache License, Version 2.0 (the
 * "License"); you may not use this file except in compliance
 * with the License.  You may obtain a copy of the License at
 * 
 *   http://www.apache.org/licenses/LICENSE-2.0
 * 
 * Unless required by applicable law or agreed to in writing,
 * software distributed under the License is distributed on an
 * "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
 * KIND, either express or implied.  See the License for the
 * specific language governing permissions and limitations
 * under the License.
 */

var constants = require('constants'),
    express = require('express'),
    http = require('http'),
    https = require('https'),
    path = require('path'),
    fs = require('fs'),
    morgan = require('morgan'),
    modRewrite = require('connect-modrewrite'),
    timeout = require('connect-timeout'),
    useragent = require("express-useragent");

var config;

try {
    config = require('/etc/traffic_portal/conf/config');
}
catch(e) {
    let file = "./conf/config";
    if((process.env.NODE_ENV || "prod") === "dev")
        file = './conf/configDev';
    config = require(file);
}

var logStream = fs.createWriteStream(config.log.stream, { flags: 'a' }),
    useSSL = config.useSSL;

// Disable for self-signed certs in dev/test
process.env.NODE_TLS_REJECT_UNAUTHORIZED = config.reject_unauthorized;

var app = express();

app.use(function(req, res, next) {
    var err = null;
    try {
        decodeURIComponent(req.path);
    }
    catch(e) {
        err = e;
    }
    if (err){
        console.log(err, req.url);
    }
    next();
});

// Add a handler to inspect the req.secure flag (see
// http://expressjs.com/api#req.secure). This allows us
// to know whether the request was via http or https.
app.all ("/*", function (req, res, next) {
    if (useSSL && !req.secure) {
        // request was via http, so redirect to https
        return res.redirect(['https://', req.get('Host'), ':', config.sslPort, req.url].join(''));
    } else {
        let ua = useragent.parse(req.headers['user-agent']);
        console.log(ua.source + " requested: " + req.url);
        // request was via https or useSSL=false, so do no special handling
        next();
    }
});

app.use(modRewrite([
    '^/api/(.*?)\\?(.*)$ ' + config.api.base_url + '$1?$2 [P]',
    '^/api/(.*)$ ' + config.api.base_url + '$1 [P]',
    '^/sso\\?(.*)$ ' + '#!/sso?$1 [R]'
]));

app.use(express.static(config.files.static));
app.use(morgan('combined', {
    stream: logStream,
    skip: function (req, res) { return res.statusCode < 400 }
}));
app.use(timeout(config.timeout));

if (app.get('env') === 'dev') {
    app.use(require('connect-livereload')({
        port: 35728,
        excludeList: ['.woff', '.flv']
    }));
} else {
    app.set('env', 'production');
}

// Enable reverse proxy support in Express. This causes the
// the "X-Forwarded-Proto" header field to be trusted so its
// value can be used to determine the protocol. See
// http://expressjs.com/api#app-settings for more details.
app.enable('trust proxy');

// Startup HTTP Server
var httpServer = http.createServer(app);
httpServer.listen(config.port);

if (useSSL) {
    //
    // Supply `SSL_OP_NO_SSLv3` constant as secureOption to disable SSLv3
    // from the list of supported protocols that SSLv23_method supports.
    //
    var sslOptions = {};
    sslOptions['secureOptions'] = constants.SSL_OP_NO_TLSv1;

    sslOptions['key'] = fs.readFileSync(config.ssl.key);
    sslOptions['cert'] = fs.readFileSync(config.ssl.cert);
    sslOptions['ca'] = config.ssl.ca.map(function(cert){
        return fs.readFileSync(cert);
    });

    // Startup HTTPS Server
    var httpsServer = https.createServer(sslOptions, app);
    httpsServer.listen(config.sslPort);

    sslOptions.agent = new https.Agent(sslOptions);
}

console.log("Traffic Portal Port         : %s", config.port);
console.log("Traffic Portal SSL Port     : %s", config.sslPort);
