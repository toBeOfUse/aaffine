import 'dart:developer';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:ml_linalg/linalg.dart';
import 'package:vector_math/vector_math_64.dart' as vec;
import 'radiant_vector.dart';

/// Used with Canvas.drawImage()
typedef DecodedImage = ui.Image;
typedef ImageWidget = Image;

/// Exits to be contained in [FrameModel].
class PointModel {
  Offset loc;
  static int idStream = 0;
  final int id;
  PointModel(this.loc) : id = idStream++;
}

/// Describes a convex quadrilateral with points that can be manipulated via the
/// [drag] method and an possibly an [image] it wants to display. The points'
/// coordinates are normalized, meaning they exist in the range [0, 1] and must
/// be scaled horizontally and vertically by the width and height of the
/// background image to get world-space pixel coordinates. This is so that
/// resizing the window/image will not dislodge the points
class FrameModel {
  final List<PointModel> _points;
  DecodedImage? image;

  /// Creates a very boring default frame. Points are clockwise with the top
  /// left first; N.B. all future constructors should follow this convention!!
  FrameModel.square(
      {Offset pos = const Offset(0.1, 0.1), double sideLength = 0.2})
      : _points = [
          pos,
          Offset(pos.dx + sideLength, pos.dy),
          Offset(pos.dx + sideLength, pos.dy + sideLength),
          Offset(pos.dx, pos.dy + sideLength),
        ].map((e) => PointModel(e)).toList();

  List<PointModel> get points {
    return _points;
  }

  /// Outputs a matrix that will take an image from "object space" (the
  /// pixel-based coordinate system where the top left of the image is at (0,0)
  /// and the bottom left corner is at (frame.image.width, frame.image.height))
  /// into "world space" (the coordinate system where the top left of the image
  /// is at the first point in _points and so on around the points/corners,
  /// clockwise) and then into "screen space" (same as before except all the
  /// points/corners are located at the pixel coordinates of where the points
  /// are actually located on the canvas we're going to draw on.) main ref:
  /// https://web.archive.org/web/20150222120106/xenia.media.mit.edu/~cwren/interpolator/
  ///
  /// Returns: null if this.image is null; a [Matrix4] otherwise.
  Matrix4? makeImageFit(double screenSpaceWidth, double screenSpaceHeight) {
    final width = image?.width.toDouble();
    final height = image?.height.toDouble();
    if (width != null && height != null && !width.isNaN && !height.isNaN) {
      /// top left first, like the output of [FrameModel.square]
      final objectSpaceCoords = [
        const Offset(0, 0),
        Offset(width, 0),
        Offset(width, height),
        Offset(0, height),
      ];
      final worldSpaceCoords = [
        for (final p in points) Offset(p.loc.dx, p.loc.dy)
      ];
      final imageSpaceDef = <List<double>>[];
      for (var i = 0; i < 4; i++) {
        final objectPoint = objectSpaceCoords[i];
        final worldPoint = worldSpaceCoords[i];
        imageSpaceDef.addAll([
          [
            objectPoint.dx,
            objectPoint.dy,
            1,
            0,
            0,
            0,
            -worldPoint.dx * objectPoint.dx,
            -worldPoint.dx * objectPoint.dy
          ],
          [
            0,
            0,
            0,
            objectPoint.dx,
            objectPoint.dy,
            1,
            -worldPoint.dy * objectPoint.dx,
            -worldPoint.dy * objectPoint.dy
          ]
        ]);
      }
      final imageSpaceDefMatrix = Matrix.fromList(imageSpaceDef);
      final worldColumnVector = Matrix.column([
        for (final point in worldSpaceCoords) ...[point.dx, point.dy]
      ]);
      final transform =
          (((imageSpaceDefMatrix.transpose() * imageSpaceDefMatrix).inverse() *
                  imageSpaceDefMatrix.transpose()) *
              worldColumnVector);
      final transformData = [
        ...[for (final row in transform.rows) ...row],
        1.0
      ];
      final mat4 = Matrix4.identity();
      for (var i = 0; i < 9; i++) {
        var row = i ~/ 3;
        var col = i % 3;
        if (row == 2) {
          row = 3;
        }
        if (col == 2) {
          col = 3;
        }
        mat4.setEntry(row, col, transformData[i]);
      }
      if (kDebugMode) {
        for (var i = 0; i < 4; i++) {
          final point = objectSpaceCoords[i];
          final wSpaceTest = [worldSpaceCoords[i].dx, worldSpaceCoords[i].dy];
          final testResult = mat4 * vec.Vector4(point.dx, point.dy, 0, 1);
          final divW = [
            testResult[0] / testResult[3],
            testResult[1] / testResult[3]
          ];
          if ((wSpaceTest[0] - divW[0]).abs() > 0.001 ||
              (wSpaceTest[1] - divW[1]).abs() > 0.001) {
            log("alert: things wrong");
            log("object space coords: ${[point.dx, point.dy]}");
            log("actual world space coords: $wSpaceTest");
            log("coords we got: $divW");
          }
        }
      }
      final scale = Matrix4.diagonal3(
          vec.Vector3(screenSpaceWidth, screenSpaceHeight, 1));
      return scale * mat4;
    } else {
      return null;
    }
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
    final result = points[pointIndex].loc;
    double bounds(double a) => math.min(1, math.max(0, a));
    points[pointIndex].loc = Offset(bounds(result.dx), bounds(result.dy));
  }
}

class FramesModel extends ChangeNotifier {
  final List<FrameModel> frames;
  final Map<int, FrameModel> _pointIndex = {};

  /// Used to identify the [CustomPaint] widget whose local coordinate system we
  /// need to use in both drawing and mouse positioning
  final GlobalKey paintKey = GlobalKey(debugLabel: "The painty boy");
  RenderBox? get paintBox =>
      paintKey.currentContext?.findRenderObject() as RenderBox?;

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

  void addImage(FrameModel frame, DecodedImage image) {
    if (frames.contains(frame)) {
      frame.image = image;
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
