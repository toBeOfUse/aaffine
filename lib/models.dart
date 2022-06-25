import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'radiant_vector.dart';

/// Exits to be contained in [FrameModel].
class PointModel {
  Offset loc;
  static int idStream = 0;
  final int id;
  PointModel(this.loc) : id = idStream++;
}

/// Describes a convex quadrilateral with points that can be manipulated via the
/// [drag] method and an possibly an [image] it wants to display.
class FrameModel {
  late final List<PointModel> _points;
  Image? image;
  FrameModel(List<Offset> points) : assert(points.length == 4) {
    _points = sortPointsCW([for (final p in points) PointModel(p)]);
  }

  /// Creates a very boring default frame.
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

  /// Sort the points in clockwise winding order so lines can be drawn between
  /// them in order to reliably form a square and not like, disconnected crossed
  /// line segments.
  List<PointModel> sortPointsCW(List<PointModel> points) {
    final sum = [for (final p in points) p.loc].reduce((o1, o2) => o1 + o2);
    final average = sum / 4;
    final cwPoints = [...points]..sort((o1, o2) =>
        (o1.loc - average).direction.compareTo((o2.loc - average).direction));
    return cwPoints;
  }

  int getPointIndex(int pointID) => points.indexWhere((p) => p.id == pointID);

  /// Attempts to move the point to [aimTowards] while avoiding making the frame
  /// a concave shape. This took a lot more math than expected...
  void drag(int pointID, Offset aimTowards) {
    final pointIndex = getPointIndex(pointID);
    Offset opposite = points[(pointIndex + 2) % 4].loc;
    Offset next = points[(pointIndex + 1) % 4].loc;
    Offset prev = points[(pointIndex + 3) % 4].loc;
    // do not go to the left of this one
    final oppositeForward =
        RadiantVector(opposite, prev, true).translate(prev - opposite);
    // or the right of this one
    final oppositeBackward =
        RadiantVector(opposite, next, true).translate(next - opposite);
    // or the left of this one.
    final crossMember = RadiantVector(next, prev, false);
    if (oppositeForward.onSideOf(aimTowards) == LineSide.left ||
        oppositeBackward.onSideOf(aimTowards) == LineSide.right ||
        crossMember.onSideOf(aimTowards) == LineSide.left) {
      if (kDebugMode) {
        log("mouse entering illegal zone D:<");
        log("mouse at: $aimTowards");
        log("opposite forward: $oppositeForward");
        log("side thereof: ${oppositeForward.onSideOf(aimTowards)}");
        log("opposite backward: $oppositeBackward");
        log("side thereof: ${oppositeBackward.onSideOf(aimTowards)}");
        log("cross member: $crossMember");
        log("side thereof: ${crossMember.onSideOf(aimTowards)}");
      }

      // good lord
      final closestPoints = [
        ...[oppositeForward, oppositeBackward, crossMember]
            .map((e) => e.closestPointOn(aimTowards))
      ]..sort((p1, p2) => (p1 - aimTowards)
          .distanceSquared
          .compareTo((p2 - aimTowards).distanceSquared));
      points[pointIndex].loc = closestPoints[0];
    } else {
      points[pointIndex].loc = aimTowards;
    }
  }
}

class FramesModel extends ChangeNotifier {
  final List<FrameModel> frames;
  final Map<int, FrameModel> _pointIndex = {};

  /// Used to identify the [CustomPaint] widget whose local coordinate system we
  /// need to use in both drawing and mouse positioning
  final GlobalKey paintKey = GlobalKey(debugLabel: "The painty boy");

  FramesModel() : frames = [FrameModel.square()] {
    for (final frame in frames) {
      for (final point in frame.points) {
        _pointIndex[point.id] = frame;
      }
    }
  }

  void drag(int pointID, Offset position) {
    final frame = _pointIndex[pointID];
    if (frame != null) {
      frame.drag(pointID, position);
      notifyListeners();
    }
  }

  /// This is a bit meaningless absent the context of the [FrameModel] but is
  /// useful for debug output
  int getPointIndex(int pointID) {
    final frame = _pointIndex[pointID];
    if (frame == null) {
      return -1;
    } else {
      return frame.getPointIndex(pointID);
    }
  }
}
