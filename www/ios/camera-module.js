
var argscheck = require('cordova/argscheck'),
    utils = require('cordova/utils'),
    exec = require('cordova/exec');


var CameraModule = function() {
};

CameraModule.getPicture = function(successCallback, errorCallback) {
  exec(successCallback, errorCallback, "CameraModule", "getPicture", []);
};

module.exports = CameraModule;



