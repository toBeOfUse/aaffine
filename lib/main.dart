import 'save_files/web_save.dart'
    if (dart.library.io) "save_files/desktop_save.dart";

import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart';

import 'models.dart';
import 'widgets.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const FramesPage(title: 'Perspective'),
    );
  }
}

void saveResult(List<FrameModel> frames, ImageProvider provider) {
  provider.resolve(const ImageConfiguration()).addListener(
      ImageStreamListener((ImageInfo imageInfo, bool synchronousCall) async {
    final image = imageInfo.image;
    final recorder = PictureRecorder();
    Canvas c = Canvas(recorder);
    c.drawImage(
        image, Offset.zero, Paint()..filterQuality = FilterQuality.high);
    FramePainter(frames, false, FilterQuality.high)
        .paint(c, Size(image.width.toDouble(), image.height.toDouble()));
    final result =
        await recorder.endRecording().toImage(image.width, image.height);
    if (kIsWeb ||
        (Platform.isLinux || Platform.isMacOS || Platform.isWindows)) {
      saveImage(result);
    } else {
      throw UnimplementedError("Not portable to mobile phones yet. Sorry 🥺");
    }
  }));
}

class ControlRow extends StatelessWidget {
  const ControlRow({super.key});
  @override
  Widget build(BuildContext context) {
    final state = Provider.of<FrameCollection>(context);
    return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        mainAxisSize: MainAxisSize.max,
        children: [
          Flexible(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 400),
              child: TextField(
                controller: state.nameField,
                cursorColor: Colors.black,
                decoration: const InputDecoration(
                    focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey)),
                    labelStyle: TextStyle(color: Colors.black),
                    labelText: "Project Name"),
              ),
            ),
          ),
          Container(
            color: Colors.black12,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            margin: const EdgeInsets.symmetric(vertical: 5),
            child: Row(children: [
              IconButton(
                splashRadius: 25,
                tooltip: "Close the current project",
                icon: const Icon(Icons.close_outlined),
                onPressed: () => state.clearMainImage(),
              ),
              IconButton(
                splashRadius: 25,
                tooltip:
                    "Generate a JSON file describing the active transformations",
                icon: const Icon(Icons.code_outlined),
                onPressed: () {
                  saveJSON(state.toJSON());
                },
              ),
              IconButton(
                splashRadius: 25,
                tooltip: "Save the image we've created",
                icon: const Icon(Icons.save_outlined),
                onPressed: () {
                  final image = state.backgroundImage;
                  if (image != null) saveResult(state.frames, image.image);
                },
              ),
              IconButton(
                splashRadius: 25,
                tooltip: "Show/hide the flexible frames for editing",
                icon: Icon(state.showingLines
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined),
                onPressed: () => state.toggleLines(),
              ),
              IconButton(
                splashRadius: 25,
                tooltip: "Add a new frame",
                icon: const Icon(Icons.add),
                onPressed: () => state.addFrame(),
              )
            ]),
          )
        ]);
  }
}

/// Page that displays flexible frames that can hold images.
class FramesPage extends StatelessWidget {
  const FramesPage({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => FrameCollection(),
      child: Consumer<FrameCollection>(
        builder: (context, frames, child) => Focus(
          onKeyEvent: (FocusNode f, KeyEvent k) {
            if (k.logicalKey == LogicalKeyboardKey.escape) {
              frames.clearMainImage();
              return KeyEventResult.handled;
            } else {
              return KeyEventResult.ignored;
            }
          },
          child: Scaffold(
            appBar: AppBar(
              title: Text(title),
            ),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: DottedBorder(
                  padding: const EdgeInsets.all(8.0),
                  dashPattern: const [5],
                  child: frames.backgroundImage == null
                      ? TextButton(
                          onPressed: () async {
                            final image = await getImageWidget();
                            if (image != null) {
                              frames.setMainImage(image);
                            }
                          },
                          child: const Text("Open Image"),
                        )
                      : IntrinsicWidth(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: InteractiveViewer(
                                  transformationController:
                                      frames.viewerController,
                                  onInteractionUpdate: (ScaleUpdateDetails d) =>
                                      frames.updateScale(),
                                  maxScale: 5,
                                  child: Stack(
                                    children: [
                                      frames.backgroundImage as Widget,
                                      const Positioned.fill(
                                        child: FrameLayer(),
                                      )
                                    ],
                                  ),
                                ),
                              ),
                              const ControlRow(),
                            ],
                          ),
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
