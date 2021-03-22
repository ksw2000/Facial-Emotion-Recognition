import 'package:tflite_flutter/tflite_flutter.dart' as tfl;

// reference: https://github.com/am15h/tflite_flutter_helper/blob/master/example/image_classification/lib/classifier.dart

class Classifier {
  var _inputShape;
  var _outputShape;
  var _interpreter;

  dynamic get inputShape => _inputShape;
  dynamic get outputShape => _outputShape;

  Future<tfl.Interpreter> loadModel(path) async {
    try {
      _interpreter = await tfl.Interpreter.fromAsset(path);
      print('interpreter Created Succesfully');
      _inputShape = _interpreter.getInputTensor(0).shape;
      _outputShape = _interpreter.getOutputTensor(0).shape;
      var _outputType = _interpreter.getOutputTensor(0).type;
      print("inputshape $_inputShape");
      print("outputshape $_outputShape");
      print("outputtype $_outputType");
      return _interpreter;
    } catch (e) {
      print('Unable to create interpreter, Caught Exception: $e');
    }
    return null;
    /*
    * https://medium.com/@hugand/capture-photos-from-camera-using-image-stream-with-flutter-e9af94bc2bee
    * */
  }

  dynamic run(input, output) {
    _interpreter.run(input, output);
    return output;
  }

  Map<String, dynamic> decide(List list1D) {
    if (list1D == null) return null;
    if (list1D.length == 0) return null;
    var maxIndex = 0;
    var sum = 0.0;
    for (int i = 0; i < list1D.length; i++) {
      sum += list1D[i];
      if (list1D[i] > list1D[maxIndex]) {
        maxIndex = i;
      }
    }
    return {"sum": sum, "label": maxIndex, "val": list1D[maxIndex]};
  }
}
