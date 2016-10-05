
var argscheck = require('cordova/argscheck'),
    utils = require('cordova/utils'),
    exec = require('cordova/exec');


var CameraModule = function() {
};

CameraModule.getPicture = function(successCallback, errorCallback) {
  exec(successCallback, errorCallback, "CameraLauncher", "getPicture", []);
};

CameraModule.pictureRecognized = function () {
    exec(null, null, "CameraLauncher", "pictureRecognized", []);
};

module.exports = CameraModule;

