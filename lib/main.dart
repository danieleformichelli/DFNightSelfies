import 'dart:async';
import 'dart:io';

import 'package:album_saver/album_saver.dart';
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
import 'package:video_player/video_player.dart';

void main() => runApp(DfNightSelfiesApp());

enum DfNightSelfiesState {
  INIT,
  CAMERA_PREVIEW,
  COUNTDOWN,
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

class _DfNightSelfiesMainState extends State<DfNightSelfiesMain> {
  var photoOrVideo = true;
  var timer = 0;
  var remainingTimer = 0;

  var state = DfNightSelfiesState.INIT;
  CameraController _cameraController;
  VideoPlayerController _videoPlayerController;
  Future _initializeCameraControllerFuture;
  Widget _imagePreview;
  String _mediaPreviewPath;
  var _pictureToScreenRatio = 3;
  var _backgroundColor = Colors.white;

  @override
  void initState() {
    super.initState();

    _initializeCameraControllerFuture = initializeCameraController();
    Screen.setBrightness(1);
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _videoPlayerController?.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      child: Scaffold(
        body: SafeArea(
          child: getCameraPreviewOrMediaPreview(),
        ),
        backgroundColor: _backgroundColor,
        bottomNavigationBar: BottomAppBar(
          child: Row(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: getButtons(),
          ),
        ),
      ),
      onTap: () async {
        startCountDownOrTake();
      },
    );
  }

