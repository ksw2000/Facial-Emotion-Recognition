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
      print("Classifier.loadModel() input shape: $_inputShape");
      print("Classifier.loadModel() output shape: $_outputShape");
      print("Classifier.loadModel() output type: $_outputType");
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
}
