// PLEASE NOTE THAT THIS IS A TEST FILE FOR LEARNING AND DEVELOPMENT (hence why is messy!)

'use strict';

const EXPRESS_PORT = 3000;

// CORE MODULES
var https       = require('https');
var http        = require('http');
var app         = require('express')();
var fs          = require('fs');

//var httpsConfig = {
//    host:               "http://ec2-52-56-217-122.eu-west-2.compute.amazonaws.com", 
//    pfx:                fs.readFileSync(__dirname + '/myserver.pfx'),
//    ca:                 [ fs.readFileSync(__dirname + '/ca.cert') ],
//    requestCert:        false,
//    rejectUnauthorized: false
//}

app.get('/',function(req,res){
  res.send('ok')
});

app.get('/file',function(req,res){
  res.sendFile(__dirname + 'file');
})

//https.createServer(httpsConfig, express).listen(EXPRESS_PORT);
http.createServer(express).listen(EXPRESS_PORT);

console.log(': Application listening on port ' + EXPRESS_PORT);
