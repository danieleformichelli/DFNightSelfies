import 'dart:async';
import 'dart:io';

import 'package:gallery_saver/gallery_saver.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';


class ExportManager {
  String temporaryFile;
  bool isPhotoMode;

  void reset() {
    temporaryFile = null;
  }

  void setTemporaryFile(String temporaryFile, bool isPhotoMode) {
    this.temporaryFile = temporaryFile;
    this.isPhotoMode = isPhotoMode;
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

    if (isPhotoMode) {
      GallerySaver.saveImage(temporaryFile);
    } else {
      GallerySaver.saveVideo(temporaryFile);
    }
  }

  Future shareMedia() async {
    Share.shareFiles([temporaryFile]);
  }

  List<int> imageBytes() {
    return new File(temporaryFile).readAsBytesSync();
  }

  void deleteTemporaryFile() {
    File(temporaryFile).delete();
    temporaryFile = null;
  }
}
