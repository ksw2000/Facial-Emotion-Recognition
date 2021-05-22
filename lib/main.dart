import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:image/image.dart' as img;
import './classifier.dart';
import './prehandle.dart';
import './imageConvert.dart';
import 'package:path_provider/path_provider.dart';

const String facialModel = 'fe93.tflite';
const String facialModel2 = 'fe80.tflite';

const facialLabel = ['驚訝', '怕爆', '覺得噁心', '開心', '傷心', '生氣', '無'];

Future<void> main() async {
  // Ensure that plugin services are initialized so that `availableCameras()`
  // can be called before `runApp()`
  WidgetsFlutterBinding.ensureInitialized();

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
    cameraCtrl = CameraController(widget.camera, ResolutionPreset.high);
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
  List<Widget> defaultWidgetList, widgetList;
  FlutterSoundRecorder myRecorder;
  FlutterSoundPlayer myPlayer;
  double ratio = 1;
  var cameraCtrl;
  bool isNowStream = false;
  bool isNowBusy = false;
  FaceDetector faceDetector_acc;
  FaceDetector faceDetector_fast;

  @override
  void initState() {
    super.initState();
    cameraCtrl = widget.cameraCtrl;
    myRecorder = FlutterSoundRecorder();
    myPlayer = FlutterSoundPlayer();
    faceDetector_acc = GoogleMlKit.vision.faceDetector(FaceDetectorOptions(
      mode: FaceDetectorMode.accurate,
    ));

    faceDetector_fast = GoogleMlKit.vision.faceDetector(FaceDetectorOptions());
  }

  @override
  void dispose() {
    faceDetector_acc.close();
    faceDetector_fast.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ratio =
        MediaQuery.of(context).size.width / cameraCtrl.value.previewSize.height;

    defaultWidgetList = [
      CameraPreview(cameraCtrl),
      Align(
          alignment: Alignment.bottomCenter,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.max,
            children: [
              // detect facial emotion after taking photo
              Container(
                padding: EdgeInsets.all(15),
                decoration:
                    BoxDecoration(shape: BoxShape.circle, color: Colors.blue),
                child: InkWell(
                  child: Icon(Icons.camera_alt, size: 30),
                  onTap: () {
                    facialEmotionDetect();
                  },
                ),
              ),
              SizedBox(width: 10),
              // detect facial emotion real time
              Container(
                padding: EdgeInsets.all(15),
                decoration:
                    BoxDecoration(shape: BoxShape.circle, color: Colors.blue),
                child: InkWell(
                  child: Icon(
                      isNowBusy
                          ? Icons.cached
                          : (isNowStream ? Icons.stop : Icons.stream),
                      size: 30),
                  onTap: () async {
                    if (isNowStream) {
                      setState(() {
                        isNowBusy = true;
                      });
                      await cameraCtrl.stopImageStream();
                    } else {
                      setState(() {
                        isNowBusy = true;
                      });
                      await realTimeFacialEmotionDetect();
                    }
                    setState(() {
                      isNowBusy = false;
                      isNowStream = !isNowStream;
                    });
                  },
                ),
              ),
              SizedBox(width: 10),
              // detect emotion by audio
              Container(
                padding: EdgeInsets.all(15),
                decoration:
                    BoxDecoration(shape: BoxShape.circle, color: Colors.blue),
                child: InkWell(
                  child: Icon(Icons.graphic_eq, size: 30),
                  onTap: () async {
                    var sink = await createFile();
                    var recordingDataController = StreamController<Food>();
                    recordingDataController.stream.listen((buffer) {
                      if (buffer is FoodData) {
                        print(buffer.data);
                        sink.add(buffer.data);
                      }
                    });

                    await myRecorder.openAudioSession();
                    await myRecorder.startRecorder(
                        codec: Codec.pcm16,
                        toStream: recordingDataController.sink);

                    Timer(Duration(seconds: 5), () async {
                      await myRecorder.stopRecorder();
                      await myRecorder.closeAudioSession();
                      recordingDataController.close();
                      sink.close();
                      print("done!");
                      // detect
                      // convert to mfcc
                      if (!myPlayer.isOpen()) {
                        await myPlayer.openAudioSession();
                      }
                      await myPlayer.startPlayer(
                        fromURI: _mPath,
                        codec: Codec.pcm16,
                      );
                    });
                  },
                ),
              ),
            ],
          ))
    ];

    return Stack(children: widgetList ?? defaultWidgetList);
  }

  var _mPath;

  Future<IOSink> createFile() async {
    var dir = await getApplicationDocumentsDirectory();
    _mPath = '${dir.path}/flutter_sound_example.pcm';
    var outputFile = File(_mPath);
    if (outputFile.existsSync()) {
      await outputFile.delete();
    }
    return outputFile.openWrite();
  }

  Future facialEmotionDetect() async {
    widgetList = defaultWidgetList;
    Classifier cls = Classifier();
    Classifier cls2 = Classifier();
    await cls.loadModel(facialModel);
    await cls2.loadModel(facialModel2);

    try {
      // STEP0: Take a shot
      await cameraCtrl.setFlashMode(FlashMode.off);
      XFile savedImg = await cameraCtrl.takePicture();
      img.Image cameraImg =
          img.JpegDecoder().decodeImage(await savedImg.readAsBytes());

      // STEP1: Initialize Firebase faceDetector
      final InputImage visionImage = InputImage.fromFile(File(savedImg.path));
      final List<Face> faces = await faceDetector_acc.processImage(visionImage);

      // STEP2: Get faces
      for (Face face in faces) {
        final Rect boundingBox = face.boundingBox;
        double faceRange = boundingBox.bottom - boundingBox.top;

        // print face range
        print("top: ${boundingBox.top}");
        print("bottom: ${boundingBox.bottom}");
        print("right: ${boundingBox.right}");
        print("left: ${boundingBox.left}");

        img.Image croppedImg = ImagePrehandle.crop(cameraImg,
            y: (cameraImg.width - boundingBox.right).toInt(),
            x: boundingBox.top.toInt(),
            w: faceRange.toInt(),
            h: faceRange.toInt());

        // run model 1
        if (cls.interpreter != null) {
          img.Image resizedImg = ImagePrehandle.resize(croppedImg,
              w: cls.inputShape[1], h: cls.inputShape[2]);

          var input1 = ImagePrehandle.uint32ListToRGB3D(resizedImg);
          var output1 = cls.run([input1]);
          setState(() {
            widgetList.add(Box(
                right: cameraImg.height - boundingBox.right,
                top: boundingBox.top,
                height: boundingBox.bottom - boundingBox.top,
                width: boundingBox.right - boundingBox.left,
                ratio: ratio,
                child: Positioned(
                    top: -35,
                    left: 0,
                    child: Text("${facialLabel[output1]}",
                        style: TextStyle(
                            fontSize: 20, backgroundColor: Colors.blue)))));
          });
        }
        // run model1 with rotation
        if (cls.interpreter != null) {
          img.Image resizedImg = ImagePrehandle.resize(croppedImg,
              w: cls.inputShape[1], h: cls.inputShape[2]);
          img.Image rotationedImg =
              ImagePrehandle.rotation(resizedImg, rotation: 270);

          var input = ImagePrehandle.uint32ListToRGB3D(ImagePrehandle.resize(
              rotationedImg,
              w: cls.inputShape[1],
              h: cls.inputShape[2]));
          print("with rotation");
          print(facialLabel[cls.run([input])]);
        }

        // run model2
        if (cls2.interpreter != null) {
          img.Image resizedImg = ImagePrehandle.resize(croppedImg,
              w: cls2.inputShape[1], h: cls2.inputShape[2]);

          var input = ImagePrehandle.uint32ListToRGB3D(ImagePrehandle.resize(
              resizedImg,
              w: cls2.inputShape[1],
              h: cls2.inputShape[2]));
          print(facialLabel[cls2.run([input])]);
        }
      } // screen width : photo width
    } catch (e) {
      print("facialEmotionDetect() $e");
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

  Future realTimeFacialEmotionDetect() async {
    Classifier cls = Classifier();
    await cls.loadModel(facialModel);
    var lock = false;
    try {
      // STEP0: start camera image stream
      await cameraCtrl.startImageStream((CameraImage cameraImg) async {
        widgetList = defaultWidgetList;
        if (!lock) {
          lock = true;
          // STEP1: Initialize Firebase faceDetector
          final WriteBuffer allBytes = WriteBuffer();
          for (Plane plane in cameraImg.planes) {
            allBytes.putUint8List(plane.bytes);
          }
          final bytes = allBytes.done().buffer.asUint8List();
          final InputImage visionImage = InputImage.fromBytes(
              bytes: bytes,
              inputImageData: InputImageData(
                  size: Size(
                      cameraImg.width.toDouble(), cameraImg.height.toDouble()),
                  imageRotation: InputImageRotation.Rotation_90deg));
          final List<Face> faces =
              await faceDetector_fast.processImage(visionImage);

          img.Image convertedImg = ImageUtils.convertCameraImage(cameraImg);
          // STEP2: Get faces
          for (Face face in faces) {
            final Rect boundingBox = face.boundingBox;
            double faceRange = boundingBox.bottom - boundingBox.top;
            img.Image inputImg = ImagePrehandle.crop(convertedImg,
                y: cameraCtrl.value.previewSize.height.toInt() -
                    boundingBox.right.toInt(),
                x: boundingBox.top.toInt(),
                w: faceRange.toInt(),
                h: faceRange.toInt());

            if (cls.interpreter != null) {
              img.Image resizedImg = ImagePrehandle.resize(inputImg,
                  w: cls.inputShape[1], h: cls.inputShape[2]);

              var input = ImagePrehandle.uint32ListToRGB3D(resizedImg);
              var output = cls.run([input]);
              print(facialLabel[output]);

              setState(() {
                widgetList.add(Box(
                    right: cameraImg.height - boundingBox.right,
                    top: boundingBox.top,
                    height: boundingBox.bottom - boundingBox.top,
                    width: boundingBox.right - boundingBox.left,
                    ratio: ratio,
                    child: Positioned(
                        top: -35,
                        left: 0,
                        child: Text("${facialLabel[output]}",
                            style: TextStyle(
                                fontSize: 20, backgroundColor: Colors.blue)))));
              });
            }
          }
          lock = false;
        }
      });
    } catch (e) {
      print("realTimeFacialEmotionDetect() $e");
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
        child: Stack(clipBehavior: Clip.none, children: [
          Container(
              decoration: BoxDecoration(
            border: Border.all(
              color: Colors.lightBlue,
              width: 3,
            ),
          )),
          child ?? Container()
        ]));
  }
}
