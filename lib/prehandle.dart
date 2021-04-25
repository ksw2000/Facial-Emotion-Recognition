import 'package:image/image.dart' as img;
import 'dart:typed_data';

// 3D List
class ImagePrehandle {
  img.Image image;

  ImagePrehandle(this.image);

  List<List<List<double>>> uint32ListToRGB3D(img.Image src) {
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

  img.Image crop(img.Image src, {int x, int y, int w, int h}) {
    return img.copyCrop(src, x, y, w, h);
  }

  img.Image resize(img.Image src, {int w, int h}) {
    return img.copyResize(src, width: w, height: h);
  }
}
