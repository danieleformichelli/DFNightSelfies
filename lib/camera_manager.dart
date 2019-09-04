import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:native_device_orientation/native_device_orientation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CameraManager {
  static final photoOrVideoKey = "PhotoOrVideo";
  var _isPhotoMode = true;

  static final pictureToScreenRatioKey = "PictureToScreenRatio";
  var _pictureToScreenRatio = 3;

  CameraController _cameraController;
  Future _initializeCameraControllerFuture;

  void switchMode() async {
    _isPhotoMode = !_isPhotoMode;
    saveSettings();
  }

  bool get isPhotoMode {
    return _isPhotoMode;
  }

  bool get isVideoMode {
    return !_isPhotoMode;
  }

  Future init() {
    _initializeCameraControllerFuture = initializeCameraController();
    return _initializeCameraControllerFuture;
  }

  Future initializeCameraController() async {
    var permission = await PermissionHandler().requestPermissions(
        [PermissionGroup.camera, PermissionGroup.microphone]);
    if (permission[PermissionGroup.camera] != PermissionStatus.granted) {
      return Future.error('Camera permission not granted');
    }
    if (permission[PermissionGroup.microphone] != PermissionStatus.granted) {
      return Future.error('Microphone permission not granted');
    }

    // In order to display the current output from the Camera, you need to
    // create a CameraController.
    _cameraController = CameraController(
      await getFrontCamera(),
      ResolutionPreset.max,
    );

    // Next, you need to initialize the controller. This returns a Future
    await _cameraController.initialize();
  }

  void dispose() {
    _cameraController?.dispose();
    _initializeCameraControllerFuture = null;
  }

  Future<CameraDescription> getFrontCamera() async {
    final cameras = await availableCameras();
    for (CameraDescription cameraDescription in cameras) {
      if (cameraDescription.lensDirection == CameraLensDirection.front) {
        return cameraDescription;
      }
    }

    return null;
  }

  Future initFuture() {
    return _initializeCameraControllerFuture;
  }

  Widget previewBox(BuildContext context) {
    int turns;
    double referenceSize;
    var size = MediaQuery.of(context).size;
    switch (NativeDeviceOrientationReader.orientation(context)) {
      case NativeDeviceOrientation.landscapeLeft:
        turns = -1;
        referenceSize = size.width;
        break;
      case NativeDeviceOrientation.landscapeRight:
        turns = 1;
        referenceSize = size.width;
        break;
      case NativeDeviceOrientation.portraitDown:
        turns = 2;
        referenceSize = size.height;
        break;
      default:
        turns = 0;
        referenceSize = size.height;
        break;
    }

    var cameraPreviewHeight = referenceSize / _pictureToScreenRatio;
    var cameraPreviewWidth =
        cameraPreviewHeight * _cameraController.value.aspectRatio;
    return RotatedBox(
      quarterTurns: turns,
      child: Container(
        child: CameraPreview(_cameraController),
        height: cameraPreviewHeight,
        width: cameraPreviewWidth,
      ),
    );
  }

  Future takePicture(String path) async {
    await _cameraController.takePicture(path);
  }

  Future startVideoRecording(String path) async {
    await _cameraController.prepareForVideoRecording();
    await _cameraController.startVideoRecording(path);
  }

  Future stopVideoRecording() async {
    await _cameraController.stopVideoRecording();
  }

  void togglePreviewSize() {
    ++_pictureToScreenRatio;
    if (_pictureToScreenRatio > 5) {
      _pictureToScreenRatio = 2;
    }
    saveSettings();
  }

  Future saveSettings() async {
    var preferences = await SharedPreferences.getInstance();
    preferences.setBool(photoOrVideoKey, _isPhotoMode);
    preferences.setInt(pictureToScreenRatioKey, _pictureToScreenRatio);
  }

  Future loadSettings() async {
    var preferences = await SharedPreferences.getInstance();
    _isPhotoMode = preferences.getBool(photoOrVideoKey) ?? _isPhotoMode;
    _pictureToScreenRatio =
        preferences.getInt(pictureToScreenRatioKey) ?? _pictureToScreenRatio;
  }
}
