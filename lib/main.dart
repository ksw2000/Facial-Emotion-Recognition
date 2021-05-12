import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_ml_vision/firebase_ml_vision.dart';
import 'package:image/image.dart' as img;
import './classifier.dart';
import './prehandle.dart';
import './imageConvert.dart';

const String facialModel = 'fe90.tflite';
const String facialModel2 = 'fe80.tflite';

var cls = Classifier();
var cls2 = Classifier();

const facial = ['驚訝', '怕爆', '覺得噁心', '開心', '傷心', '生氣', '無'];

Future<void> main() async {
  // Ensure that plugin services are initialized so that `availableCameras()`
  // can be called before `runApp()`
  WidgetsFlutterBinding.ensureInitialized();

  // initialize firebase app
  await Firebase.initializeApp();

  // Obtain a list of the available cameras on the device.
  final cameras = await availableCameras();
  runApp(Main(camera: cameras.first));
}

class Main extends StatefulWidget {
  Main({this.camera});
  final camera;
  _MainState createState() => _MainState();
}

class _MainState extends State<Main> with WidgetsBindingObserver {
  CameraController cameraCtrl;

  Future _initialize() async {
    await cls.loadModel(facialModel);
    await cls2.loadModel(facialModel2);

    cameraCtrl =
        CameraController(widget.camera, ResolutionPreset.high, // 1280x720
            enableAudio: true);
    //imageFormatGroup: ImageFormatGroup.yuv420);
    return cameraCtrl.initialize();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // App state changed before we got the chance to initialize.
    if (cameraCtrl == null || !cameraCtrl.value.isInitialized) {
      return;
    }
    if (state == AppLifecycleState.inactive) {
      cameraCtrl?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      print("------------------------resumed------------------------");
      if (cameraCtrl != null) {
        cameraCtrl =
            CameraController(widget.camera, ResolutionPreset.high, // 1280x720
                enableAudio: true);
      }
    }
  }

  Widget build(BuildContext context) {
    return MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
            body: SafeArea(
                child: FutureBuilder<void>(
                    future: _initialize(),
                    builder: (BuildContext context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.done) {
                        return TakePictureScreen(
                          cameraCtrl: cameraCtrl,
                        );
                      } else {
                        return Center(child: CircularProgressIndicator());
                      }
                    }))));
  }
}

// A screen that allows users to take a picture using a given camera.
class TakePictureScreen extends StatefulWidget {
  final cameraCtrl;
  const TakePictureScreen({this.cameraCtrl});

  @override
  TakePictureScreenState createState() => TakePictureScreenState();
}

class TakePictureScreenState extends State<TakePictureScreen> {
  String text = "";
  //Widget preview, faceRange;
  List<Widget> oriWidgetList, widgetList;
  FlutterSoundRecorder myRecorder;
  FaceDetector faceDetector;
  double ratio = 1;
  var cameraCtrl;
  bool isNowStream = false;

  @override
  void initState() {
    super.initState();
    cameraCtrl = widget.cameraCtrl;
    print("width: ${cameraCtrl.value.previewSize.height}");
    myRecorder = FlutterSoundRecorder();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ratio =
        MediaQuery.of(context).size.width / cameraCtrl.value.previewSize.height;

    oriWidgetList = [
      CameraPreview(cameraCtrl),
      Positioned(
          bottom: 10,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.max,
            children: [
              Container(
                padding: EdgeInsets.all(15),
                decoration:
                    BoxDecoration(shape: BoxShape.circle, color: Colors.blue),
                child: InkWell(
                  child: Icon(Icons.camera_alt, size: 30),
                  onTap: () {
                    shotWithFaceDetect();
                  },
                ),
              ),
              Container(
                padding: EdgeInsets.all(15),
                decoration:
                    BoxDecoration(shape: BoxShape.circle, color: Colors.blue),
                child: InkWell(
                  child:
                      Icon(isNowStream ? Icons.stop : Icons.stream, size: 30),
                  onTap: () async {
                    if (isNowStream) {
                      await cameraCtrl.stopImageStream();
                    } else {
                      await shotWithFaceDetectStream();
                    }
                    setState(() {
                      isNowStream = !isNowStream;
                    });
                  },
                ),
              ),
            ],
          ))
    ];

