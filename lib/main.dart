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

  var state = DfNightSelfiesState.INIT;
  CameraController _cameraController;
  VideoPlayerController _videoPlayerController;
  Future _initializeCameraControllerFuture;
  Image _imagePreview;
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
    return Scaffold(
      body: GestureDetector(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: getCameraPreviewOrMediaPreview(),
              ),
            ),
          ],
        ),
        onTap: () async {
          photoOrVideo ? takePhoto() : startOrStopVideo();
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

  Widget getCameraPreviewOrMediaPreview() {
    if (state == DfNightSelfiesState.MEDIA_PREVIEW) {
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
                  cameraPreviewHeight * _cameraController.value.aspectRatio;
              return RotatedBox(
                quarterTurns: turns,
                child: Container(
                  child: CameraPreview(_cameraController),
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
    if (state == DfNightSelfiesState.MEDIA_PREVIEW) {
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

    AlbumSaver.saveToAlbum(filePath: _mediaPreviewPath, albumName: "");
  }

  void deleteImage() {
    File(_mediaPreviewPath).delete();
    setState(() {
      state = DfNightSelfiesState.CAMERA_PREVIEW;
    });
  }

  Future shareImage() async {
    var fileBaseName = basename(_mediaPreviewPath);
    return Share.file(fileBaseName, fileBaseName,
        File(_mediaPreviewPath).readAsBytesSync(), 'image/png');
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
    _cameraController = CameraController(
      await getFrontCamera(),
      ResolutionPreset.high,
    );

    // Next, you need to initialize the controller. This returns a Future
    await _cameraController.initialize();
    state = DfNightSelfiesState.CAMERA_PREVIEW;
  }

  takePhoto() async {
    if (state != DfNightSelfiesState.CAMERA_PREVIEW) {
      return;
    }

    try {
      state = DfNightSelfiesState.RECORDING;
      await _initializeCameraControllerFuture;

      final imagePath = join(
        (await getTemporaryDirectory()).path,
        'DFNightSelfies_${DateTime.now()}.png',
      );

      await _cameraController.takePicture(imagePath);
      setState(() {
        state = DfNightSelfiesState.MEDIA_PREVIEW;
        _mediaPreviewPath = imagePath;
        _imagePreview = Image.file(File(imagePath));
      });
    } catch (e) {
      state = DfNightSelfiesState.CAMERA_PREVIEW;
      print(e);
    }
  }

  startOrStopVideo() async {
    switch (state) {
      case DfNightSelfiesState.CAMERA_PREVIEW:
        setState(() {
          state = DfNightSelfiesState.RECORDING;
        });

        await _initializeCameraControllerFuture;

        _mediaPreviewPath = join(
          (await getTemporaryDirectory()).path,
          'DFNightSelfies_${DateTime.now()}.mp4',
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
}
