import 'dart:developer';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:ml_linalg/linalg.dart';
import 'package:vector_math/vector_math_64.dart' as vec;
import 'radiant_vector.dart';

/// Used with Canvas.drawImage()
typedef DecodedImage = ui.Image;
typedef ImageWidget = Image;

/// Flutter allows you to store images in several ways: as Uint8Lists, as
/// ui.Images (typedeffed by me to DecodedImage), as StatelessWidget Images
/// (typedeffed by me to ImageWidget); this is because they want me to be
/// confused and unhappy. this weak map associates objects of the aforementioned
/// types with strings as a way to add a "name" field to all of them at once.
final imageNames = Expando<String>();

/// attempts to store a name in [imageNames].
Future<Uint8List?> getImageBytes() async {
  FilePickerResult? result =
      await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
  if (result != null && result.files.isNotEmpty) {
    Uint8List? bytes = result.files.first.bytes;
    if (bytes != null) {
      imageNames[bytes] = result.files.first.name;
      return bytes;
    }
  }
  return null;
}

/// attempts to store a name in [imageNames].
Future<DecodedImage?> getImage() async {
  final bytes = await getImageBytes();
  if (bytes != null) {
    try {
      final ui.Codec codec = await ui.instantiateImageCodec(bytes);
      final image = (await codec.getNextFrame()).image;
      imageNames[image] = imageNames[bytes];
      return image;
    } catch (e) {
      log("could not load image", level: 500);
      log(e.toString());
    }
  }
  return null;
}

/// attempts to store a name in [imageNames].
Future<ImageWidget?> getImageWidget() async {
  final bytes = await getImageBytes();
  if (bytes != null) {
    final result =
        ImageWidget.memory(bytes, filterQuality: FilterQuality.medium,
            frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
      if (wasSynchronouslyLoaded) return child;
      return AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: frame != null
            ? child
            : Container(
                padding: const EdgeInsets.all(40),
                child: const SizedBox(
                  height: 60,
                  width: 60,
                  child: CircularProgressIndicator(strokeWidth: 6),
                ),
              ),
      );
    });
    imageNames[result] = imageNames[bytes];
    return result;
  }
  return null;
}

extension LowerDimensions on Matrix4 {
  vec.Matrix3 toMatrix3() {
    return vec.Matrix3.fromList([
      for (final colIndex in [0, 1, 3]) ...[
        for (final rowIndex in [0, 1, 3]) getRow(rowIndex)[colIndex]
      ]
    ]);
  }

  List<List<double>> toLists() {
    return [
      for (var i = 0; i < 4; i++) [for (var j = 0; j < 4; j++) getRow(i)[j]]
    ];
  }
}

extension HigherDimensions on vec.Matrix3 {
  Matrix4 toMatrix4() {
    return Matrix4.fromList([
      getColumn(0)[0],
      getColumn(0)[1],
      0,
      getColumn(0)[2],
      getColumn(1)[0],
      getColumn(1)[1],
      0,
      getColumn(1)[2],
      0,
      0,
      1,
      0,
      getColumn(2)[0],
      getColumn(2)[1],
      0,
      getColumn(2)[2]
    ]);
  }

  List<List<double>> toLists() {
    return [
      for (var i = 0; i < 3; i++) [for (var j = 0; j < 3; j++) getRow(i)[j]]
    ];
  }
}

extension ToOffset on vec.Vector2 {
  Offset toOffset() {
    return Offset(x, y);
  }
}

extension ToVec2 on Offset {
  vec.Vector2 toVec2() {
    return vec.Vector2(dx, dy);
  }
}

/// Exits to be contained in [FrameModel].
class PointModel {
  Offset loc;
  static int idStream = 0;
  final int id;
  PointModel(this.loc) : id = idStream++;
}

/// Describes a convex quadrilateral with points that can be manipulated via the
/// [dragPoint] method and an possibly an [image] it wants to display. The points'
/// coordinates are normalized, meaning they exist in the range [0, 1] and must
/// be scaled horizontally and vertically by the width and height of the
/// background image to get world-space pixel coordinates. This is so that
/// resizing the window/image will not dislodge the points
class FrameModel {
  final List<PointModel> _points;
  static int frameCount = 0;
  int id;
  DecodedImage? image;
  TextEditingController nameField;

  /// Creates a very boring default frame. Points are clockwise with the top
  /// left first; N.B. all future constructors should follow this convention!!
  FrameModel.square(
      {Offset pos = const Offset(0.1, 0.1), double sideLength = 0.2})
      : id = frameCount,
        nameField = TextEditingController(text: "PerspectiveFrame$frameCount"),
        _points = [
          pos,
          Offset(pos.dx + sideLength, pos.dy),
          Offset(pos.dx + sideLength, pos.dy + sideLength),
          Offset(pos.dx, pos.dy + sideLength),
        ].map((e) => PointModel(e)).toList() {
    frameCount++;
  }
  factory FrameModel.overlapAvoidingSquare() {
    return FrameModel.square(
        pos: Offset(0.1 + 0.05 * frameCount, 0.1 + 0.05 * frameCount));
  }

