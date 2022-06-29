import 'dart:typed_data';
import 'dart:io';
import 'dart:ui';

import 'package:file_picker/file_picker.dart';

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
    File(path).writeAsBytes(bytes, flush: true);
  }
}
