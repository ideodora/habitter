import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:oauth1/oauth1.dart' as oauth1;
import 'package:path_provider/path_provider.dart';

class CounterStorage {
  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();

    return directory.path;
  }

  Future<File> get _localFile async {
    final path = await _localPath;
    return File('$path/token.json');
  }

  Future<oauth1.Credentials?> readToken() async {
    try {
      final file = await _localFile;

      // Read the file
      final contents = await file.readAsString();
      var obj = json.decode(contents);
      return oauth1.Credentials(
          obj['oauth_token']!, obj['oauth_token_secret']!);
    } catch (e) {
      // If enTokening an error, return 0
      return null;
    }
  }

  Future<File> writeToken(oauth1.Credentials? credentials) async {
    final file = await _localFile;

    if (credentials == null) {
      return file;
    }

    // Write the file
    return file.writeAsString(json.encode(credentials.toJSON()));
  }
}
