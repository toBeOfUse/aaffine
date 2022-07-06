import 'dart:convert';

import 'package:aaffine/app.dart';
import 'package:aaffine/models.dart';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

// why isn't there a simple ui.imageFromBytes function...
Future<DecodedImage> imageFromBytes(ByteData bytes) async {
  return (await (await ui.instantiateImageCodec(bytes.buffer.asUint8List()))
          .getNextFrame())
      .image;
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  rootBundle.loadString("assets/timessquare.json").then((demoData) async {
    final demo = FrameCollection.prefab(
        [
          for (final frameData in jsonDecode(demoData)["frames"])
            FrameModel(
                (frameData["worldPlanePoints"] as List)
                    .map((e) => Offset(e[0], e[1]))
                    .toList(),
                await imageFromBytes(
                    await rootBundle.load("assets/${frameData['name']}")),
                frameData['name']),
        ],
        (await getImageWidget((await rootBundle
                .load("assets/andre-benz-_T35CPjjSik-unsplash.jpg"))
            .buffer
            .asUint8List()))!);
    runApp(MyApp(initialScene: demo));
  });
}
