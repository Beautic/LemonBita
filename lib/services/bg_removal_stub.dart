import 'dart:typed_data';

Future<Uint8List> removeBackgroundImpl(Uint8List imageBytes) async {
  throw UnsupportedError('Background removal is only supported on the web.');
}

Future<Uint8List> flattenImageToJpegImpl(Uint8List imageBytes) async {
  throw UnsupportedError('Image flattening is only supported on the web.');
}
