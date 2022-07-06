import 'dart:convert';

import 'package:aaffine/app.dart';
import 'package:aaffine/models.dart';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

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
                // why isn't there a simple ui.imageFromBytes function...
                (await (await ui.instantiateImageCodec((await rootBundle
                                .load("assets/${frameData['name']}"))
                            .buffer
                            .asUint8List()))
                        .getNextFrame())
                    .image,
                frameData['name']),
        ],
        Image.asset(
          "assets/andre-benz-_T35CPjjSik-unsplash.jpg",
          filterQuality: FilterQuality.medium,
        ));
    runApp(MyApp(initialScene: demo));
  });
}
