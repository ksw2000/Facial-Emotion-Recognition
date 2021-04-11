import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart' as tfl;
import 'package:image/image.dart' as img;
import './classifier.dart';
import './prehandle.dart';

const int shotSize = 500;
const facial = ['驚訝', '怕爆', '噁心', '開勳', '桑心', '森77', '無'];
int max(List<num> list) {
  if (list == null || list?.length == 0) return null;
  int index = 0;
  for (int i = 0; i < list.length; i++) {
    if (list[i] > list[index]) {
      index = i;
    }
  }
  return index;
}

int min(List<num> list) {
  if (list == null || list?.length == 0) return null;
  int index = 0;
  for (int i = 0; i < list.length; i++) {
    if (list[i] < list[index]) {
      index = i;
    }
  }
  return index;
}

Future<void> main() async {
  // Ensure that plugin services are initialized so that `availableCameras()`
  // can be called before `runApp()`
  WidgetsFlutterBinding.ensureInitialized();

  // Obtain a list of the available cameras on the device.
  final cameras = await availableCameras();

  // Get a specific camera from the list of available cameras.
  final firstCamera = cameras.first;

  runApp(
    MaterialApp(
      theme: ThemeData.dark(),
      home: TakePictureScreen(
        // Pass the appropriate camera to the TakePictureScreen widget.
        camera: firstCamera,
      ),
    ),
  );
}

// A screen that allows users to take a picture using a given camera.
class TakePictureScreen extends StatefulWidget {
  final CameraDescription camera;

  const TakePictureScreen({
    Key key,
    @required this.camera,
  }) : super(key: key);

  @override
  TakePictureScreenState createState() => TakePictureScreenState();
}

class TakePictureScreenState extends State<TakePictureScreen> {
  CameraController _cameraCtrl;
  Future<void> _initializeControllerFuture;
  String text;
  Widget preview;

  @override
  void initState() {
    super.initState();
    _cameraCtrl =
        CameraController(widget.camera, ResolutionPreset.high, // 1280x720
            enableAudio: true);
    _initializeControllerFuture = _cameraCtrl.initialize();
    text = "";
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double ratio = MediaQuery.of(context).size.width / 720;
    double top = (1280 - shotSize) / 2;
    double right = (720 - shotSize) / 2;

    return Scaffold(
      body: SafeArea(
          child: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (BuildContext context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            // If the Future is complete, display the preview.
            return Stack(
              children: [
                CameraPreview(
                  _cameraCtrl,
                ),
                Box.square(
                    top: top,
                    right: right,
                    side: shotSize.toDouble(),
                    ratio: ratio),
                Align(
                    alignment: Alignment.bottomCenter,
                    child: Text(text ?? "", style: TextStyle(fontSize: 50))),
                (preview != null)
                    ? Align(alignment: Alignment.topRight, child: preview)
                    : Container()
              ],
            );
          } else {
            // Otherwise, display a loading indicator.
            return Center(child: CircularProgressIndicator());
          }
        },
      )),
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.camera_alt),
        // Provide an onPressed callback.
        onPressed: () async {
          print("click");
          /*
          _controller.startImageStream((CameraImage getImage) {
            print("line66");
            print(getImage.width);
          });
          */
          // Take the Picture in a try / catch block. If anything goes wrong,
          // catch the error.
          try {
            // Ensure that the camera is initialized.
            await _initializeControllerFuture;

            // Attempt to take a picture and log where it's been saved.
            await _cameraCtrl.takePicture().then((XFile file) async {
              if (mounted) {
                runModel(
                    image: file,
                    top: top,
                    right: right,
                    callback: (img.Image i) {
                      setState(() {
                        preview =
                            Image.memory(img.JpegEncoder().encodeImage(i));
                      });
                    }).then((res) {
                  setState(() {
                    print(res);
                    text = res;
                  });
                });
              }
            });
          } catch (e) {
            print(e);
          }
        },
      ),
    );
  }
}

Future<String> runModel(
    {XFile image, double right: 0, double top: 0, Function callback}) async {
  try {
    /// Pixels are encoded into 4-byte Uint32 integers in #AABBGGRR channel order.
    ImagePrehandle preHandle = ImagePrehandle(await image.readAsBytes());
    Classifier cls = Classifier();

    var interpreter = await cls.loadModel('fe.tflite');

    // 3D list
    // crop's direction vertical top x = 0, horizontal right: y = 0
    preHandle.image = preHandle.crop(preHandle.image,
        y: right.toInt(), x: top.toInt(), w: shotSize, h: shotSize);
    preHandle.image = preHandle.resize(preHandle.image,
        w: cls.inputShape[1], h: cls.inputShape[2]);

    // check the photo after cropped and resized
    if (callback != null) {
      callback(preHandle.image);
    }

    dynamic input = preHandle.uint32ListToRGB3D(preHandle.image);

    if (interpreter != null) {
      int outputSize = 1;
      cls.outputShape.forEach((e) {
        outputSize *= e;
      });
      var output = List.filled(outputSize, 0).reshape(cls.outputShape);
      cls.run([input], output);
      print(output);
      print(facial[min(output[0])]);
      return facial[max(output[0])];
    }
    interpreter.close();
  } on PlatformException {
    print('Failed to get platform version.');
  } catch (e) {
    print(e);
  }
  return "錯誤";
}

class Box extends StatelessWidget {
  Box(
      {@required this.right,
      @required this.top,
      @required this.width,
      @required this.height,
      this.ratio = 1.0}); // screen width : photo width

  Box.square(
      {@required this.right,
      @required this.top,
      @required double side,
      this.ratio = 1.0})
      : width = side,
        height = side;

  final double right;
  final double top;
  final double width;
  final double height;
  final double ratio;

  Widget build(BuildContext context) {
    return Positioned(
        right: right * ratio,
        top: top * ratio,
        width: width * ratio,
        height: height * ratio,
        child: Container(
            decoration: BoxDecoration(
          border:
              Border.all(color: Color.fromRGBO(27, 213, 253, 1.0), width: 3),
        )));
  }
}
