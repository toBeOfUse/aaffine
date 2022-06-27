import 'dart:developer';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'models.dart';

Future<Image?> getImage() async {
  FilePickerResult? result =
      await FilePicker.platform.pickFiles(type: FileType.image);
  if (result != null && result.count > 0) {
    String? path = result.files.first.path;
    log("got image path: $path");
    if (path != null) {
      return Image.file(File(path), filterQuality: FilterQuality.medium);
    }
  }
  return null;
}

/// Draws a little circle to represent a [PointModel]; detects pointer events
/// that want to move it and gets [FramesModel] to update the state based on
/// them.
class PointWidget extends StatelessWidget {
  final int pointID;
  static const double radius = 5;
  const PointWidget({super.key, required this.pointID});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanUpdate: (details) {
        final state = Provider.of<FramesModel>(context, listen: false);
        final box = state.paintBox;
        if (box != null) {
          Offset position = box.globalToLocal(details.globalPosition);
          position = Offset(
              position.dx / box.size.width, position.dy / box.size.height);
          state.drag(pointID, position);
        }
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

/// Draws a [FrameModel] using a [FramePainter] and [PointWidget]s. And some
/// [Text] when in debug mode
class FrameWidget extends StatelessWidget {
  final FrameModel frame;
  const FrameWidget({Key? key, required this.frame}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<FramesModel>(context, listen: false);
    return CustomPaint(
      key: state.paintKey,
      painter: FramePainter(frame),
      child: LayoutBuilder(
        builder: (context, constraints) {
          log("points: ${[
            for (final p in frame.points) [p.loc.dx, p.loc.dy]
          ]}");
          log("PointWidget radius: ${PointWidget.radius}");
          final xAdjust = PointWidget.radius / constraints.maxWidth;
          log("PointWidget radius as fraction of width: $xAdjust");
          final yAdjust = PointWidget.radius / constraints.maxHeight;
          log("PointWidget radius as fraction of height: $yAdjust");
          final adjusted = [
            for (final p in frame.points)
              Offset(p.loc.dx - xAdjust, p.loc.dy - yAdjust)
          ];
          log("adjusted points: ${[
            for (final p in adjusted) [p.dx, p.dy]
          ]}");
          log("box size: ${Offset(constraints.maxWidth, constraints.maxHeight)}");
          return Stack(
            children: [
              for (var i = 0; i < 4; i++) ...[
                Align(
                    alignment: FractionalOffset(
                        frame.points[i].loc.dx, frame.points[i].loc.dy),
                    child: PointWidget(pointID: frame.points[i].id)),
                if (kDebugMode)
                  Align(
                      alignment: FractionalOffset(
                          adjusted[i].dx,
                          adjusted[i].dy +
                              PointWidget.radius * 2 / constraints.maxHeight),
                      child: Text(
                          state.getPointIndex(frame.points[i].id).toString()))
              ],
              IconButton(
                  onPressed: () async {
                    final image = await getImage();
                    if (image != null) {
                      state.addImage(frame, image);
                    }
                  },
                  icon: const Icon(Icons.folder_outlined))
            ],
          );
        },
      ),
    );
  }
}

class FramePainter extends CustomPainter {
  final style = Paint()..color = Colors.black;
  final FrameModel frame;
  FramePainter(this.frame);
  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < 4; i++) {
      canvas.drawLine(frame.points[i].loc.scale(size.width, size.height),
          frame.points[(i + 1) % 4].loc.scale(size.width, size.height), style);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}
