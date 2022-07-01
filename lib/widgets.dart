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
    return ImageWidget.memory(bytes, filterQuality: FilterQuality.medium,
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
  }
  return null;
}

/// Draws a little circle to represent a [PointModel]; detects pointer events
/// that want to move it and gets [FrameCollection] to update the state based on
/// them.
class PointWidget extends StatelessWidget {
  final int pointID;
  static const double radius = 5;
  const PointWidget({super.key, required this.pointID});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanUpdate: (details) {
        final state = Provider.of<FrameCollection>(context, listen: false);
        final box = state.paintBox;
        if (box != null) {
          Offset position = box.globalToLocal(details.globalPosition);
          position = Offset(
              position.dx / box.size.width, position.dy / box.size.height);
          state.dragPoint(pointID, position);
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

/// Draws the lines and images for all the frames in [this.frames].
class FramePainter extends CustomPainter {
  final style = Paint()..color = Colors.black;
  final List<FrameModel> frames;
  final bool drawLines;
  final FilterQuality quality;
  FramePainter(this.frames, this.drawLines,
      [this.quality = FilterQuality.medium]);

  Float64List getF64L(Matrix4 m) {
    return Float64List.fromList(
        [for (var i = 0; i < 4; i++) ...m.getColumn(i).storage]);
  }

  @override
  void paint(Canvas canvas, Size size) {
    for (final frame in frames) {
      canvas.save();
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
        canvas.drawImage(image, Offset.zero, Paint()..filterQuality = quality);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}

class FloatingFrameButton extends StatelessWidget {
  final GestureTapCallback onPressed;
  final Icon icon;
  const FloatingFrameButton(
      {required this.onPressed, required this.icon, super.key});
  final buttonSize = 30.0;
  @override
  Widget build(BuildContext context) {
    return IconButton(
        padding: const EdgeInsets.all(2),
        constraints:
            BoxConstraints(maxWidth: buttonSize, maxHeight: buttonSize),
        iconSize: buttonSize * 0.8,
        onPressed: onPressed,
        icon: icon);
  }
}

/// Builds the draggable points, open image button, and other interactible
/// components for [this.frame].
class FrameWidget extends StatelessWidget {
  final FrameModel frame;
  const FrameWidget(this.frame, {Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    final state = Provider.of<FrameCollection>(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        // the box in which the PointWidgets can be rendered has to be bigger
        // than this container so that the centers of the points can be at the
        // edges of the image meaning that the sides of the points are off the
        // edge of the image
        final pointAreaWidth = constraints.maxWidth + PointWidget.radius * 2;
        final pointAreaHeight = constraints.maxHeight + PointWidget.radius * 2;

        /// control buttons are anchored, arbitrarily, to the 3rd point in the
        /// point array. as long as the frames were constructed to spec, this
        /// will be the botom right point, at least before the user starts
        /// rotating things.
        const controlButtonSize = 30.0;
        final controlRowAnchor = frame.points[2].loc
            .scale(constraints.maxWidth, constraints.maxHeight);
        // to compensate for the "margin" of the pointAreaHeight:
        var controlRowYOffset = PointWidget.radius;
        // to add a gap between the point and the control row:
        // ("PointWidget.radius*1/5" could be replaced with whatever you like)
        final controlRowGap =
            PointWidget.radius * 1.5 / state.viewerScaleFactor;
        // if we actually have to put the control row above the point:
        if (controlRowAnchor.dy +
                controlRowYOffset +
                controlButtonSize / state.viewerScaleFactor >
            constraints.maxHeight) {
          controlRowYOffset -=
              controlButtonSize / state.viewerScaleFactor + controlRowGap;
        } else {
          controlRowYOffset += controlRowGap;
        }
        // to compensate for the "margin" of pointAreaWidth:
        var controlRowXOffset = PointWidget.radius;
        // for centering; assumes 3 control buttons!
        controlRowXOffset -= controlButtonSize * 1.5;
        final controlRowPos = Offset(controlRowAnchor.dx + controlRowXOffset,
            controlRowAnchor.dy + controlRowYOffset);

        // label positioning logic: find the highest-up points in the frame. if
        // there isn't room above them, find the two lowest-down points in the
        // frame. either way, take the two most extreme points. if they have
        // very similar y-values, position the label directly between them.
        // otherwise, position the label directly above/below the most high
        // up/low down point.
        const labelWidth = 150;
        const labelHeight = 30;
        var columned = [...frame.points];
        late final Offset labelAnchor;
        late double labelYOffset;
        columned.sort((a, b) => a.loc.dy.compareTo(b.loc.dy));
        if (columned[0].loc.dy <
            (labelHeight / state.viewerScaleFactor + 15) /
                constraints.maxHeight) {
          labelYOffset = 30;
          columned = columned.reversed.toList();
        } else {
          labelYOffset = -labelHeight - 15;
        }
        labelYOffset /= state.viewerScaleFactor;
        final topTwoDifference =
            (columned[0].loc.dy - columned[1].loc.dy).abs();
        if (topTwoDifference < 0.05) {
          labelAnchor = ((columned[0].loc + columned[1].loc) / 2)
              .scale(constraints.maxWidth, constraints.maxHeight);
        } else {
          labelAnchor = columned[0]
              .loc
              .scale(constraints.maxWidth, constraints.maxHeight);
        }
        final labelPos = Offset(
            labelAnchor.dx - labelWidth / 2, labelAnchor.dy + labelYOffset);

        return OverflowBox(
          maxWidth: pointAreaWidth,
          maxHeight: pointAreaHeight,
          child: Stack(
            children: [
              if (state.showingLines)
                for (final point in frame.points) ...[
                  Align(
                    alignment: FractionalOffset(point.loc.dx, point.loc.dy),
                    child: state.undoViewerScale(
                        shrinkTowards: Alignment.center,
                        PointWidget(pointID: point.id)),
                  )
                ],
              if (state.showingLines)
                Positioned(
                  left: labelPos.dx,
                  top: labelPos.dy,
                  child: state.undoViewerScale(
                    shrinkTowards: Alignment.topCenter,
                    Container(
                      decoration: const BoxDecoration(
                          color: Colors.white60,
                          borderRadius: BorderRadius.all(Radius.circular(5))),
                      padding: const EdgeInsets.fromLTRB(5, 8, 5, 5),
                      child: SizedBox(
                        width: labelWidth.toDouble(),
                        height: labelHeight.toDouble(),
                        child: TextField(
                          textAlign: TextAlign.center,
                          textAlignVertical: TextAlignVertical.center,
                          style: const TextStyle(fontSize: labelHeight - 15),
                          controller: frame.nameField,
                          clipBehavior: Clip.none,
                          decoration: const InputDecoration(
                              border: OutlineInputBorder(
                                borderSide: BorderSide(color: Colors.grey),
                              ),
                              labelStyle: TextStyle(
                                  color: Colors.black,
                                  fontSize: labelHeight - 15),
                              alignLabelWithHint: true,
                              floatingLabelAlignment:
                                  FloatingLabelAlignment.center,
                              fillColor: Colors.black26,
                              labelText: "Frame ID"),
                        ),
                      ),
                    ),
                  ),
                ),
              if (!controlRowPos.dx.isNaN &&
                  !controlRowPos.dy.isNaN &&
                  state.showingLines)
                Positioned(
                  left: controlRowPos.dx,
                  top: controlRowPos.dy,
                  child: state.undoViewerScale(
                      shrinkTowards: Alignment.topCenter,
                      Container(
                        decoration: const BoxDecoration(
                          color: Colors.white60,
                          shape: BoxShape.rectangle,
                          borderRadius: BorderRadius.all(Radius.circular(2.0)),
                        ),
                        child: Row(children: [
                          GestureDetector(
                            onPanUpdate: (details) {
                              final state = Provider.of<FrameCollection>(
                                  context,
                                  listen: false);
                              state.dragFrame(frame,
                                  details.delta / state.viewerScaleFactor);
                            },
                            child: FloatingFrameButton(
                              onPressed: () {},
                              icon: const Icon(Icons.open_with_outlined),
                            ),
                          ),
                          FloatingFrameButton(
                              onPressed: () async {
                                final image = await getImage();
                                if (image != null) {
                                  state.addImage(frame, image);
                                }
                              },
                              icon: const Icon(Icons.folder_outlined)),
                          FloatingFrameButton(
                              onPressed: () {
                                state.removeFrame(frame);
                              },
                              icon: const Icon(Icons.delete_outlined))
                        ]),
                      )),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Builds all the [FrameModel]s in the [FrameCollection] state via one instance
/// of [FramePainter] and then one instance of [FrameWidget] for each
/// [FrameModel].
class FrameLayer extends StatelessWidget {
  const FrameLayer({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<FrameCollection>(context);
    return CustomPaint(
      key: state.paintKey,
      painter: FramePainter(state.frames, state.showingLines),
      child: Stack(children: [
        if (state.showingLines)
          for (final frame in state.frames) FrameWidget(frame)
      ]),
    );
  }
}
