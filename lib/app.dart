import 'dart:io';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';

import 'models.dart';
import 'widgets.dart';
import 'save_files/web_save.dart'
    if (dart.library.io) "save_files/desktop_save.dart";

void saveResult(List<FrameModel> frames, ImageProvider provider) {
  provider.resolve(const ImageConfiguration()).addListener(
      ImageStreamListener((ImageInfo imageInfo, bool synchronousCall) async {
    final image = imageInfo.image;
    final recorder = PictureRecorder();
    Canvas c = Canvas(recorder);
    // bizarrely, FilterQuality.high sometimes has much worse image quality
    c.drawImage(
        image, Offset.zero, Paint()..filterQuality = FilterQuality.medium);
    FramePainter(frames, false, 1)
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

/// App entry point
class FramesPage extends StatelessWidget {
  final FrameCollection? initialScene;
  const FramesPage({super.key, this.initialScene});

  @override
  Widget build(BuildContext context) {
    final body = Consumer<FrameCollection>(
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
            title: const Text("Mitch's Perspective Transformer"),
          ),
          body: Column(
            children: [
              if (frames.backgroundImage != null)
                Container(
                  margin: const EdgeInsets.all(8.0),
                  child: const Text(
                      "Zoom around the image and tap and drag frames and their "
                      "points to gain a Sense of Perspective"),
                ),
              const Flexible(
                child: FramesScene(),
              ),
            ],
          ),
        ),
      ),
    );

    Widget shell(Widget body) => MaterialApp(
        title: 'Perspective',
        theme: ThemeData(
          primarySwatch: Colors.blue,
        ),
        home: body);

    if (initialScene != null) {
      return ChangeNotifierProvider.value(
          value: initialScene, child: shell(body));
    } else {
      return ChangeNotifierProvider(
          create: (context) => FrameCollection(), child: shell(body));
    }
  }
}

/// App primary content
class FramesScene extends StatelessWidget {
  const FramesScene({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final frames = Provider.of<FrameCollection>(context);
    return Center(
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
                          transformationController: frames.viewerController,
                          onInteractionUpdate: (ScaleUpdateDetails d) =>
                              frames.updateScale(),
                          maxScale: 5,
                          child: Stack(
                            children: [
                              frames.backgroundImage as Widget,
                              if (frames.mainImageLoaded)
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
    );
  }
}

/// Control bar for primary content
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
                tooltip: "Load frames from a JSON file",
                icon: const Icon(Icons.folder_outlined),
                onPressed: () async {
                  FilePickerResult? result = await FilePicker.platform
                      .pickFiles(
                          type: FileType.custom,
                          allowedExtensions: ["json"],
                          withData: true);
                  if (result != null && result.files.isNotEmpty) {
                    final text =
                        utf8.decode(result.files.first.bytes!.toList());
                    final data = jsonDecode(text);
                    final frames = [
                      for (final frameData in data["frames"])
                        FrameModel(
                            (frameData["worldPlanePoints"] as List)
                                .map((e) => Offset(e[0], e[1]))
                                .toList(),
                            null,
                            frameData['name'])
                    ];
                    for (final frame in frames) {
                      state.addFrame(frame);
                    }
                  }
                },
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
