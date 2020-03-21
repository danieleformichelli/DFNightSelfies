import 'dart:async';
import 'dart:io';

import 'package:dfnightselfies/camera_manager.dart';
import 'package:dfnightselfies/countdown_manager.dart';
import 'package:dfnightselfies/export_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_material_color_picker/flutter_material_color_picker.dart';
import 'package:native_device_orientation/native_device_orientation.dart';
import 'package:screen/screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';

void main() => runApp(DfNightSelfiesApp());

enum DfNightSelfiesState { INIT, CAMERA_PREVIEW, COUNTDOWN, TAKING, RECORDING, MEDIA_PREVIEW }

class DfNightSelfiesApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DF Night Selfies',
      home: DfNightSelfiesMain(title: 'DF Night Selfies'),
    );
  }
}

class DfNightSelfiesMain extends StatefulWidget {
  DfNightSelfiesMain({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _DfNightSelfiesMainState createState() => _DfNightSelfiesMainState();
}

class _DfNightSelfiesMainState extends State<DfNightSelfiesMain> with WidgetsBindingObserver {
  static final backgroundColorKey = "BackgroundColor";
  var _backgroundColor = Colors.white;

  var _state = DfNightSelfiesState.INIT;
  VideoPlayerController _videoPlayerController;
  Widget _imagePreview;
  bool _isPaused = false;
  SharedPreferences _preferences;
  CameraManager _cameraManager = CameraManager();
  ExportManager _exportManager = ExportManager();
  CountdownManager _countdownManager = CountdownManager();

  @override
  void initState() {
    super.initState();

    loadSettings();
    WidgetsBinding.instance.addObserver(this);
    initializeCamera();
    Screen.setBrightness(1);
  }

  void initializeCamera() {
    _cameraManager.init().then((_) {
      if (_state == DfNightSelfiesState.INIT) {
        _state = DfNightSelfiesState.CAMERA_PREVIEW;
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    setState(() {
      if (_isPaused && state == AppLifecycleState.resumed) {
        _isPaused = false;
        initializeCamera();
      } else if (!_isPaused && state == AppLifecycleState.paused) {
        _isPaused = true;
        _cameraManager.dispose();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraManager.dispose();
    _videoPlayerController?.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: onBackButton,
      child: GestureDetector(
        child: Scaffold(
          body: SafeArea(
            child: Center(child: getCameraPreviewOrMediaPreview()),
          ),
          backgroundColor: _backgroundColor,
          bottomNavigationBar: BottomAppBar(
            child: Row(
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: getButtons(),
            ),
            color: _backgroundColor,
          ),
        ),
        onTap: () async {
          startCountDownOrTake();
        },
      ),
    );
  }

  Future<bool> onBackButton() {
    switch (_state) {
      case DfNightSelfiesState.MEDIA_PREVIEW:
        deleteTemporaryMediaAndRestartPreview();
        restartPreview();
        return Future.value(false);

      case DfNightSelfiesState.RECORDING:
        stopVideoRecording();
        return Future.value(false);

      default:
        return Future.value(true);
    }
  }

  Widget getCameraPreviewOrMediaPreview() {
    if (_state == DfNightSelfiesState.MEDIA_PREVIEW) {
      return getMediaPreview();
    } else {
      return getCameraPreview();
    }
  }

  Widget getMediaPreview() {
    if (_imagePreview != null) {
      // picture
      return _imagePreview;
    } else {
      // video
      var widget = AspectRatio(
        aspectRatio: _videoPlayerController.value.aspectRatio,
        // Use the VideoPlayer widget to display the video
        child: VideoPlayer(_videoPlayerController),
      );
      _videoPlayerController.setLooping(true);
      _videoPlayerController.play();
      return widget;
    }
  }

  StatefulWidget getCameraPreview() {
    if (_cameraManager.initFuture() == null) {
      return CircularProgressIndicator();
    }

    return FutureBuilder<void>(
      future: _cameraManager.initFuture(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return CircularProgressIndicator();
        }

        return NativeDeviceOrientationReader(builder: (context) {
          var cameraPreviewBox = _cameraManager.previewBox(context);
          var stackChildren = List<Widget>();
          stackChildren.add(Center(child: cameraPreviewBox));
          if (_state == DfNightSelfiesState.COUNTDOWN) {
            stackChildren.add(
              Center(
                child: _countdownManager.widget(),
              ),
            );
          }
          return Stack(children: stackChildren);
        });
      },
    );
  }

  List<Widget> getButtons() {
    switch (_state) {
      case DfNightSelfiesState.MEDIA_PREVIEW:
        return <Widget>[
          IconButton(
            icon: Icon(Icons.save),
            onPressed: () async {
              pauseVideo();
              await _exportManager.saveMedia();
              restartPreview();
            },
          ),
          IconButton(
            icon: Icon(Icons.delete),
            onPressed: () {
              deleteTemporaryMediaAndRestartPreview();
            },
          ),
          IconButton(
            icon: Icon(Icons.share),
            onPressed: () async {
              await _exportManager.shareMedia();
            },
          ),
        ];

      case DfNightSelfiesState.INIT:
      case DfNightSelfiesState.CAMERA_PREVIEW:
      case DfNightSelfiesState.TAKING:
        return <Widget>[
          IconButton(
            icon: Icon(Icons.colorize),
            onPressed: pickColor,
          ),
          IconButton(
            icon: Icon(Icons.photo_size_select_large),
            onPressed: togglePreviewSize,
          ),
          IconButton(
            icon: _countdownManager.icon,
            onPressed: toggleTimer,
          ),
          IconButton(
            icon: Icon(_cameraManager.isPhotoMode ? Icons.camera_alt : Icons.videocam),
            onPressed: togglePhotoOrVideo,
          ),
        ];

      case DfNightSelfiesState.COUNTDOWN:
        return <Widget>[
          IconButton(
            icon: Icon(Icons.cancel),
            onPressed: cancelCountDown,
          )
        ];
        break;

      case DfNightSelfiesState.RECORDING:
        return <Widget>[
          IconButton(
            icon: Icon(Icons.fiber_manual_record),
            color: Colors.red,
            onPressed: stopVideoRecording,
          )
        ];
    }

    return List();
  }

  void restartPreview() {
    setState(() {
      _imagePreview = null;
      _exportManager.reset();
      _state = DfNightSelfiesState.CAMERA_PREVIEW;
    });
  }

  void pickColor() {
    var colors = List<MaterialColor>();
    colors.addAll(Colors.primaries);
    colors.add(MaterialColor(Colors.white.value, Map()));

    showDialog(
      context: context,
      builder: (_) => Center(
        child: Material(
          child: MaterialColorPicker(
            allowShades: false,
            colors: colors,
            onMainColorChange: (Color color) {
              setState(() {
                _backgroundColor = color;
                _preferences.setInt(backgroundColorKey, _backgroundColor.value);
              });
            },
            selectedColor: _backgroundColor,
            shrinkWrap: true,
          ),
        ),
      ),
    );
  }

  void togglePreviewSize() {
    setState(() {
      _cameraManager.togglePreviewSize();
    });
  }

  void pauseVideo() {
    _videoPlayerController?.pause();
  }

  void deleteTemporaryMediaAndRestartPreview() {
    pauseVideo();
    _exportManager.deleteTemporaryFile();
    restartPreview();
  }

  void togglePhotoOrVideo() {
    if (_state != DfNightSelfiesState.CAMERA_PREVIEW) {
      return;
    }

    setState(() {
      _cameraManager.switchMode();
    });
  }

  void toggleTimer() {
    if (_state != DfNightSelfiesState.CAMERA_PREVIEW) {
      return;
    }

    setState(() {
      _countdownManager.toggle();
    });
  }

  takePhoto() async {
    if (_state != DfNightSelfiesState.TAKING) {
      return;
    }

    try {
      await _cameraManager.initFuture();

      var imagePath = await _exportManager.getTemporaryFile(true);

      await _cameraManager.takePicture(imagePath);
      setState(() {
        _state = DfNightSelfiesState.MEDIA_PREVIEW;
        _imagePreview = Center(child: Image.file(File(imagePath)));
      });
    } catch (e) {
      _state = DfNightSelfiesState.CAMERA_PREVIEW;
      print(e);
    }
  }

  startVideoRecording() async {
    await _cameraManager.initFuture();

    var videoPath = await _exportManager.getTemporaryFile(false);
    await _cameraManager.startVideoRecording(videoPath);
    setState(() {
      _state = DfNightSelfiesState.RECORDING;
    });
  }

  stopVideoRecording() async {
    await _cameraManager.stopVideoRecording();
    _videoPlayerController?.dispose();
    _videoPlayerController = VideoPlayerController.file(File(_exportManager.temporaryFile));
    await _videoPlayerController.initialize();
    setState(() {
      _state = DfNightSelfiesState.MEDIA_PREVIEW;
    });
  }

  void startCountDownOrTake() {
    if (_state == DfNightSelfiesState.RECORDING) {
      stopVideoRecording();
    }

    if (_state != DfNightSelfiesState.CAMERA_PREVIEW) {
      return;
    }

    if (!_countdownManager.enabled) {
      take();
    } else {
      setState(() {
        _state = DfNightSelfiesState.COUNTDOWN;
        _countdownManager.schedule((completed) {
          setState(() {
            if (completed) {
              take();
            }
          });
        });
      });
    }
  }

  void take() {
    setState(() {
      _state = DfNightSelfiesState.TAKING;
    });

    _cameraManager.isPhotoMode ? takePhoto() : startVideoRecording();
  }

  void cancelCountDown() {
    _countdownManager.cancel();
    restartPreview();
  }

  void loadSettings() async {
    _preferences = await SharedPreferences.getInstance();
    await _cameraManager.loadSettings();
    await _countdownManager.loadSettings();

    setState(() {
      var backgroundColorValue = _preferences.getInt(backgroundColorKey) ?? _backgroundColor.value;
      _backgroundColor = Color(backgroundColorValue);
    });
  }
}
