import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class Store {
  static Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  static Future<String?> readFile(String filename) async {
    final path = await _localPath;
    final file = File('$path/$filename');
    final bool exists = await file.exists();
    if (!exists) {
      return null;
    } else {
      return await file.readAsString();
    }
  }

  static Future<File> writeFile(String filename, String contents) async {
    final path = await _localPath;
    final file = File('$path/$filename');
    return file.writeAsString('$contents');
  }

  static Future deleteFile(String filename) async {
    final path = await _localPath;
    final file = File('$path/$filename');
    final bool exists = await file.exists();
    if (exists) {
      await file.delete();
    }
  }
}
