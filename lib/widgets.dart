import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'models.dart';

/// Draws a little circle to represent a [PointModel]; detects pointer events
/// that want to move it and gets [FramesModel] to update the state based on
/// them.
class PointWidget extends StatelessWidget {
  final int pointID;
  static const int radius = 5;
  const PointWidget({super.key, required this.pointID});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanUpdate: (details) {
        final state = Provider.of<FramesModel>(context, listen: false);
        Offset? position =
            (state.paintKey.currentContext?.findRenderObject() as RenderBox?)
                ?.globalToLocal(details.globalPosition);
        if (position != null) {
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
        child: Stack(
          children: [
            for (final p in frame.points) ...[
              Positioned(
                  left: p.loc.dx - PointWidget.radius,
                  top: p.loc.dy - PointWidget.radius,
                  child: PointWidget(pointID: p.id)),
              if (kDebugMode)
                Positioned(
                    left: p.loc.dx,
                    top: p.loc.dy,
                    child: Text(state.getPointIndex(p.id).toString()))
            ]
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
