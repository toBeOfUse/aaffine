import 'save_image/web_save.dart'
    if (dart.library.io) "save_image/desktop_save.dart";

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

/// Page that displays flexible frames that can hold images.
class FramesPage extends StatefulWidget {
  const FramesPage({super.key, required this.title});

  final String title;

  @override
  State<FramesPage> createState() => _FramesPageState();
}

class _FramesPageState extends State<FramesPage> {
  ImageWidget? _image;

  void openImage() async {
    final image = await getImageWidget();
    if (image != null) {
      setState(() {
        _image = image;
      });
    }
  }

  void saveResult(List<FrameModel> frames) {
    final provider = _image?.image;
    if (provider == null) {
      return;
    }
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

  @override
  Widget build(BuildContext context) {
    return Focus(
        onKeyEvent: (FocusNode f, KeyEvent k) {
          if (k.logicalKey == LogicalKeyboardKey.escape) {
            setState(() {
              _image = null;
            });
            return KeyEventResult.handled;
          } else {
            return KeyEventResult.ignored;
          }
        },
        child: Scaffold(
          appBar: AppBar(
            title: Text(widget.title),
          ),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: DottedBorder(
                padding: const EdgeInsets.all(8.0),
                dashPattern: const [5],
                child: _image == null
                    ? TextButton(
                        onPressed: openImage,
                        child: const Text("Open Image"),
                      )
                    : ChangeNotifierProvider(
                        create: (context) => FrameCollection(),
                        child: Consumer<FrameCollection>(
                          builder: (context, frames, child) => Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Flexible(
                                  child: Stack(
                                children: [
                                  _image as Widget,
                                  const Positioned.fill(
                                    child: FrameLayer(),
                                  )
                                ],
                              )),
                              Container(
                                  color: Colors.black12,
                                  padding:
                                      const EdgeInsets.fromLTRB(8, 0, 8, 0),
                                  margin: const EdgeInsets.fromLTRB(0, 5, 0, 0),
                                  child: Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          splashRadius: 25,
                                          tooltip:
                                              "Save the image we've created",
                                          icon: const Icon(Icons.save_outlined),
                                          onPressed: () =>
                                              saveResult(frames.frames),
                                        ),
                                        IconButton(
                                          splashRadius: 25,
                                          tooltip:
                                              "Show the flexible frames for editing",
                                          icon: Icon(frames.showingLines
                                              ? Icons.visibility_outlined
                                              : Icons.visibility_off_outlined),
                                          onPressed: () => frames.toggleLines(),
                                        ),
                                        IconButton(
                                          splashRadius: 25,
                                          tooltip: "Add a new frame",
                                          icon: const Icon(Icons.add),
                                          onPressed: () => frames.addFrame(),
                                        ),
                                      ]))
                            ],
                          ),
                        ),
                      ),
              ),
            ),
          ),
        ));
  }
}
