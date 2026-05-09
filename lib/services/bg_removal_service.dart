import 'dart:typed_data';

import 'bg_removal_stub.dart'
  if (dart.library.html) 'bg_removal_web.dart';

class BgRemovalService {
  static Future<Uint8List> removeBackground(Uint8List imageBytes) async {
    return removeBackgroundImpl(imageBytes);
  }

  static Future<Uint8List> flattenImageToJpeg(Uint8List imageBytes) async {
    return flattenImageToJpegImpl(imageBytes);
  }
}
