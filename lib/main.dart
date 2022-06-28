import 'package:flutter/material.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

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
                        create: (context) => FramesModel(),
                        child: Consumer<FramesModel>(
                          builder: (context, frames, child) => Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Flexible(
                                  child: Stack(
                                children: [
                                  _image as Widget,
                                  ...[
                                    for (final frame in frames.frames)
                                      Positioned.fill(
                                        child: FrameWidget(frame: frame),
                                      )
                                  ],
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
                                          onPressed: () {},
                                        ),
                                        IconButton(
                                          splashRadius: 25,
                                          tooltip:
                                              "Show the flexible frames for editing",
                                          icon: Icon(frames.showingLines
                                              ? Icons.visibility_outlined
                                              : Icons.visibility_off),
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