    return Stack(children: widgetList ?? oriWidgetList);
  }

  Future shotWithFaceDetect() async {
    print("shotWithFaceDetect()");
    widgetList = oriWidgetList;
    try {
      // Attempt to take a picture and log where it's been saved.
      await cameraCtrl.setFlashMode(FlashMode.off);
      XFile savedImage = await cameraCtrl.takePicture();
      final FirebaseVisionImage visionImage =
          FirebaseVisionImage.fromFile(File(savedImage.path));
      faceDetector = FirebaseVision.instance.faceDetector();
      final List<Face> faces = await faceDetector.processImage(visionImage);
      for (Face face in faces) {
        final Rect boundingBox = face.boundingBox;

        print("""
        Face range-
        top: ${boundingBox.top}
        bottom: ${boundingBox.bottom}
        right: ${boundingBox.right}
        left: ${boundingBox.left}
        """);

        double faceRangeSize = boundingBox.bottom - boundingBox.top;
        // boundingBox.right - boundingBox.left ==
        // boundingBox.bottom - boundingBox.top
        img.Image inputImg = ImagePrehandle.crop(
            img.JpegDecoder().decodeImage(await savedImage.readAsBytes()),
            y: cameraCtrl.value.previewSize.height.toInt() -
                boundingBox.right.toInt(),
            x: boundingBox.top.toInt(),
            w: faceRangeSize.toInt(),
            h: faceRangeSize.toInt());

        // run model1
        if (cls.interpreter != null) {
          var input1 = ImagePrehandle.uint32ListToRGB3D(ImagePrehandle.resize(
              inputImg,
              w: cls.inputShape[1],
              h: cls.inputShape[2]));
          var output1 = cls.run([input1]);
          print(facial[output1]);
          setState(() {
            widgetList.add(Box(
                right: cameraCtrl.value.previewSize.height - boundingBox.right,
                top: boundingBox.top,
                height: boundingBox.bottom - boundingBox.top,
                width: boundingBox.right - boundingBox.left,
                ratio: ratio,
                child: Positioned(
                    top: -35,
                    left: 0,
                    child: Text("${facial[output1]}",
                        style: TextStyle(
                            fontSize: 20, backgroundColor: Colors.blue)))));
          });
        }

        // run mode2
        if (cls2.interpreter != null) {
          var input2 = ImagePrehandle.uint32ListToRGB3D(ImagePrehandle.resize(
              inputImg,
              w: cls2.inputShape[1],
              h: cls2.inputShape[2]));
          var output2 = cls2.run([input2]);
          print(facial[output2]);
          setState(() {
            widgetList.add(Box(
                right: cameraCtrl.value.previewSize.height - boundingBox.right,
                top: boundingBox.top,
                height: boundingBox.bottom - boundingBox.top,
                width: boundingBox.right - boundingBox.left,
                ratio: ratio,
                child: Positioned(
                    top: -70,
                    left: 0,
                    child: Text("${facial[output2]}",
                        style: TextStyle(
                            fontSize: 20, backgroundColor: Colors.blue)))));
          });
        }
      } // screen width : photo width

      faceDetector.close();
    } catch (e) {
      print("line317 $e");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
            "$e",
          ),
          action: SnackBarAction(
            label: 'close',
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
            },
          )));
    }
  }

  Future shotWithFaceDetectStream() async {
    print("shotWithFaceDetectStream()");
    var lock = false;

    try {
      // Attempt to take a picture and log where it's been saved.
      await cameraCtrl.startImageStream((CameraImage cameraImage) async {
        widgetList = oriWidgetList;
        if (!lock) {
          lock = true;
          final FirebaseVisionImageMetadata metadata =
              FirebaseVisionImageMetadata(
                  rawFormat: cameraImage.format.raw,
                  size: Size(cameraImage.width.toDouble(),
                      cameraImage.height.toDouble()),
                  planeData: cameraImage.planes
                      .map((currentPlane) => FirebaseVisionImagePlaneMetadata(
                          bytesPerRow: currentPlane.bytesPerRow,
                          height: currentPlane.height,
                          width: currentPlane.width))
                      .toList(),
                  rotation: ImageRotation.rotation90);

          final FirebaseVisionImage visionImage = FirebaseVisionImage.fromBytes(
              cameraImage.planes[0].bytes, metadata);
          faceDetector = FirebaseVision.instance.faceDetector();
          final List<Face> faces = await faceDetector.processImage(visionImage);
          for (Face face in faces) {
            final Rect boundingBox = face.boundingBox;
            print(boundingBox);

            double faceRangeSize = boundingBox.bottom - boundingBox.top;
            // boundingBox.right - boundingBox.left ==
            // boundingBox.bottom - boundingBox.top
            img.Image inputImg = ImagePrehandle.crop(
                ImageUtils.convertCameraImage(cameraImage),
                y: cameraCtrl.value.previewSize.height -
                    boundingBox.right.toInt(),
                x: boundingBox.top.toInt(),
                w: faceRangeSize.toInt(),
                h: faceRangeSize.toInt());

            if (cls2.interpreter != null) {
              inputImg = ImagePrehandle.resize(inputImg,
                  w: cls2.inputShape[1], h: cls2.inputShape[2]);
              var input = ImagePrehandle.uint32ListToRGB3D(inputImg);
              var output = cls2.run([input]);
              print(facial[output]);
              setState(() {
                widgetList.add(Box(
                    right:
                        cameraCtrl.value.previewSize.height - boundingBox.right,
                    top: boundingBox.top,
                    height: boundingBox.bottom - boundingBox.top,
                    width: boundingBox.right - boundingBox.left,
                    ratio: ratio,
                    child: Positioned(
                        top: -35,
                        left: 0,
                        child: Text("${facial[output]}",
                            style: TextStyle(
                                fontSize: 20, backgroundColor: Colors.blue)))));
              });
            }
          }
          faceDetector.close();
          lock = false;
        }
      });
    } catch (e) {
      print("line341 $e");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
            "$e",
          ),
          action: SnackBarAction(
            label: 'close',
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
            },
          )));
    }
  }
}

