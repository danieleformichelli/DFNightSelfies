import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:native_device_orientation/native_device_orientation.dart';
import 'package:path/path.dart' show join;
import 'package:path_provider/path_provider.dart';

void main() => runApp(DfNightSelfiesApp());

enum DfNightSelfiesState {
  INIT,
  CAMERA_PREVIEW,
  COUNTDOWN,
  RECORDING,
  IMAGE_PREVIEW
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

  var state = DfNightSelfiesState.INIT;
  CameraController _controller;
  Future _initializeControllerFuture;
  Image _imagePreview;
  String _imagePreviewPath;

  @override
  void initState() {
    super.initState();

    _initializeControllerFuture = initializeCameraController();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        child: Container(
          child: Center(
            child: getPreviewOrImage(),
          ),
        ),
        onTap: () async {
          takePhotoOrVideo();
        },
      ),
      bottomNavigationBar: BottomAppBar(
        child: Row(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: getButtons(),
        ),
      ),
    );
  }

  Widget getPreviewOrImage() {
    if (state == DfNightSelfiesState.IMAGE_PREVIEW) {
      return _imagePreview;
    } else {
      return FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
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

              var cameraPreviewHeight = referenceSize / 3;
              var cameraPreviewWidth =
                  cameraPreviewHeight * _controller.value.aspectRatio;
              return RotatedBox(
                quarterTurns: turns,
                child: Container(
                  child: CameraPreview(_controller),
                  height: cameraPreviewHeight,
                  width: cameraPreviewWidth,
                ),
              );
            });
          } else {
            return CircularProgressIndicator();
          }
        },
      );
    }
  }

  List<Widget> getButtons() {
    if (state == DfNightSelfiesState.IMAGE_PREVIEW) {
      return <Widget>[
        IconButton(
          icon: Icon(Icons.check),
          onPressed: () async {
            saveImagePreview();
            setState(() {
              state = DfNightSelfiesState.CAMERA_PREVIEW;
            });
          },
        ),
        IconButton(
          icon: Icon(Icons.delete),
          onPressed: deleteImagePreview,
        ),
        IconButton(
          icon: Icon(Icons.share),
          onPressed: () async {
            shareImage(await saveImagePreview());
          },
        ),
      ];
    } else {
      return <Widget>[
        IconButton(
          icon: Icon(Icons.photo_library),
          onPressed: openLibrary,
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
    }
  }

  Future<String> saveImagePreview() async {
    setState(() {
      // TODO save
      _imagePreview = null;
      _imagePreviewPath = null;
    });

    return '';
  }

  void deleteImagePreview() {
    saveImagePreview();
    setState(() {
      state = DfNightSelfiesState.CAMERA_PREVIEW;
    });
  }

  void openLibrary() {
    if (state != DfNightSelfiesState.CAMERA_PREVIEW) {
      return;
    }
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
    _controller = CameraController(
      await getFrontCamera(),
      ResolutionPreset.high,
    );

    // Next, you need to initialize the controller. This returns a Future
    await _controller.initialize();
    state = DfNightSelfiesState.CAMERA_PREVIEW;
  }

  takePhotoOrVideo() async {
    if (state != DfNightSelfiesState.CAMERA_PREVIEW) {
      return;
    }

    try {
      state = DfNightSelfiesState.RECORDING;
      await _initializeControllerFuture;

      final imagePath = join(
        (await getTemporaryDirectory()).path,
        'DFNightSelfies_${DateTime.now()}.png',
      );

      await _controller.takePicture(imagePath);
      setState(() {
        state = DfNightSelfiesState.IMAGE_PREVIEW;
        _imagePreviewPath = imagePath;
        _imagePreview = Image.file(File(imagePath));
      });
    } catch (e) {
      state = DfNightSelfiesState.CAMERA_PREVIEW;
      print(e);
    }
  }

  void shareImage(String filePath) {}
}
