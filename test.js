// PLEASE NOTE THAT THIS IS A TEST FILE FOR LEARNING AND DEVELOPMENT (hence why is messy!)

'use strict';

const EXPRESS_PORT = 3000;

// CORE MODULES
var https       = require('https');
var express     = require('express')();
var serveStatic = require('serve-static');
var fs          = require('fs');

var PoolModel   = require('./server/models/sbd-pool');
var sbdPool     = new PoolModel(config,acl);

var rootHandler = require('./server/routes/');
// TEMP
var apiUser     = require('./server/routes/user');
var apiAdmin    = require('./server/routes/admin');



function root_get (req, res){
    res.sendFile(appRoot + '/client/index.html')
}


// Setup ACL permissions... note that whilst express will allow /route to also
// match /route/ - the acl module doesn't and needs this to be specified exlicitly
acl = new acl(new acl.memoryBackend(),aclCertAuth.simpleLogger);
acl.addUserRoles('user1','users');
acl.addRoleParents('admins','allRoles');
acl.addRoleParents('users','allRoles');


// NON-ACL CONTROLLED (STATIC) RESOURCES
// Place ahead of express.use(acl.middleware()), which (implicitly) will expressly to all other routes
express.use('/', rootHandler)
express.use('/resources', serveStatic(__dirname + '/client'));
express.use(favicon(__dirname + '/client/img/favicon.ico'));

// MIDDLEWARE
express.use(aclCertAuth.authenticate);
express.use(acl.middleware());
express.use(aclCertAuth.errorHandler);
express.use(bodyParser.json());

// ACL CONTROLLED ROUTES
acl.allow('admins',['/adminapi','/adminapi/'],'get');
express.use('/adminapi', apiAdmin);

acl.allow('users' ,['/userapi','/userapi/']  ,'get');
express.use('/userapi', apiUser);


// WEB SERVER START
var httpsConfig = {
    host:               "myserver", 
    pfx:                fs.readFileSync(__dirname + '/config/certs/myserver.open.pfx'),
    ca:                 [ fs.readFileSync(__dirname + '/config/certs/myserver.ca.cert') ],
    requestCert:        true,
    rejectUnauthorized: true
}

https.createServer(httpsConfig, express).listen(EXPRESS_PORT);

console.log(timestamp() + ': Application listening on port ' + EXPRESS_PORT);