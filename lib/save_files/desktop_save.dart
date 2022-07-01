import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:file_picker/file_picker.dart';

String ensureEndsWith(String path, String end) =>
    [path, if (!path.endsWith(end)) end].join("");

void saveImage(Image image) async {
  final path = await FilePicker.platform.saveFile(
      dialogTitle: "Save Image",
      type: FileType.custom,
      allowedExtensions: ["png"]);
  if (path != null) {
    final bytes = (await image.toByteData(format: ImageByteFormat.png))
        ?.buffer
        .asUint8List();
    if (bytes == null) {
      throw const FormatException("Could not write result image to bytes");
    }
    await File(ensureEndsWith(path, '.png')).writeAsBytes(bytes, flush: true);
  }
}

void saveJSON(Map<String, dynamic> json) async {
  final path = await FilePicker.platform.saveFile(
      dialogTitle: "Save JSON",
      type: FileType.custom,
      allowedExtensions: ["json"]);
  if (path != null) {
    await File(ensureEndsWith(path, '.json'))
        .writeAsString(jsonEncode(json), flush: true);
  }
}
