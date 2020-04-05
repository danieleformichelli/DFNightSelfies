import 'dart:async';
import 'dart:io';

import 'package:esys_flutter_share/esys_flutter_share.dart';
import 'package:gallery_saver/gallery_saver.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' show join;
import 'package:path/path.dart' show basename;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class ExportManager {
  String temporaryFile;
  bool _isPhotoMode;

  void reset() {
    temporaryFile = null;
  }

  Future<String> getTemporaryFile(bool isPhotoMode) async {
    if (isPhotoMode) {
      temporaryFile = join(
        (await getTemporaryDirectory()).path,
        'DFNightSelfies_${getDateTime()}.png',
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
    PermissionStatus permissionStatus;
    if (Platform.isAndroid) {
      permissionStatus = await Permission.storage.request();
    } else {
      permissionStatus = await Permission.photos.request();
    }
    if (!permissionStatus.isGranted) {
      openAppSettings();
      return;
    }

    if (_isPhotoMode) {
      GallerySaver.saveImage(temporaryFile);
    } else {
      GallerySaver.saveVideo(temporaryFile);
    }
  }

  Future shareMedia() async {
    var fileBaseName = basename(temporaryFile);
    return Share.file(fileBaseName, fileBaseName, imageBytes(), _isPhotoMode ? 'image/png' : 'video/mp4');
  }

  List<int> imageBytes() {
    return new File(temporaryFile).readAsBytesSync();
  }

  void deleteTemporaryFile() {
    File(temporaryFile).delete();
    temporaryFile = null;
  }
}
