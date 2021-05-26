import 'package:image/image.dart' as img;
import 'package:camera/camera.dart';

// 3D List
class ImagePrehandle {
  static List<List<List<double>>> uint32ListToRGB3D(img.Image src) {
    int k = 0;
    int e;
    List<List<List<double>>> rgb = [];
    for (int i = 0; i < src.width; i++) {
      List<List<double>> row = [];
      for (int j = 0; j < src.height; j++) {
        // e is ##AABBGGRR
        e = src.data[k++];
        row.add([
          (e & 255) / 255.0,
          ((e >> 8) & 255) / 255.0,
          ((e >> 16) & 255) / 255.0
        ]);
      }
      rgb.add(row);
    }
    return rgb;
  }

  static img.Image convertYUV420(CameraImage image) {
    var ret = img.Image(image.width, image.height); // Create Image buffer

    Plane plane = image.planes[0];
    const int shift = (0xFF << 24);

    // Fill image buffer with plane[0] from YUV420_888
    for (int x = 0; x < image.width; x++) {
      for (int planeOffset = 0;
          planeOffset < image.height * image.width;
          planeOffset += image.width) {
        final pixelColor = plane.bytes[planeOffset + x];
        // color: 0x FF  FF  FF  FF
        //           A   B   G   R
        // Calculate pixel color
        var newVal =
            shift | (pixelColor << 16) | (pixelColor << 8) | pixelColor;

        ret.data[planeOffset + x] = newVal;
      }
    }

    return ret;
  }
}
