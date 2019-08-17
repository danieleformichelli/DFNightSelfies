import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:esys_flutter_share/esys_flutter_share.dart';
import 'package:flutter/material.dart';
import 'package:flutter_material_color_picker/flutter_material_color_picker.dart';
import 'package:intl/intl.dart';
import 'package:native_device_orientation/native_device_orientation.dart';
import 'package:path/path.dart' show join;
import 'package:path/path.dart' show basename;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:screen/screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';

void main() => runApp(DfNightSelfiesApp());

enum DfNightSelfiesState {
  INIT,
  CAMERA_PREVIEW,
  COUNTDOWN,
  TAKING,
  RECORDING,
  MEDIA_PREVIEW
}

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

class _DfNightSelfiesMainState extends State<DfNightSelfiesMain>
    with WidgetsBindingObserver {
  static final photoOrVideoKey = "PhotoOrVideo";
  var _photoOrVideo = true;

  static final timerKey = "Timer";
  var _timer = 0;
  var _remainingTimer = 0;

  static final pictureToScreenRatioKey = "PictureToScreenRatio";
  var _pictureToScreenRatio = 3;

  static final backgroundColorKey = "BackgroundColor";
  var _backgroundColor = Colors.white;

  var _state = DfNightSelfiesState.INIT;
  CameraController _cameraController;
  VideoPlayerController _videoPlayerController;
  Future _initializeCameraControllerFuture;
  Widget _imagePreview;
  String _mediaPreviewPath;
  AppLifecycleState _lastLifecyleState;
  Timer _countdownTimer;
  SharedPreferences _preferences;

  @override
  void initState() {
    super.initState();

    loadSettings();
    WidgetsBinding.instance.addObserver(this);
    _initializeCameraControllerFuture = initializeCameraController();
    Screen.setBrightness(1);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    setState(() {
      if (_lastLifecyleState != AppLifecycleState.resumed &&
          state == AppLifecycleState.resumed) {
        _initializeCameraControllerFuture = initializeCameraController();
      } else if (_lastLifecyleState == AppLifecycleState.resumed &&
          state != AppLifecycleState.resumed) {
        _cameraController?.dispose();
        _initializeCameraControllerFuture = null;
      }
      _lastLifecyleState = state;
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
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
        deleteTemporaryMedia();
        restartPreview();
        return Future.value(false);

      case DfNightSelfiesState.RECORDING:
        stopVideo();
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
    if (_initializeCameraControllerFuture == null) {
      return CircularProgressIndicator();
    }

    return FutureBuilder<void>(
      future: _initializeCameraControllerFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return CircularProgressIndicator();
        }

        return NativeDeviceOrientationReader(builder: (context) {
          int turns;
          double referenceSize;
          switch (NativeDeviceOrientationReader.orientation(context)) {
            case NativeDeviceOrientation.landscapeLeft:
              turns = -1;
              referenceSize = MediaQuery.of(context).size.width;
              break;
            case NativeDeviceOrientation.landscapeRight:
              turns = 1;
              referenceSize = MediaQuery.of(context).size.width;
              break;
            case NativeDeviceOrientation.portraitDown:
              turns = 2;
              referenceSize = MediaQuery.of(context).size.height;
              break;
            default:
              turns = 0;
              referenceSize = MediaQuery.of(context).size.height;
              break;
          }

          var cameraPreviewHeight = referenceSize / _pictureToScreenRatio;
          var cameraPreviewWidth =
              cameraPreviewHeight / _cameraController.value.aspectRatio;
          var cameraPreviewBox = RotatedBox(
            quarterTurns: turns,
            child: Container(
              child: CameraPreview(_cameraController),
              height: cameraPreviewHeight,
              width: cameraPreviewWidth,
            ),
          );

          var stackChildren = List<Widget>();
          stackChildren.add(Center(child: cameraPreviewBox));
          if (_state == DfNightSelfiesState.COUNTDOWN) {
            stackChildren.add(
              Center(
                child: Text(
                  '$_remainingTimer',
                  style: TextStyle(fontSize: 64, color: Colors.white30),
                  textAlign: TextAlign.center,
                ),
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
              saveMedia().then((path) => deleteTemporaryMedia());
              restartPreview();
            },
          ),
          IconButton(
            icon: Icon(Icons.delete),
            onPressed: () {
              deleteTemporaryMedia();
              restartPreview();
            },
          ),
          IconButton(
            icon: Icon(Icons.share),
            onPressed: () async {
              await shareMedia();
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
            icon: Icon(_timer == 10
                ? Icons.timer_10
                : _timer == 3 ? Icons.timer_3 : Icons.timer_off),
            onPressed: toggleTimer,
          ),
          IconButton(
            icon: Icon(_photoOrVideo ? Icons.camera_alt : Icons.videocam),
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
            onPressed: stopVideo,
          )
        ];
    }

    return List();
  }

  void restartPreview() {
    setState(() {
      _imagePreview = null;
      _mediaPreviewPath = null;
      _state = DfNightSelfiesState.CAMERA_PREVIEW;
    });
  }

  void pickColor() {
    List<MaterialColor> colors = List<MaterialColor>();
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
                  _preferences.setInt(
                      backgroundColorKey, _backgroundColor.value);
                });
              },
              selectedColor: _backgroundColor),
        ),
      ),
    );
  }

  void togglePreviewSize() {
    setState(() {
      ++_pictureToScreenRatio;
      if (_pictureToScreenRatio > 5) {
        _pictureToScreenRatio = 2;
      }
      _preferences.setInt(pictureToScreenRatioKey, _pictureToScreenRatio);
    });
  }

  List<int> imageBytes() {
    return new File(_mediaPreviewPath).readAsBytesSync();
  }

  Future saveMedia() async {
    if (Platform.isAndroid) {
      var permission = await PermissionHandler()
          .requestPermissions([PermissionGroup.storage]);
      if (permission[PermissionGroup.storage] != PermissionStatus.granted) {
        return Future.error('Write storage permission not granted');
      }
    }

    return ImageGallerySaver.save(
        new File(_mediaPreviewPath).readAsBytesSync());
  }

  void deleteTemporaryMedia() {
    _videoPlayerController?.pause();

    File(_mediaPreviewPath).delete();
    _mediaPreviewPath = null;

    setState(() {
      _state = DfNightSelfiesState.CAMERA_PREVIEW;
    });
  }

  Future shareMedia() async {
    var fileBaseName = basename(_mediaPreviewPath);
    return Share.file(fileBaseName, fileBaseName, imageBytes(),
        _photoOrVideo ? 'image/png' : 'video/mp4');
  }

  void togglePhotoOrVideo() {
    if (_state != DfNightSelfiesState.CAMERA_PREVIEW) {
      return;
    }

    setState(() {
      _photoOrVideo = !_photoOrVideo;
      _preferences.setBool(photoOrVideoKey, _photoOrVideo);
    });
  }

  void toggleTimer() {
    if (_state != DfNightSelfiesState.CAMERA_PREVIEW) {
      return;
    }

    setState(() {
      switch (_timer) {
        case 0:
          _timer = 3;
          break;
        case 3:
          _timer = 10;
          break;
        default:
          _timer = 0;
          break;
      }
      _preferences.setInt(timerKey, _timer);
    });
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
      ResolutionPreset.veryHigh,
    );

    // Next, you need to initialize the controller. This returns a Future
    await _cameraController.initialize();
    if (_state == DfNightSelfiesState.INIT) {
      _state = DfNightSelfiesState.CAMERA_PREVIEW;
    }
  }

  takePhoto() async {
    if (_state != DfNightSelfiesState.TAKING) {
      return;
    }

    try {
      await _initializeCameraControllerFuture;

      final imagePath = join(
        (await getTemporaryDirectory()).path,
        'DFNightSelfies_${getDateTime()}.png',
      );

      await _cameraController.takePicture(imagePath);
      setState(() {
        _state = DfNightSelfiesState.MEDIA_PREVIEW;
        _mediaPreviewPath = imagePath;
        _imagePreview = Center(child: Image.file(File(imagePath)));
      });
    } catch (e) {
      _state = DfNightSelfiesState.CAMERA_PREVIEW;
      print(e);
    }
  }

  getDateTime() => DateFormat('yyyyMMddHHmmss').format(DateTime.now());

  startVideo() async {
    await _initializeCameraControllerFuture;

    _mediaPreviewPath = join(
      (await getTemporaryDirectory()).path,
      'DFNightSelfies_${getDateTime()}.mp4',
    );

    await _cameraController.prepareForVideoRecording();
    await _cameraController.prepareForVideoRecording();
    await _cameraController.startVideoRecording(_mediaPreviewPath);
    setState(() {
      _state = DfNightSelfiesState.RECORDING;
    });
  }

  stopVideo() async {
    await _cameraController.stopVideoRecording();
    _videoPlayerController?.dispose();
    _videoPlayerController =
        VideoPlayerController.file(File(_mediaPreviewPath));
    await _videoPlayerController.initialize();
    setState(() {
      _state = DfNightSelfiesState.MEDIA_PREVIEW;
    });
  }

  void startCountDownOrTake() {
    if (_state == DfNightSelfiesState.RECORDING) {
      stopVideo();
    }

    if (_state != DfNightSelfiesState.CAMERA_PREVIEW) {
      return;
    }

    if (_timer == 0) {
      take();
    } else {
      setState(() {
        _remainingTimer = _timer;
        _state = DfNightSelfiesState.COUNTDOWN;
        _countdownTimer = new Timer.periodic(
          Duration(seconds: 1),
          (Timer timer) => setState(
            () {
              if (_countdownTimer == null) {
                // canceled
                return;
              }

              --_remainingTimer;
              if (_remainingTimer <= 0) {
                _countdownTimer.cancel();
                take();
              }
            },
          ),
        );
      });
    }
  }

  void take() {
    setState(() {
      _state = DfNightSelfiesState.TAKING;
    });

    _photoOrVideo ? takePhoto() : startVideo();
  }

  void cancelCountDown() {
    _countdownTimer.cancel();
    _countdownTimer = null;
    restartPreview();
  }

  void loadSettings() async {
    _preferences = await SharedPreferences.getInstance();

    setState(() {
      _photoOrVideo = _preferences.getBool(photoOrVideoKey) ?? _photoOrVideo;
      _timer = _preferences.getInt(timerKey) ?? _timer;
      _pictureToScreenRatio =
          _preferences.getInt(pictureToScreenRatioKey) ?? _pictureToScreenRatio;
      var backgroundColorValue =
          _preferences.getInt(backgroundColorKey) ?? _backgroundColor.value;
      _backgroundColor = Color(backgroundColorValue);
    });
  }
}
