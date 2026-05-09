import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:js_util' as js_util;

String _detectMime(Uint8List bytes) {
  if (bytes.length >= 4 &&
      bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47) {
    return 'image/png';
  }
  if (bytes.length >= 3 && bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
    return 'image/jpeg';
  }
  if (bytes.length >= 12 &&
      bytes[0] == 0x52 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x46 &&
      bytes[8] == 0x57 && bytes[9] == 0x45 && bytes[10] == 0x42 && bytes[11] == 0x50) {
    return 'image/webp';
  }
  return 'image/jpeg';
}

Future<Uint8List> flattenImageToJpegImpl(Uint8List imageBytes) async {
  final mime = _detectMime(imageBytes);
  final dataUrl = 'data:$mime;base64,${base64Encode(imageBytes)}';
  if (!js_util.hasProperty(js_util.globalThis, 'flattenImageToJpeg')) {
    throw Exception('flattenImageToJpeg not registered yet.');
  }
  final promise = js_util.callMethod(js_util.globalThis, 'flattenImageToJpeg', [dataUrl]);
  final result = await js_util.promiseToFuture<dynamic>(promise);
  if (result == null) throw Exception('flattenImageToJpeg returned null');
  final s = result.toString();
  final i = s.indexOf(',');
  if (i == -1) throw Exception('Invalid data URL from flattenImageToJpeg');
  return base64Decode(s.substring(i + 1));
}

Future<Uint8List> removeBackgroundImpl(Uint8List imageBytes) async {
  try {
    final mime = _detectMime(imageBytes);
    final base64String = base64Encode(imageBytes);
    final dataUrl = 'data:$mime;base64,$base64String';

    if (!js_util.hasProperty(js_util.globalThis, 'removeImageBackground')) {
      throw Exception('Background removal module is not loaded yet. Please refresh or try again in a few seconds.');
    }

    final promise = js_util.callMethod(js_util.globalThis, 'removeImageBackground', [dataUrl]);

    dynamic result;
    try {
      result = await js_util.promiseToFuture<dynamic>(promise);
    } catch (jsError) {
      final msg = js_util.hasProperty(jsError, 'message')
          ? js_util.getProperty(jsError, 'message')
          : jsError;
      throw Exception('JS bg-removal failed: $msg');
    }

    if (result == null) {
      throw Exception('Background removal returned null.');
    }

    final resultString = result.toString();
    final commaIndex = resultString.indexOf(',');
    if (commaIndex == -1) {
      throw Exception('Invalid data URL returned from JS');
    }

    final base64Result = resultString.substring(commaIndex + 1);
    return base64Decode(base64Result);
  } catch (_) {
    rethrow;
  }
}
