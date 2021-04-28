import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:tflite_flutter/tflite_flutter.dart' as tfl;
import 'package:flutter_sound/flutter_sound.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:video_player/video_player.dart';
import 'package:firebase_ml_vision/firebase_ml_vision.dart';
import 'package:image/image.dart' as img;
import './classifier.dart';
import './prehandle.dart';

const int shotSize = 500;
const int cameraWidth = 720;
const int cameraHeight = 1280;
var cls = Classifier();

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

class _MainState extends State<Main> {
  CameraController cameraCtrl;

  Future _initialize() async {
    await cls.loadModel('fe90.tflite');
    cameraCtrl =
        CameraController(widget.camera, ResolutionPreset.high, // 1280x720
            enableAudio: true);
    //imageFormatGroup: ImageFormatGroup.yuv420);
    return cameraCtrl.initialize();
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
  Widget preview, faceRange;
  List<Widget> oriWidgetList, widgetList;
  FlutterSoundRecorder myRecorder;
  FaceDetector faceDetector;
  double ratio = 1;
  var cameraCtrl;

  @override
  void initState() {
    super.initState();
    cameraCtrl = widget.cameraCtrl;
    myRecorder = FlutterSoundRecorder();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ratio = MediaQuery.of(context).size.width / cameraWidth;

    oriWidgetList = [
      CameraPreview(cameraCtrl),
      /*
      (preview != null)
          ? Align(alignment: Alignment.topRight, child: preview)
          : Container(),

       */
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
                  child: Icon(Icons.stream, size: 30),
                  onTap: () async {
                    shotWithFaceDetectStream();
                  },
                ),
              ),
              /***********************************************
                         * REAL - TIME MODE
                         *
                         * Container(
                            padding: EdgeInsets.all(15),
                            decoration: BoxDecoration(
                            shape: BoxShape.circle, color: Colors.blue),
                            child: InkWell(
                            child: Icon(Icons.stream, size: 30),
                            onTap: () {
                            shotStream(top, right);
                            },
                            ),
                            ),
                            Container(
                            padding: EdgeInsets.all(15),
                            decoration: BoxDecoration(
                            shape: BoxShape.circle, color: Colors.blue),
                            child: InkWell(
                            child: Icon(Icons.stop, size: 30),
                            onTap: () {
                            stopStream();
                            },
                            ),
                            ),

                         ************************************************/
              // Container(
              //   padding: EdgeInsets.all(15),
              //   decoration: BoxDecoration(
              //       shape: BoxShape.circle, color: Colors.blue),
              //   child: InkWell(
              //     child: Icon(Icons.circle, size: 30),
              //     onTap: () {
              //       myRecorder.openAudioSession().then((_) {
              //         myRecorder.startRecorder();
              //         //myRecorder.closeAudioSession();
              //       });
              //     },
              //   ),
              // ),
              // Container(
              //   padding: EdgeInsets.all(15),
              //   decoration: BoxDecoration(
              //       shape: BoxShape.circle, color: Colors.blue),
              //   child: InkWell(
              //     child: Icon(Icons.stop, size: 30),
              //     onTap: () {
              //       myRecorder.stopRecorder();
              //       myRecorder.closeAudioSession();
              //     },
              //   ),
              // ),
              Container(
                padding: EdgeInsets.all(15),
                decoration:
                    BoxDecoration(shape: BoxShape.circle, color: Colors.blue),
                child: InkWell(
                  child: Icon(Icons.stop, size: 30),
                  onTap: () async {
                    await cameraCtrl.stopImageStream();
                  },
                ),
              ),
            ],
          ))
    ];

    return Center(child: Stack(children: widgetList));
  }

  Future shotStream(double top, double right) async {
    try {
      // Ensure that the camera is initialized.
      await cameraCtrl.startImageStream((CameraImage cameraImage) {
        ImagePrehandle.convertYUV420(cameraImage);
      });
    } catch (e) {
      print(e);
    }
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
        img.Image inputImg =
            img.JpegDecoder().decodeImage(await savedImage.readAsBytes());
        inputImg = ImagePrehandle.crop(inputImg,
            y: cameraWidth - boundingBox.right.toInt(),
            x: boundingBox.top.toInt(),
            w: faceRangeSize.toInt(),
            h: faceRangeSize.toInt());
        inputImg = ImagePrehandle.resize(inputImg,
            w: cls.inputShape[1], h: cls.inputShape[2]);

        // setState(() {
        //   preview = Image.memory(img.JpegEncoder().encodeImage(inputImg));
        // });

        // run model
        if (cls.interpreter != null) {
          int outputSize = 1;
          cls.outputShape.forEach((e) {
            outputSize *= e;
          });
          var input = ImagePrehandle.uint32ListToRGB3D(inputImg);
          var output = List.filled(outputSize, 0).reshape(cls.outputShape);
          cls.run([input], output);
          print(facial[max(output[0])]);
          setState(() {
            widgetList.add(Box(
                right: cameraWidth - boundingBox.right,
                top: boundingBox.top,
                height: boundingBox.bottom - boundingBox.top,
                width: boundingBox.right - boundingBox.left,
                ratio: ratio,
                child: Positioned(
                    top: -35,
                    left: 0,
                    child: Text("${facial[max(output[0])]}",
                        style: TextStyle(
                            fontSize: 20, backgroundColor: Colors.blue)))));
          });
          /*
          setState(() {
            faceRange = Box(
                right: cameraWidth - boundingBox.right,
                top: boundingBox.top,
                height: boundingBox.bottom - boundingBox.top,
                width: boundingBox.right - boundingBox.left,
                ratio: ratio,
                child: Positioned(
                    top: -35,
                    left: 0,
                    child: Text("${facial[max(output[0])]}",
                        style: TextStyle(
                            fontSize: 20, backgroundColor: Colors.blue))));
          });
           */
        }
      } // screen width : photo width

      faceDetector.close();
    } catch (e) {
      print("line299 $e");
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
    print("shotWithFaceDetect()");
    try {
      // Attempt to take a picture and log where it's been saved.
      await cameraCtrl.startImageStream((CameraImage cameraImage) async {
        if (mounted) {
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
            // final double rotY = face
            //     .headEulerAngleY; // Head is rotated to the right rotY degrees
            // final double rotZ =
            //     face.headEulerAngleZ; // Head is tilted sideways rotZ degrees
            // // If landmark detection was enabled with FaceDetectorOptions (mouth, ears,
            // // eyes, cheeks, and nose available):
            // final FaceLandmark leftEar =
            //     face.getLandmark(FaceLandmarkType.leftEar);
            // if (leftEar != null) {
            //   final Offset leftEarPos = leftEar.position;
            // }
            // // If classification was enabled with FaceDetectorOptions:
            // if (face.smilingProbability != null) {
            //   final double smileProb = face.smilingProbability;
            // }
            // // If face tracking was enabled with FaceDetectorOptions:
            // if (face.trackingId != null) {
            //   final int id = face.trackingId;
            // }
          }
          faceDetector.close();
        }
      });
    } catch (e) {
      print(e);
    }
  }
}

class FaceRange extends StatefulWidget {
  _FaceRangeState createState() => _FaceRangeState();
}

class _FaceRangeState extends State<FaceRange> {
  Widget build(BuildContext context) {
    return Container();
  }
}

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
