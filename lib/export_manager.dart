import 'dart:async';
import 'dart:io';

import 'package:esys_flutter_share/esys_flutter_share.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' show join;
import 'package:path/path.dart' show basename;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:gallery_saver/gallery_saver.dart';
import 'package:flutter_photokit/flutter_photokit.dart';

class ExportManager {
  String temporaryFile;
  bool _isPhotoMode;

  void reset() {
    temporaryFile = null;
  }

  Future<String> getTemporaryFile(bool isPhotoMode) async {
    if (isPhotoMode) {
      temporaryFile = join(
        (await getTemporaryDirectory()).path,'DFNightSelfies_${getDateTime()}.png',
      );
    } else {
      temporaryFile = join(
        (await getTemporaryDirectory()).path,
        'DFNightSelfies_${getDateTime()}.mp4',
      );
    }

    _isPhotoMode = isPhotoMode;
    return temporaryFile;
  }

  getDateTime() => DateFormat('yyyyMMddHHmmss').format(DateTime.now());

  Future saveMedia() async {
    if (Platform.isAndroid) {
      var permission = await PermissionHandler()
          .requestPermissions([PermissionGroup.storage]);
      if (permission[PermissionGroup.storage] != PermissionStatus.granted) {
        return Future.error('Write storage permission not granted');
      }

      if (_isPhotoMode) {
        GallerySaver.saveImage(temporaryFile);
      } else {
        GallerySaver.saveVideo(temporaryFile);
      }
    } else {
      var permission = await PermissionHandler()
          .requestPermissions([PermissionGroup.photos]);
      if (permission[PermissionGroup.photos] != PermissionStatus.granted) {
        return Future.error('Photo permission not granted');
      }

      FlutterPhotokit.saveToCameraRoll(filePath: temporaryFile);
    }
  }

  Future shareMedia() async {
    var fileBaseName = basename(temporaryFile);
    return Share.file(fileBaseName, fileBaseName, imageBytes(),
        _isPhotoMode ? 'image/png' : 'video/mp4');
  }

  List<int> imageBytes() {
    return new File(temporaryFile).readAsBytesSync();
  }

  void deleteTemporaryFile() {
    File(temporaryFile).delete();
    temporaryFile = null;
  }
}