  Map<String, dynamic>? toJSON() {
    final matrix = makeImageFit(1, 1);
    return {
      if (matrix != null) "4x4matrix": matrix.toLists(),
      if (matrix != null) "3x3matrix": matrix.toMatrix3().toLists(),
      if (objectSpaceCoords != null)
        "imagePlanePoints":
            objectSpaceCoords!.map((e) => [e.dx, e.dy]).toList(),
      "worldPlanePoints": _points.map((p) => [p.loc.dx, p.loc.dy]).toList(),
      "name": nameField.text
    };
  }

  List<PointModel> get points {
    return _points;
  }

  /// top left first, like the output of [FrameModel.square]
  List<Offset>? get objectSpaceCoords => image == null
      ? null
      : [
          const Offset(0, 0),
          Offset(image!.width.toDouble(), 0),
          Offset(image!.width.toDouble(), image!.height.toDouble()),
          Offset(0, image!.height.toDouble()),
        ];

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
    final objectSpaceCoords = this.objectSpaceCoords;
    if (width != null && height != null && objectSpaceCoords != null) {
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
                  worldColumnVector)
              .getColumn(0);
      final colMajorTransform = [
        ...[
          transform[0],
          transform[3],
          transform[6],
          transform[1],
          transform[4],
          transform[7],
          transform[2],
          transform[5]
        ],
        1.0
      ];
      final mat4 = vec.Matrix3.fromList(colMajorTransform).toMatrix4();
      if (kDebugMode) {
        for (var i = 0; i < 4; i++) {
          final point = objectSpaceCoords[i];
          final wSpaceTest = [worldSpaceCoords[i].dx, worldSpaceCoords[i].dy];
          final testResult = mat4 * vec.Vector4(point.dx, point.dy, 0, 1);
          final divW = [
            testResult[0] / testResult[3],
            testResult[1] / testResult[3]
          ];
          if ((wSpaceTest[0] - divW[0]).abs() > 0.01 ||
              (wSpaceTest[1] - divW[1]).abs() > 0.01) {
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
  void dragPoint(int pointID, Offset aimTowards) {
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
      // if (kDebugMode) {
      // log("mouse entering illegal zone D:<");
      // log("mouse at: $aimTowards");
      // log("opposite forward: $oppositeForward");
      // log("side thereof: ${oppositeForward.onSideOf(aimTowards)}");
      // log("opposite backward: $oppositeBackward");
      // log("side thereof: ${oppositeBackward.onSideOf(aimTowards)}");
      // log("cross member: $crossMember");
      // log("side thereof: ${crossMember.onSideOf(aimTowards)}");
      // }

      // good lord
      final closestPoints = [
        ...[oppositeForward, oppositeBackward, crossMember]
            .map((e) => e.closestPointOn(aimTowards))
      ]..sort((p1, p2) => (p1 - aimTowards)
          .distanceSquared
          .compareTo((p2 - aimTowards).distanceSquared));
      final pointOnLine = closestPoints[0];
      final correction = pointOnLine - aimTowards;
      // for stability, when "correcting" a point to keep it within bounds,
      // correct it a little extra to make the shape Definitely not concave.
      final pointOffLine =
          aimTowards + correction + correction.normalized() * 0.001;
      points[pointIndex].loc = pointOffLine;
    } else {
      points[pointIndex].loc = aimTowards;
    }
    final result = points[pointIndex].loc;
    double bounds(double a) => math.min(1, math.max(0, a));
    points[pointIndex].loc = Offset(bounds(result.dx), bounds(result.dy));
  }

  vec.Aabb2 getAABB() {
    final topLeft = points.fold<Offset>(
        Offset.infinite,
        (Offset o, PointModel p) =>
            Offset(math.min(o.dx, p.loc.dx), math.min(o.dy, p.loc.dy)));
    final bottomRight = points.fold<Offset>(
        Offset.zero,
        (Offset o, PointModel p) =>
            Offset(math.max(o.dx, p.loc.dx), math.max(o.dy, p.loc.dy)));
    return vec.Aabb2.minMax(vec.Vector2(topLeft.dx, topLeft.dy),
        vec.Vector2(bottomRight.dx, bottomRight.dy));
  }

  bool pointInFrame(Offset point) {
    // initial fast aabb test:
    final aabb = getAABB();
    if (!aabb.containsVector2(point.toVec2())) {
      return false;
    }
    // split the quad into two triangles. for each triangle, go around and make
    // sure the point is on the right side of each line segment to see if the
    // point is in the triangle. it has to be inside at least one of the
    // triangles.
    // parallel arrays 😌
    final triangles = [
      [points[0].loc, points[1].loc, points[2].loc],
      [points[2].loc, points[3].loc, points[0].loc]
    ];
    final inTris = [true, true];
    for (var j = 0; j < 2; j++) {
      final tri = triangles[j];
      for (var i = 0; i < 3; i++) {
        final rad = RadiantVector(tri[i], tri[(i + 1) % 3], false);
        if (rad.onSideOf(point) == LineSide.left) {
          inTris[j] = false;
          continue;
        }
      }
    }
    return inTris[0] || inTris[1];
  }

  void move(Offset delta) {
    final aabb = getAABB();
    final topLeft = aabb.min.toOffset();
    final bottomRight = aabb.max.toOffset();
    if (topLeft.dx + delta.dx < 0) {
      delta = Offset(-topLeft.dx, delta.dy);
    }
    if (topLeft.dy + delta.dy < 0) {
      delta = Offset(delta.dx, -topLeft.dy);
    }
    if (bottomRight.dx + delta.dx > 1) {
      delta = Offset(1 - bottomRight.dx, delta.dy);
    }
    if (bottomRight.dy + delta.dy > 1) {
      delta = Offset(delta.dx, 1 - bottomRight.dy);
    }
    for (final point in points) {
      point.loc += delta;
    }
  }
}

class FrameCollection extends ChangeNotifier {
  final List<FrameModel> frames;
  final Map<int, FrameModel> _pointIndex = {};
  ImageWidget? backgroundImage;
  TextEditingController nameField = TextEditingController();
  bool showingLines = true;
  bool mainImageLoaded = false;
  TransformationController viewerController = TransformationController();
  double viewerScaleFactor = 1.0;

  Widget undoViewerScale(Widget w,
          {required AlignmentGeometry? shrinkTowards}) =>
      Transform.scale(
          scale: 1 / viewerScaleFactor, alignment: shrinkTowards, child: w);

  /// Used to identify the [CustomPaint] widget whose local coordinate system we
  /// need to use in both drawing and mouse positioning
  final GlobalKey paintKey = GlobalKey(debugLabel: "The painty boy");
  RenderBox? get paintBox =>
      paintKey.currentContext?.findRenderObject() as RenderBox?;

  FrameCollection() : frames = [] {
    addFrame(FrameModel.square());
  }

  Map<String, dynamic> toJSON() {
    return {
      "frames": frames.map((f) => f.toJSON()).toList(),
      "name": nameField.text
    };
  }

  void updateScale() {
    viewerScaleFactor = viewerController.value.getMaxScaleOnAxis();
    notifyListeners();
  }

  void dragPoint(int pointID, Offset position) {
    final frame = _pointIndex[pointID];
    if (frame != null) {
      frame.dragPoint(pointID, position);
      notifyListeners();
    }
  }

  void dragFrame(FrameModel frame, Offset delta) {
    final box = paintBox?.size;
    if (box != null) {
      frame.move(Offset(delta.dx / box.width, delta.dy / box.height));
      notifyListeners();
    }
  }

  void addImage(FrameModel frame, DecodedImage image) {
    if (frames.contains(frame)) {
      frame.image = image;
      if (imageNames[image] != null) {
        frame.nameField.text = imageNames[image]!;
      }
      notifyListeners();
    }
  }

  void addFrame([FrameModel? newFrame]) {
    newFrame = newFrame ?? FrameModel.overlapAvoidingSquare();
    for (final point in newFrame.points) {
      _pointIndex[point.id] = newFrame;
    }
    frames.add(newFrame);
    showingLines = true;
    notifyListeners();
  }

  void removeFrame(FrameModel del) {
    for (final point in del.points) {
      _pointIndex.remove(point.id);
    }
    del.nameField.dispose();
    frames.remove(del);
    notifyListeners();
  }

  void toggleLines() {
    showingLines = !showingLines;
    notifyListeners();
  }

  void setMainImage(ImageWidget image) {
    image.image
        .resolve(const ImageConfiguration())
        .addListener(ImageStreamListener(
      (image, synchronousCall) {
        mainImageLoaded = true;
        notifyListeners();
      },
    ));
    backgroundImage = image;
    notifyListeners();
  }

  void clearMainImage() {
    backgroundImage = null;
    _pointIndex.clear();
    for (final frame in [...frames]) {
      removeFrame(frame);
    }
    nameField.clear();
    mainImageLoaded = false;
    notifyListeners();
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
