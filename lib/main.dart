import 'dart:developer';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

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
      home: const FramesPage(title: '3D Frames'),
    );
  }
}

class FramesPage extends StatefulWidget {
  const FramesPage({super.key, required this.title});

  final String title;

  @override
  State<FramesPage> createState() => _FramesPageState();
}

class PointModel {
  Offset loc;
  static int idStream = 0;
  final int id;
  PointModel(this.loc) : id = idStream++;
}

class FrameModel {
  late final List<PointModel> _points;
  FrameModel(List<Offset> points) : assert(points.length == 4) {
    _points = sortPointsCW([for (final p in points) PointModel(p)]);
  }
  factory FrameModel.square(
      {Offset pos = const Offset(20, 20), int sideLength = 100}) {
    return FrameModel([
      pos,
      Offset(pos.dx, pos.dy + sideLength),
      Offset(pos.dx + sideLength, pos.dy),
      Offset(pos.dx + sideLength, pos.dy + sideLength)
    ]);
  }

  List<PointModel> get points {
    return _points;
  }

  /// Access the points in clockwise winding order so lines can be drawn
  /// between them in order to form a square and not like, disconnected crossed
  /// line segments.
  List<PointModel> sortPointsCW(List<PointModel> points) {
    final sum = [for (final p in points) p.loc].reduce((o1, o2) => o1 + o2);
    final average = sum / 4;
    final cwPoints = [...points]..sort((o1, o2) =>
        (o1.loc - average).direction.compareTo((o2.loc - average).direction));
    return cwPoints;
  }

  void drag(int pointID, Offset change) {
    final pointIndex = points.indexWhere((p) => p.id == pointID);
    if (pointIndex == -1) {
      log("attempt to drag nonexistent point with id ${pointID.toString()}",
          level: 1000);
      return;
    }
    final point = points[pointIndex];
    // final dividingLine = [
    //   points[(pointIndex + 1) % 4],
    //   points[(pointIndex + 3) % 4]
    // ];
    point.loc += change;
    point.loc = Offset(math.max(0, point.loc.dx), math.max(0, point.loc.dy));
  }
}

class FramesModel extends ChangeNotifier {
  final List<FrameModel> frames;
  final Map<int, FrameModel> _pointIndex = {};

  FramesModel() : frames = [FrameModel.square()] {
    for (final frame in frames) {
      for (final point in frame.points) {
        _pointIndex[point.id] = frame;
      }
    }
  }

  void drag(int pointID, Offset change) {
    _pointIndex[pointID]?.drag(pointID, change);
    notifyListeners();
  }
}

class PointWidget extends StatelessWidget {
  final int pointID;
  static const int radius = 5;
  const PointWidget({super.key, required this.pointID});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanUpdate: (details) {
        Provider.of<FramesModel>(context, listen: false)
            .drag(pointID, details.delta);
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          width: radius * 2,
          height: radius * 2,
          decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.black),
              shape: BoxShape.circle),
        ),
      ),
    );
  }
}

class FrameWidget extends StatelessWidget {
  final FrameModel frame;
  const FrameWidget({Key? key, required this.frame}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
        painter: FramePainter(frame),
        child: Stack(
          children: [
            for (final p in frame.points)
              Positioned(
                  left: p.loc.dx - PointWidget.radius,
                  top: p.loc.dy - PointWidget.radius,
                  child: PointWidget(pointID: p.id))
          ],
        ));
  }
}

class FramePainter extends CustomPainter {
  final style = Paint()..color = Colors.black;
  final FrameModel frame;
  FramePainter(this.frame);
  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < 4; i++) {
      canvas.drawLine(
          frame.points[i].loc, frame.points[(i + 1) % 4].loc, style);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}

class _FramesPageState extends State<FramesPage> {
  Image? _image;

  void getImage() async {
    FilePickerResult? result =
        await FilePicker.platform.pickFiles(type: FileType.image);
    if (result != null && result.count > 0) {
      String? path = result.files.first.path;
      if (path != null) {
        setState(() {
          _image = Image.file(File(path), filterQuality: FilterQuality.medium);
        });
      }
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
                        onPressed: getImage,
                        child: const Text("Open Image"),
                      )
                    : ChangeNotifierProvider(
                        create: (context) => FramesModel(),
                        child: Consumer<FramesModel>(
                            builder: (context, frames, child) =>
                                Stack(children: [
                                  _image as Widget,
                                  ...[
                                    for (final frame in frames.frames)
                                      Positioned.fill(
                                        child: FrameWidget(frame: frame),
                                      )
                                  ],
                                ]))),
              )),
        ),
      ),
    );
  }
}
