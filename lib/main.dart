import 'dart:async';
import 'dart:io';
import 'package:opencv/opencv.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart' as tfl;
import 'package:image/image.dart' as img;
import 'package:liar_detection_app/classifier.dart';
import 'package:liar_detection_app/prehandle.dart';

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
  CameraController _controller;
  Future<void> _initializeControllerFuture;
  String text;

  @override
  void initState() {
    super.initState();
    // To display the current output from the Camera,
    // create a CameraController.
    _controller = CameraController(
        // Get a specific camera from the list of available cameras.
        widget.camera,
        // Define the resolution to use.
        ResolutionPreset.high,
        enableAudio: true);

    // Next, initialize the controller. This returns a Future.
    _initializeControllerFuture = _controller.initialize();
    text = "";
  }

  @override
  void dispose() {
    // Dispose of the controller when the widget is disposed.
    //_controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
          child: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (BuildContext context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            // If the Future is complete, display the preview.
            return Stack(
              children: [
                CameraPreview(_controller),
                Box.square(top: 0.0, right: 0.0, side: 50.0),
                Center(child: Text(text ?? "", style: TextStyle(fontSize: 20)))
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
          // Take the Picture in a try / catch block. If anything goes wrong,
          // catch the error.
          try {
            // Ensure that the camera is initialized.
            await _initializeControllerFuture;

            // Attempt to take a picture and log where it's been saved.
            await _controller.takePicture().then((XFile file) async {
              if (mounted) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CallModel(image: file),
                  ),
                );
              }
            });
          } catch (e) {
            // If an error occurs, log the error to the console.
            print(e);
          }
        },
      ),
    );
  }
}

// A widget that displays the picture taken by the user.
class CallModel extends StatefulWidget {
  const CallModel({this.image});
  final XFile image;

  @override
  _CallModelState createState() => _CallModelState();
}

class _CallModelState extends State<CallModel> {
  XFile imageFile;
  Widget previewCroppedImage = Container();

  @override
  initState() {
    super.initState();
    imageFile = widget.image;
  }

  Future<String> run() async {
    try {
      /// Pixels are encoded into 4-byte Uint32 integers in #AABBGGRR channel order.
      String ret = "";
      ImagePrehandle preHandle = ImagePrehandle(await imageFile.readAsBytes());
      Classifier cls = Classifier();
      await cls.loadModel('fe.tflite').then((interpreter) {
        print("loadmodel()");
        print("input shape: ${cls.inputShape}");
        print("output shape: ${cls.outputShape}");

        // 3D list
        img.Image croppedImage = preHandle.crop(preHandle.image,
            x: 0, y: 0, w: cls.inputShape[1], h: cls.inputShape[2]);
        dynamic input = preHandle.reshape(
            preHandle.uint32ListToRGBFloat(croppedImage),
            cls.inputShape[1],
            cls.inputShape[2]);
        previewCroppedImage =
            Image.memory(img.JpegEncoder().encodeImage(croppedImage));

        if (interpreter != null) {
          print("run");
          int outputSize = 1;
          cls.outputShape.forEach((e) {
            outputSize *= e;
          });
          var output = List.filled(outputSize, 0).reshape(cls.outputShape);
          cls.run([input], output);
          var res = cls.decide(output[0]);
          ret = "情緒 ${res["label"]}號 ${res["val"] * 100 ~/ res["sum"]}%";
          print(ret);
        }
      });

      return ret;
      // var res = await ImgProc.gaussianBlur(imageByte, [45, 45], 0);
      // var res2 =
      // await ImgProc.resize(imageByte, [500, 500], 0, 0, ImgProc.interArea);
    } on PlatformException {
      print('Failed to get platform version.');
    } catch (e) {
      print(e);
    }
    return "錯誤";
  }

  @override
  Widget build(BuildContext context) {
    var _ctrl = ScrollController();
    return Scaffold(
        appBar: AppBar(title: Text('Show result')),
        // The image is stored as a file on the device. Use the `Image.file`
        // constructor with the given path to display the image.
        body: Scrollbar(
            controller: _ctrl,
            child: SingleChildScrollView(
                controller: _ctrl,
                child: Column(
                  children: [
                    Image.file(File(imageFile.path)),
                    FutureBuilder(
                        future: run(),
                        builder: (buildContext, snapshot) {
                          if (snapshot.hasData) {
                            print(snapshot.data);
                            return previewCroppedImage;
                            // Image.memory(croppedImage?.getBytes()
                            // return Image.memory(
                            // img.JpegEncoder().encodeImage(preHandle.imgDecode));
                          } else {
                            return CircularProgressIndicator();
                          }
                        })
                  ],
                ))));
  }
}

class Box extends StatelessWidget {
  double right;
  double top;
  double width;
  double height;
  Box(
      {@required this.right,
      @required this.top,
      @required this.width,
      @required this.height});

  Box.square({
    @required this.right,
    @required this.top,
    @required side,
  }) {
    width = side;
    height = side;
  }

  Widget build(BuildContext context) {
    return Positioned(
        right: right,
        top: top,
        width: width,
        height: height,
        child: Container(
            decoration: BoxDecoration(
          border:
              Border.all(color: Color.fromRGBO(27, 213, 253, 1.0), width: 3),
        )));
  }
}
