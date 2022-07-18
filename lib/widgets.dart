import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'models.dart';

/// Draws a little circle to represent a [PointModel]; detects pointer events
/// that want to move it and gets [FrameCollection] to update the state based on
/// them.
class PointWidget extends StatelessWidget {
  final int pointID;
  static double get radius =>
      WidgetsBinding.instance.window.physicalSize.width > 600 ? 5 : 10;
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
  final List<FrameModel> frames;
  final bool drawLines;
  final FilterQuality quality;
  final double lineWidth;
  FramePainter(this.frames, this.drawLines, this.lineWidth,
      [this.quality = FilterQuality.medium]);

  Float64List getF64L(Matrix4 m) {
    return Float64List.fromList(
        [for (var i = 0; i < 4; i++) ...m.getColumn(i).storage]);
  }

  @override
  void paint(Canvas canvas, Size size) {
    for (final frame in frames) {
      if (drawLines) {
        for (int i = 0; i < 4; i++) {
          for (var layer = 0; layer < 2; layer++) {
            canvas.drawLine(
                frame.points[i].loc.scale(size.width, size.height),
                frame.points[(i + 1) % 4].loc.scale(size.width, size.height),
                Paint()
                  ..color = layer == 0 ? Colors.black : Colors.white
                  ..strokeWidth = lineWidth / (layer == 0 ? 1 : 3)
                  ..strokeCap = StrokeCap.round
                  ..filterQuality = quality);
          }
        }
      }

      final tf = frame.makeImageFit(size.width, size.height);
      final image = frame.image;
      if (tf != null && image != null) {
        canvas.save();
        canvas.transform(getF64L(tf));
        canvas.drawImage(image, Offset.zero, Paint()..filterQuality = quality);
        canvas.restore();
      }
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

class FrameWidget extends StatefulWidget {
  final FrameModel frame;

  const FrameWidget(this.frame, {Key? key}) : super(key: key);
  @override
  FrameState createState() => FrameState();
}

/// Builds the draggable points, open image button, and other interactible
/// components for [this.frame].
class FrameState extends State<FrameWidget> {
  bool childHovered = false;
  bool quadHovered = false;

  bool get showControls => childHovered || quadHovered;

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<FrameCollection>(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final frame = widget.frame;
        // the box in which the PointWidgets can be rendered has to be bigger
        // than this container so that the centers of the points can be at the
        // edges of the image meaning that the sides of the points are off the
        // edge of the image
        final pointAreaWidth = constraints.maxWidth + PointWidget.radius * 2;
        final pointAreaHeight = constraints.maxHeight + PointWidget.radius * 2;

        final scaledPoints = frame.points.map(
            (p) => p.loc.scale(constraints.maxWidth, constraints.maxHeight));

        // the control button row is centered around the center point of the
        // frame.
        final controlRowAnchor = scaledPoints.reduce((acc, el) => acc + el) / 4;
        final controlRowCenterPos = Offset(
            controlRowAnchor.dx + PointWidget.radius,
            controlRowAnchor.dy + PointWidget.radius);

        // label positioning logic: find the highest-up points in the frame. if
        // there isn't room above them, find the two lowest-down points in the
        // frame. either way, take the two most extreme points. if they have
        // very similar y-values, position the label directly between them.
        // otherwise, position the label directly above/below the most high
        // up/low down point.
        const labelWidth = 150;
        const labelHeight = 30;
        var columned = [...scaledPoints];
        late final Offset labelAnchor;
        late double labelYOffset;
        columned.sort((a, b) => a.dy.compareTo(b.dy));
        if (columned[0].dy <
            (labelHeight / state.viewerScaleFactor + 15) /
                constraints.maxHeight) {
          labelYOffset = 30;
          columned = columned.reversed.toList();
        } else {
          labelYOffset = -labelHeight - 15;
        }
        labelYOffset /= state.viewerScaleFactor;
        final topTwoDifference = (columned[0].dy - columned[1].dy).abs();
        if (topTwoDifference < 5) {
          labelAnchor = ((columned[0] + columned[1]) / 2);
        } else {
          labelAnchor = columned[0];
        }
        final labelPos = Offset(
            labelAnchor.dx - labelWidth / 2, labelAnchor.dy + labelYOffset);

        return OverflowBox(
          maxWidth: pointAreaWidth,
          maxHeight: pointAreaHeight,
          child: Stack(
            children: [
              MouseRegion(
                  opaque: false,
                  onHover: (event) {
                    setState(() {
                      quadHovered = frame.pointInFrame((event.localPosition -
                              Offset(PointWidget.radius, PointWidget.radius))
                          .scale(1 / constraints.maxWidth,
                              1 / constraints.maxHeight));
                    });
                  },
                  child: Listener(
                    behavior: HitTestBehavior.translucent,
                    onPointerUp: (event) {
                      setState(() {
                        quadHovered = frame.pointInFrame((event.localPosition -
                                Offset(PointWidget.radius, PointWidget.radius))
                            .scale(1 / constraints.maxWidth,
                                1 / constraints.maxHeight));
                      });
                    },
                  )),
              MouseRegion(
                opaque: false,
                onEnter: (event) => setState(() {
                  childHovered = true;
                }),
                onExit: (event) => setState(() {
                  childHovered = false;
                }),
                hitTestBehavior: HitTestBehavior.deferToChild,
                child: Stack(children: [
                  if (!controlRowCenterPos.dx.isNaN &&
                      !controlRowCenterPos.dy.isNaN &&
                      state.showingLines &&
                      showControls)
                    Positioned(
                      left: controlRowCenterPos.dx,
                      top: controlRowCenterPos.dy,
                      child: FractionalTranslation(
                          translation: const Offset(-0.5, -0.5),
                          child: state.undoViewerScale(
                            shrinkTowards: Alignment.center,
                            AnimatedOpacity(
                              duration: const Duration(milliseconds: 200),
                              opacity: showControls ? 1 : 0,
                              child: Container(
                                decoration: const BoxDecoration(
                                  color: Colors.white60,
                                  shape: BoxShape.rectangle,
                                  borderRadius:
                                      BorderRadius.all(Radius.circular(2.0)),
                                ),
                                child: FrameControls(frame: frame),
                              ),
                            ),
                          )),
                    ),
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
                        AnimatedOpacity(
                          duration: const Duration(milliseconds: 200),
                          opacity: showControls ? 1 : 0,
                          child: Container(
                            decoration: const BoxDecoration(
                                color: Colors.white60,
                                borderRadius:
                                    BorderRadius.all(Radius.circular(5))),
                            padding: const EdgeInsets.fromLTRB(5, 8, 5, 5),
                            child: SizedBox(
                              width: labelWidth.toDouble(),
                              height: labelHeight.toDouble(),
                              child: TextField(
                                textAlign: TextAlign.center,
                                textAlignVertical: TextAlignVertical.center,
                                style:
                                    const TextStyle(fontSize: labelHeight - 15),
                                controller: frame.nameField,
                                clipBehavior: Clip.none,
                                decoration: const InputDecoration(
                                    border: OutlineInputBorder(
                                      borderSide:
                                          BorderSide(color: Colors.grey),
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
                    ),
                ]),
              )
            ],
          ),
        );
      },
    );
  }
}

class FrameControls extends StatelessWidget {
  const FrameControls({
    Key? key,
    required this.frame,
  }) : super(key: key);

  final FrameModel frame;

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<FrameCollection>(context, listen: false);
    return Row(children: [
      GestureDetector(
        onPanUpdate: (details) {
          state.dragFrame(frame, details.delta / state.viewerScaleFactor);
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
    ]);
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
      painter: FramePainter(
          state.frames, state.showingLines, 3 / state.viewerScaleFactor),
      child: Stack(children: [
        if (state.showingLines)
          for (final frame in state.frames) FrameWidget(frame)
      ]),
    );
  }
}