  Widget getCameraPreviewOrMediaPreview() {
    if (state == DfNightSelfiesState.MEDIA_PREVIEW) {
      if (_imagePreview != null) {
        // picture
        return _imagePreview;
      } else {
        // video
        var widget = Center(
          child: AspectRatio(
            aspectRatio: _videoPlayerController.value.aspectRatio,
            // Use the VideoPlayer widget to display the video
            child: VideoPlayer(_videoPlayerController),
          ),
        );
        _videoPlayerController.setLooping(true);
        _videoPlayerController.play();
        return widget;
      }
    } else {
      return FutureBuilder<void>(
        future: _initializeCameraControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return NativeDeviceOrientationReader(builder: (context) {
              int turns;
              double referenceSize;
              switch (NativeDeviceOrientationReader.orientation(context)) {
                case NativeDeviceOrientation.landscapeLeft:
                  turns = -1;
                  referenceSize = MediaQuery
                      .of(context)
                      .size
                      .width;
                  break;
                case NativeDeviceOrientation.landscapeRight:
                  turns = 1;
                  referenceSize = MediaQuery
                      .of(context)
                      .size
                      .width;
                  break;
                case NativeDeviceOrientation.portraitDown:
                  turns = 2;
                  referenceSize = MediaQuery
                      .of(context)
                      .size
                      .height;
                  break;
                default:
                  turns = 0;
                  referenceSize = MediaQuery
                      .of(context)
                      .size
                      .height;
                  break;
              }

              var cameraPreviewHeight = referenceSize / _pictureToScreenRatio;
              var cameraPreviewWidth =
                  cameraPreviewHeight * _cameraController.value.aspectRatio;
              var cameraPreviewBox = Center(
                child: RotatedBox(
                  quarterTurns: turns,
                  child: Container(
                    child: CameraPreview(_cameraController),
                    height: cameraPreviewHeight,
                    width: cameraPreviewWidth,
                  ),
                ),
              );

              var stackChildren = List<Widget>();
              stackChildren.add(cameraPreviewBox);
              if (remainingTimer != 0) {
                stackChildren.add(
                  Center(
                    child: Text(
                      '$remainingTimer',
                      style: TextStyle(fontSize: 64, color: Colors.white30),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }
              return Stack(children: stackChildren);
            });
          } else {
            return CircularProgressIndicator();
          }
        },
      );
    }
  }

  List<Widget> getButtons() {
    switch (state) {
      case DfNightSelfiesState.MEDIA_PREVIEW:
        return <Widget>[
          IconButton(
            icon: Icon(Icons.save),
            onPressed: () async {
              await saveMedia();
              restartPreview();
            },
          ),
          IconButton(
            icon: Icon(Icons.delete),
            onPressed: () {
              deleteMedia();
              restartPreview();
            },
          ),
          IconButton(
            icon: Icon(Icons.share),
            onPressed: () async {
              var fileName = await saveMedia();
              await shareMedia(fileName);
              restartPreview();
            },
          ),
        ];

      case DfNightSelfiesState.CAMERA_PREVIEW:
      case DfNightSelfiesState.INIT:
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
            icon: Icon(timer == 10
                ? Icons.timer_10
                : timer == 3 ? Icons.timer_3 : Icons.timer_off),
            onPressed: toggleTimer,
          ),
          IconButton(
            icon: Icon(photoOrVideo ? Icons.camera_alt : Icons.videocam),
            onPressed: togglePhotoOrVideo,
          ),
        ];

      default:
        return List();
    }
  }

  void restartPreview() {
    setState(() {
      _videoPlayerController?.pause();
      _videoPlayerController?.dispose();
      _videoPlayerController = null;

      _imagePreview = null;
      _mediaPreviewPath = null;
      state = DfNightSelfiesState.CAMERA_PREVIEW;
    });
  }

  void pickColor() {
    List<MaterialColor> colors = List<MaterialColor>();
    colors.addAll(Colors.primaries);
    colors.add(MaterialColor(Colors.white.value, Map()));

    showDialog(
      context: context,
      builder: (_) =>
          Center(
            child: Material(
              child: MaterialColorPicker(
                  allowShades: false,
                  colors: colors,
                  onMainColorChange: (Color color) {
                    setState(() {
                      _backgroundColor = color;
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
    });
  }

  Future<String> saveMedia() async {
    var permission =
    await PermissionHandler().requestPermissions([PermissionGroup.storage]);
    if (permission[PermissionGroup.storage] != PermissionStatus.granted) {
      return Future.error('Write storage permission not granted');
    }

    var fileFolder = join(await AlbumSaver.getDcimPath(), 'DFNightSelfies');
    await Directory(fileFolder).create(recursive: true);
    var filePath = join(fileFolder, basename(_mediaPreviewPath));
    File(_mediaPreviewPath).copySync(filePath);
    File(_mediaPreviewPath).delete();
    return Future.value(filePath);
  }

  void deleteMedia() {
    File(_mediaPreviewPath).delete();
    setState(() {
      state = DfNightSelfiesState.CAMERA_PREVIEW;
    });
  }

  Future shareMedia(String fileName) async {
    var fileBaseName = basename(fileName);
    return Share.file(fileBaseName, fileBaseName,
        File(fileName).readAsBytesSync(), 'image/png');
  }

  void togglePhotoOrVideo() {
    if (state != DfNightSelfiesState.CAMERA_PREVIEW) {
      return;
    }

    setState(() {
      photoOrVideo = !photoOrVideo;
    });
  }

  void toggleTimer() {
    if (state != DfNightSelfiesState.CAMERA_PREVIEW) {
      return;
    }

    setState(() {
      switch (timer) {
        case 0:
          timer = 3;
          break;
        case 3:
          timer = 10;
          break;
        default:
          timer = 0;
          break;
      }
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
    // In order to display the current output from the Camera, you need to
    // create a CameraController.
    _cameraController = CameraController(
      await getFrontCamera(),
      ResolutionPreset.high,
    );

    // Next, you need to initialize the controller. This returns a Future
    await _cameraController.initialize();
    state = DfNightSelfiesState.CAMERA_PREVIEW;
  }

  takePhoto() async {
    if (state != DfNightSelfiesState.CAMERA_PREVIEW &&
        state != DfNightSelfiesState.COUNTDOWN) {
      return;
    }

    try {
      state = DfNightSelfiesState.RECORDING;
      await _initializeCameraControllerFuture;

      final imagePath = join(
        (await getTemporaryDirectory()).path,
        'DFNightSelfies_${getDateTime()}.png',
      );

      await _cameraController.takePicture(imagePath);
      setState(() {
        state = DfNightSelfiesState.MEDIA_PREVIEW;
        _mediaPreviewPath = imagePath;
        _imagePreview = Center(child: Image.file(File(imagePath)));
      });
    } catch (e) {
      state = DfNightSelfiesState.CAMERA_PREVIEW;
      print(e);
    }
  }

  getDateTime() => DateFormat('yyyyMMddHHmmss').format(DateTime.now());

  startOrStopVideo() async {
    switch (state) {
      case DfNightSelfiesState.CAMERA_PREVIEW:
        setState(() {
          state = DfNightSelfiesState.RECORDING;
        });

        await _initializeCameraControllerFuture;

        _mediaPreviewPath = join(
          (await getTemporaryDirectory()).path,
          'DFNightSelfies_${getDateTime()}.mp4',
        );

        await _cameraController.prepareForVideoRecording();
        await _cameraController.startVideoRecording(_mediaPreviewPath);
        break;

      case DfNightSelfiesState.RECORDING:
        await _cameraController.stopVideoRecording();
        _videoPlayerController =
            VideoPlayerController.file(File(_mediaPreviewPath));
        await _videoPlayerController.initialize();
        setState(() {
          state = DfNightSelfiesState.MEDIA_PREVIEW;
        });
        break;

      default:
        return;
    }
  }

  void startCountDownOrTake() {
    if (timer == 0) {
      take();
    } else {
      setState(() {
        remainingTimer = timer;
        state = DfNightSelfiesState.COUNTDOWN;
        Timer _timer;
        _timer = new Timer.periodic(
          Duration(seconds: 1),
              (Timer timer) =>
              setState(
                    () {
                  --remainingTimer;
                  if (remainingTimer <= 0) {
                    _timer.cancel();
                    take();
                  }
                },
              ),
        );
      });
    }
  }

  void take() {
    photoOrVideo ? takePhoto() : startOrStopVideo();
  }
}
