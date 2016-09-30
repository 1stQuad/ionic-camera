
var argscheck = require('cordova/argscheck'),
    utils = require('cordova/utils'),
    exec = require('cordova/exec');


var CameraModule = function() {
};

CameraModule.getPicture = function(successCallback, errorCallback) {
  exec(successCallback, errorCallback, "CameraModule", "getPicture", []);
};

CameraModule.pictureRecognized = function () {
    exec(null, null, "CameraModule", "pictureRecognized", []);
};

module.exports = CameraModule;

