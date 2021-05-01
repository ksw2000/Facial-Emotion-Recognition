import 'package:tflite_flutter/tflite_flutter.dart' as tfl;
// reference: https://github.com/am15h/tflite_flutter_helper/blob/master/example/image_classification/lib/classifier.dart

class Classifier {
  var _inputShape;
  var _outputShape;
  var _interpreter;
  var _outputSize;

  dynamic get inputShape => _inputShape;
  dynamic get outputShape => _outputShape;
  dynamic get interpreter => _interpreter;
  dynamic get outputSize => _outputSize;

  Future<tfl.Interpreter> loadModel(path) async {
    try {
      if (_interpreter != null) return _interpreter;
      _interpreter = await tfl.Interpreter.fromAsset(path);
      _inputShape = _interpreter.getInputTensor(0).shape;
      _outputShape = _interpreter.getOutputTensor(0).shape;

      _outputSize = 1;
      outputShape.forEach((e) {
        _outputSize *= e;
      });

      return _interpreter;
    } catch (e) {
      print('Unable to create interpreter, Caught Exception: $e');
    }
    return null;
    /*
    * https://medium.com/@hugand/capture-photos-from-camera-using-image-stream-with-flutter-e9af94bc2bee
    * */
  }

  int run(input) {
    var output = List.filled(_outputSize, 0).reshape(_outputShape);
    _interpreter.run(input, output);
    return _max(output[0]);
  }

  int _max(List<num> list) {
    if (list == null || list?.length == 0) return null;
    int index = 0;
    for (int i = 0; i < list.length; i++) {
      if (list[i] > list[index]) {
        index = i;
      }
    }
    return index;
  }
}