/*
class PreviewVideo extends StatefulWidget {
  PreviewVideo(this.file);
  final File file;
  _PreviewVideoState createState() => _PreviewVideoState();
}

class _PreviewVideoState extends State<PreviewVideo> {
  VideoPlayerController _controller;
  Future<void> _initializeVideoPlayerFuture;
  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(widget.file);
    // Initialize the controller and store the Future for later use.
    _initializeVideoPlayerFuture = _controller.initialize();

    // Use the controller to loop the video.
    _controller.setLooping(true);
  }

  @override
  void dispose() {
    super.dispose();
    _controller.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _initializeVideoPlayerFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          // If the VideoPlayerController has finished initialization, use
          // the data it provides to limit the aspect ratio of the VideoPlayer.
          return Scaffold(
            body: Center(
              child: _controller.value.isInitialized
                  ? AspectRatio(
                      aspectRatio: _controller.value.aspectRatio,
                      child: VideoPlayer(_controller),
                    )
                  : Container(),
            ),
            floatingActionButton: FloatingActionButton(
              onPressed: () {
                setState(() {
                  _controller.value.isPlaying
                      ? _controller.pause()
                      : _controller.play();
                });
              },
              child: Icon(
                _controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
              ),
            ),
          );
        } else {
          // If the VideoPlayerController is still initializing, show a
          // loading spinner.
          return Center(child: CircularProgressIndicator());
        }
      },
    );
  }
}
*/

class Box extends StatelessWidget {
  Box(
      {@required this.right,
      @required this.top,
      @required this.width,
      @required this.height,
      this.child,
      this.ratio = 1.0}); // screen width : photo width

  Box.square(
      {@required this.right,
      @required this.top,
      @required double side,
      this.child,
      this.ratio = 1.0})
      : width = side,
        height = side;

  final double right;
  final double top;
  final double width;
  final double height;
  final double ratio;
  final Widget child;
  Widget build(BuildContext context) {
    return Positioned(
        right: right * ratio,
        top: top * ratio,
        width: width * ratio,
        height: height * ratio,
        child: Stack(overflow: Overflow.visible, children: [
          Container(
              decoration: BoxDecoration(
            border: Border.all(
              color: Color.fromRGBO(27, 213, 253, 1.0),
              width: 3,
            ),
          )),
          child ?? Container()
        ]));
  }
}
