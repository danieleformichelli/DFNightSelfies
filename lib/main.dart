import 'dart:io';

import 'package:album_saver/album_saver.dart';
import 'package:camera/camera.dart';
import 'package:esys_flutter_share/esys_flutter_share.dart';
import 'package:flutter/material.dart';
import 'package:flutter_material_color_picker/flutter_material_color_picker.dart';
import 'package:native_device_orientation/native_device_orientation.dart';
import 'package:path/path.dart' show join;
import 'package:path/path.dart' show basename;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:screen/screen.dart';

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
  var _pictureToScreenRatio = 3;
  var _backgroundColor = Colors.white;

  @override
  void initState() {
    super.initState();

    _initializeControllerFuture = initializeCameraController();
    Screen.setBrightness(1);
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
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: getPreviewOrImage(),
              ),
            ),
          ],
        ),
        onTap: () async {
          takePhotoOrVideo();
        },
      ),
      backgroundColor: _backgroundColor,
      bottomNavigationBar: BottomAppBar(
        child: Row(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
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

              var cameraPreviewHeight = referenceSize / _pictureToScreenRatio;
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
          icon: Icon(Icons.save),
          onPressed: () async {
            await saveImage();
            restartPreview();
          },
        ),
        IconButton(
          icon: Icon(Icons.delete),
          onPressed: () {
            deleteImage();
            restartPreview();
          },
        ),
        IconButton(
          icon: Icon(Icons.share),
          onPressed: () async {
            await saveImage();
            await shareImage();
            deleteImage();
            restartPreview();
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
          icon: Icon(Icons.colorize),
          onPressed: pickColor,
        ),
        IconButton(
          icon: Icon(Icons.photo_size_select_large),
          onPressed: togglePreviewSize,
        ),
        IconButton(
          icon: Icon(photoOrVideo ? Icons.camera_alt : Icons.videocam),
          onPressed: togglePhotoOrVideo,
        ),
      ];
    }
  }

  void restartPreview() {
    setState(() {
      state = DfNightSelfiesState.CAMERA_PREVIEW;
      _imagePreview = null;
      _imagePreviewPath = null;
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

  saveImage() async {
    var permission =
        await PermissionHandler().requestPermissions([PermissionGroup.storage]);
    if (permission[PermissionGroup.storage] != PermissionStatus.granted) {
      return Future.error('Write storage permission not granted');
    }

    AlbumSaver.saveToAlbum(filePath: _imagePreviewPath, albumName: "");
  }

  void deleteImage() {
    File(_imagePreviewPath).delete();
    setState(() {
      state = DfNightSelfiesState.CAMERA_PREVIEW;
    });
  }

  Future shareImage() async {
    var fileBaseName = basename(_imagePreviewPath);
    return Share.file(fileBaseName, fileBaseName,
        File(_imagePreviewPath).readAsBytesSync(), 'image/png');
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
}
