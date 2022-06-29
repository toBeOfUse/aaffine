import 'dart:convert';
import 'dart:html';
import 'dart:ui' show Image, ImageByteFormat;

void saveImage(Image image) async {
  final metaCanvas = CanvasElement(width: image.width, height: image.height);
  final buffer =
      (await image.toByteData(format: ImageByteFormat.rawStraightRgba))?.buffer;
  final bytes = buffer!.asUint8ClampedList();
  final context = (metaCanvas.getContext("2d") as CanvasRenderingContext2D);
  context.putImageData(ImageData(bytes, image.width, image.height), 0, 0);
  window.console.log(context);
  window.console.log(metaCanvas);
  final blobURL =
      Url.createObjectUrlFromBlob(await context.canvas.toBlob("png"));
  AnchorElement(href: blobURL)
    ..setAttribute("download", "framed.png")
    ..click();
}

void saveJSON(Map<String, dynamic> json) async {
  AnchorElement(
      href: Url.createObjectUrlFromBlob(
          Blob([jsonEncode(json)], "application/json")))
    ..setAttribute("download", "framed.png")
    ..click();
}
