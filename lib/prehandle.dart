import 'package:image/image.dart' as img;
import 'dart:typed_data';

// 3D List
class ImagePrehandle {
  Uint32List list;
  img.Image image;
  var height, width;

  ImagePrehandle(this.image) {
    list = image.data; //Uint32List
    height = image.height;
    width = image.width;
  }

  // return [[r,g,b], [r,g,b], ...]
  /*
  List<List<double>> uint32ListToRGBFloat(img.Image src) {
    List<List<double>> rgb = List.filled(src.data.length, [0, 0, 0]);
    // e is ##AABBGGRR
    int i = 0;
    src.data.forEach((e) {
      rgb[i][0] = (e & 255) / 255.0;
      e = (e >> 8);
      rgb[i][1] = (e & 255) / 255.0;
      e = (e >> 8);
      rgb[i][2] = (e & 255) / 255.0;
      i = i + 1;
    });
    return rgb;
  }

  List reshape(List src, int w, int h) {
    List<List<List<dynamic>>> dest = List.filled(w, List.filled(h, [0, 0, 0]));
    int count = 0;
    for (int i = 0; i < w; i++) {
      for (int j = 0; j < h; j++) {
        dest[i][j] = src[count++];
      }
    }
    return dest;
  }
   */

  /*List<List<List<double>>> uint32ListToRGB3D(img.Image src) {
    List<List<List<double>>> rgb =
        List.filled(src.width, List.filled(src.height, [0, 0, 0]));

    int k = 0;
    int e;
    for (int i = 0; i < src.width; i++) {
      for (int j = 0; j < src.height; j++) {
        e = src.data[k++];
        // e is ##AABBGGRR
        rgb[i][j][0] = (e & 255) / 255.0;
        e = (e >> 8);
        rgb[i][j][1] = (e & 255) / 255.0;
        e = (e >> 8);
        rgb[i][j][2] = (e & 255) / 255.0;
      }
    }
    print(rgb);
    return rgb;
  }*/

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
