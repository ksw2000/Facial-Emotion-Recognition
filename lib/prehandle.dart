import 'package:image/image.dart' as img;
import 'dart:typed_data';

// 3D List
class ImagePrehandle {
  Uint32List list;
  img.Image image;
  var height, width;

  ImagePrehandle(byteData) {
    image = img.JpegDecoder().decodeImage(byteData);
    list = image.data; //Uint32List
    height = image.height;
    width = image.width;
  }

  // return [[r,g,b], [r,g,b], ...]
  List<List<double>> uint32ListToRGBFloat(img.Image src) {
    List<List<double>> rgb = [];
    // e is ##AARRGGBB
    src.data.forEach((e) {
      var tmp = e;
      var r = tmp % 256;
      tmp -= r;
      tmp ~/= 256;
      var g = tmp % 256;
      tmp -= g;
      tmp ~/= 256;
      var b = tmp % 256;
      rgb.add([r / 255.0, g / 255.0, b / 255.0]);
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

  /*
  List ABGRCodeToList(int abgr) {
    var r = abgr % 256;
    abgr -= r;
    abgr ~/= 256;
    var g = abgr % 256;
    abgr -= g;
    abgr ~/= 256;
    var b = abgr % 256;
    return [r / 255.0, g / 255.0, b / 255.0];
  }

  img.Image RGBFloatList3DToUint32(
      List<List<List<dynamic>>> rgbList, width, height) {
    List<int> list = [];
    rgbList.forEach((e) {
      e.forEach((f) {
        list.add((f[0] * 255).toInt());
        list.add((f[1] * 255).toInt());
        list.add((f[2] * 255).toInt());
      });
    });
    print(list);
    return img.Image.fromBytes(
      width,
      height,
      list,
      format: img.Format.rgb,
    );
  }
*/
  img.Image crop(img.Image src, {int x, int y, int w, int h}) {
    return img.copyCrop(src, x, y, w, h);
  }
}
