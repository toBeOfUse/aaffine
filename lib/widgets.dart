import 'dart:developer';
import 'dart:ui';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'models.dart';

Future<Uint8List?> getImageBytes() async {
  FilePickerResult? result =
      await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
  if (result != null && result.files.isNotEmpty) {
    Uint8List? bytes = result.files.first.bytes;
    return bytes;
  }
  return null;
}

Future<DecodedImage?> getImage() async {
  final bytes = await getImageBytes();
  if (bytes != null) {
    try {
      final Codec codec = await instantiateImageCodec(bytes);
      return (await codec.getNextFrame()).image;
    } catch (e) {
      log("could not load image", level: 500);
      log(e.toString());
    }
  }
  return null;
}

Future<ImageWidget?> getImageWidget() async {
  final bytes = await getImageBytes();
  if (bytes != null) {
    return ImageWidget.memory(bytes, filterQuality: FilterQuality.medium);
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
      painter: FramePainter(frame, state.showingLines),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // the box in which the PointWidgets can be rendered has to be bigger
          // than this container so that the centers of the points can be at the
          // edges of the image meaning that the sides of the points are off the
          // edge of the image
          const openButtonSize = 30.0;
          final pointAreaWidth = constraints.maxWidth + PointWidget.radius * 2;
          final pointAreaHeight =
              constraints.maxHeight + PointWidget.radius * 2;
          final openButtonPoint = frame.points[2].loc
              .scale(constraints.maxWidth, constraints.maxHeight);
          var openButtonYOffset = PointWidget.radius * 2.5;
          if (openButtonPoint.dy + openButtonYOffset + openButtonSize >
              constraints.maxHeight) {
            openButtonYOffset = -openButtonYOffset - openButtonSize * 1.5;
          }
          final openPos = Offset(
              openButtonPoint.dx, openButtonPoint.dy + openButtonYOffset);
          return OverflowBox(
              maxWidth: pointAreaWidth,
              maxHeight: pointAreaHeight,
              child: Stack(
                children: [
                  if (state.showingLines)
                    for (final point in frame.points) ...[
                      Align(
                          alignment:
                              FractionalOffset(point.loc.dx, point.loc.dy),
                          child: PointWidget(pointID: point.id)),
                    ],
                  if (!openPos.dx.isNaN &&
                      !openPos.dy.isNaN &&
                      state.showingLines)
                    Positioned(
                      left: openPos.dx,
                      top: openPos.dy,
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Colors.white24,
                          shape: BoxShape.rectangle,
                          borderRadius: BorderRadius.all(Radius.circular(2.0)),
                        ),
                        child: IconButton(
                            padding: const EdgeInsets.all(2),
                            constraints: const BoxConstraints(
                                maxWidth: openButtonSize,
                                maxHeight: openButtonSize),
                            iconSize: openButtonSize * 0.8,
                            onPressed: () async {
                              final image = await getImage();
                              if (image != null) {
                                state.addImage(frame, image);
                              }
                            },
                            icon: const Icon(Icons.folder_outlined)),
                      ),
                    ),
                ],
              ));
        },
      ),
    );
  }
}

class FramePainter extends CustomPainter {
  final style = Paint()..color = Colors.black;
  final FrameModel frame;
  final bool drawLines;
  FramePainter(this.frame, this.drawLines);

  Float64List getF64L(Matrix4 m) {
    return Float64List.fromList(
        [for (var i = 0; i < 4; i++) ...m.getColumn(i).storage]);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (drawLines) {
      for (int i = 0; i < 4; i++) {
        canvas.drawLine(
            frame.points[i].loc.scale(size.width, size.height),
            frame.points[(i + 1) % 4].loc.scale(size.width, size.height),
            style);
      }
    }

    final tf = frame.makeImageFit(size.width, size.height);
    final image = frame.image;
    if (tf != null && image != null) {
      canvas.transform(getF64L(tf));
      canvas.drawImage(
          image, Offset.zero, Paint()..filterQuality = FilterQuality.medium);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}
