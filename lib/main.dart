import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_audio/tflite_audio.dart';
import './classifier.dart';
import './prehandle.dart';
import './imageConvert.dart';

const facialModel = 'fe93.tflite';
const facialModel2 = 'fe80.tflite';

const sampleRate = 44100; //16000;
const recordingLength = 2500; //16000;
const bufferSize = 100; //2000;
const audioModel = 'assets/ae94.tflite'; //decoded_wav_model.tflite';
const audioLabel = 'assets/audio_label.txt'; //decoded_wav_label.txt';

const facialLabel = ['驚訝', '怕爆', '覺得噁心', '開心', '傷心', '生氣', '無'];
CameraDescription camera;

bool realTimeModePrepare =
    false; // whether camera resolution is realTimeModePrepare

Future<void> main() async {
  // Ensure that plugin services are initialized so that `availableCameras()`
  // can be called before `runApp()`
  WidgetsFlutterBinding.ensureInitialized();

  // Obtain a list of the available cameras on the device.
  final cameras = await availableCameras();
  camera = cameras.first;
  runApp(Main());
}

class Main extends StatefulWidget {
  Main();
  _MainState createState() => _MainState();
}

ValueNotifier<CameraController> _cameraCtrl = ValueNotifier<CameraController>(
    CameraController(camera, ResolutionPreset.max));

class _MainState extends State<Main> with AutomaticKeepAliveClientMixin {
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _cameraCtrl.value.dispose();
    super.dispose();
  }

  Widget build(BuildContext context) {
    return MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
            body: SafeArea(
                child: ValueListenableBuilder(
          builder: (context, value, child) {
            return FutureBuilder<void>(
                future: value.initialize(),
                builder: (BuildContext context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.done &&
                      value != null) {
                    return value.value.isInitialized
                        ? Stack(children: [
                            CameraPreview(value),
                            TakePictureScreen()
                          ])
                        : Container();
                  } else {
                    return Center(child: CircularProgressIndicator());
                  }
                });
          },
          valueListenable: _cameraCtrl,
        ))));
  }

  @override
  bool get wantKeepAlive => true;
}

// A screen that allows users to take a picture using a given camera.
class TakePictureScreen extends StatefulWidget {
  const TakePictureScreen();
  @override
  TakePictureScreenState createState() => TakePictureScreenState();
}

class TakePictureScreenState extends State<TakePictureScreen> {
  String text = "";
  List<Widget> defaultWidgetList, widgetList;
  bool isNowBusy = false;
  FaceDetector faceDetectorAcc;
  FaceDetector faceDetectorFast;
  bool isRecording = false;

  @override
  void initState() {
    super.initState();
    TfliteAudio.loadModel(model: audioModel, label: audioLabel);
    faceDetectorAcc = GoogleMlKit.vision.faceDetector(FaceDetectorOptions(
      mode: FaceDetectorMode.accurate,
    ));
    faceDetectorFast = GoogleMlKit.vision.faceDetector(FaceDetectorOptions());
  }

  @override
  void dispose() {
    faceDetectorAcc?.close();
    faceDetectorFast?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    defaultWidgetList = [
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
                          : (_cameraCtrl.value.value.isStreamingImages
                              ? Icons.stop
                              : Icons.stream),
                      size: 30),
                  onTap: () async {
                    if (_cameraCtrl.value.value.isStreamingImages) {
                      setState(() {
                        isNowBusy = true;
                      });

                      await _cameraCtrl.value.stopImageStream();
                      if (realTimeModePrepare) {
                        if (_cameraCtrl.value != null) {
                          _cameraCtrl.value.dispose();
                        }
                        _cameraCtrl.value =
                            CameraController(camera, ResolutionPreset.max);
                        _cameraCtrl.addListener(() {
                          if (mounted) {
                            setState(() {
                              realTimeModePrepare = false;
                            });
                          }
                        });
                      }

                      // reset widgetList
                      setState(() async {
                        widgetList = defaultWidgetList;
                        isNowBusy = false;
                      });
                    } else {
                      setState(() {
                        isNowBusy = true;
                      });
                      await realTimeFacialEmotionDetect();
                      setState(() {
                        isNowBusy = false;
                      });
                    }
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
                  child: Icon((isRecording) ? Icons.stop : Icons.graphic_eq,
                      size: 30),
                  onTap: () {
                    if (!isRecording) {
                      setState(() {
                        isRecording = true;
                      });
                      var result = TfliteAudio.startAudioRecognition(
                        numOfInferences: 1,
                        inputType: 'decodedWav',
                        sampleRate: sampleRate,
                        recordingLength: recordingLength,
                        bufferSize: bufferSize,
                      );
                      result.listen((event) {
                        print("listen");
                        print(event);
                        print(event['recognitionResult']);
                      }).onDone(() {
                        TfliteAudio.stopAudioRecognition();
                        print("TfliteAudio() done!");
                        setState(() {
                          isRecording = false;
                        });
                      });
                    } else {
                      TfliteAudio.stopAudioRecognition();
                      setState(() {
                        isRecording = false;
                      });
                    }
                  },
                ),
              ),
            ],
          ))
    ];

    return Stack(children: widgetList ?? defaultWidgetList);
  }

  Future facialEmotionDetect() async {
    widgetList = defaultWidgetList;
    Classifier cls = Classifier();
    await cls.loadModel(facialModel);

    try {
      // STEP0: Take a shot
      await _cameraCtrl.value.setFlashMode(FlashMode.off);
      XFile savedImg = await _cameraCtrl.value.takePicture();
      img.Image cameraImg =
          img.JpegDecoder().decodeImage(await savedImg.readAsBytes());

      // STEP1: Initialize Firebase faceDetector
      final InputImage visionImage = InputImage.fromFile(File(savedImg.path));
      final List<Face> faces = await faceDetectorAcc.processImage(visionImage);

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
            y: (cameraImg.height - boundingBox.right).toInt(),
            x: boundingBox.top.toInt(),
            w: faceRange.toInt(),
            h: faceRange.toInt());

        // run model 1
        if (cls.interpreter != null) {
          img.Image resizedImg = ImagePrehandle.resize(croppedImg,
              w: cls.inputShape[1], h: cls.inputShape[2]);
          var input = ImagePrehandle.uint32ListToRGB3D(resizedImg);
          var output = cls.run([input]);

          print(facialLabel[output]);
          setState(() {
            widgetList.add(Box(
                x: boundingBox.left,
                y: boundingBox.top,
                height: boundingBox.bottom - boundingBox.top,
                width: boundingBox.right - boundingBox.left,
                ratio: MediaQuery.of(context).size.width / cameraImg.height,
                child: Positioned(
                    top: -50,
                    left: 0,
                    child: Column(children: [
                      Image.memory(img.JpegEncoder().encodeImage(resizedImg)),
                      Text("${facialLabel[output]}",
                          style: TextStyle(
                              fontSize: 20, backgroundColor: Colors.blue))
                    ]))));
          });
        }
      } // screen width : photo width
    } on CameraException {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
            "camera error",
          ),
          action: SnackBarAction(
            label: 'close',
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
            },
          )));
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
    if (!realTimeModePrepare) {
      if (_cameraCtrl.value != null) {
        _cameraCtrl.value.dispose();
      }
      var newCameraCtrl = CameraController(camera, ResolutionPreset.high);
      realTimeModePrepare = true;
      _cameraCtrl.value = newCameraCtrl;
    } else {
      bool lock = false;
      try {
        // STEP0: start camera image stream
        _cameraCtrl.value.startImageStream((CameraImage cameraImg) async {
          widgetList = defaultWidgetList;
          if (!lock) {
            lock = true;
            // STEP1: Initialize Firebase faceDetector
            final WriteBuffer allBytes = WriteBuffer();
            for (Plane plane in cameraImg.planes) {
              allBytes.putUint8List(plane.bytes);
            }
            final InputImage visionImage = InputImage.fromBytes(
                bytes: allBytes.done().buffer.asUint8List(),
                inputImageData: InputImageData(
                    size: Size(cameraImg.width.toDouble(),
                        cameraImg.height.toDouble()),
                    imageRotation: InputImageRotation.Rotation_90deg));
            final List<Face> faces =
                await faceDetectorFast.processImage(visionImage);

            img.Image convertedImg = ImageUtils.convertCameraImage(cameraImg);
            // STEP2: Get faces
            for (Face face in faces) {
              final Rect boundingBox = face.boundingBox;
              double faceRange = boundingBox.bottom - boundingBox.top;
              img.Image inputImg = ImagePrehandle.crop(convertedImg,
                  y: cameraImg.height.toInt() - boundingBox.right.toInt(),
                  x: boundingBox.top.toInt(),
                  w: faceRange.toInt(),
                  h: faceRange.toInt());

              if (cls.interpreter != null) {
                img.Image rotationImg =
                    ImagePrehandle.rotation(inputImg, rotation: 90);

                img.Image resizedImg = ImagePrehandle.resize(rotationImg,
                    w: cls.inputShape[1], h: cls.inputShape[2]);

                var input = ImagePrehandle.uint32ListToRGB3D(resizedImg);
                var output = cls.run([input]);
                print(facialLabel[output]);

                setState(() {
                  widgetList.add(Box.square(
                      x: boundingBox.left,
                      y: boundingBox.top,
                      side: boundingBox.bottom - boundingBox.top,
                      ratio:
                          MediaQuery.of(context).size.width / cameraImg.height,
                      child: Positioned(
                          top: -50,
                          left: 0,
                          child: Column(children: [
                            Image.memory(
                                img.JpegEncoder().encodeImage(resizedImg)),
                            Text("${facialLabel[output]}",
                                style: TextStyle(
                                    fontSize: 20, backgroundColor: Colors.blue))
                          ]))));
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
}

class Box extends StatelessWidget {
  Box(
      {@required this.x,
      @required this.y,
      @required this.width,
      @required this.height,
      this.child,
      this.ratio = 1.0}); // screen width : photo width

  Box.square(
      {@required this.x,
      @required this.y,
      @required double side,
      this.child,
      this.ratio = 1.0})
      : width = side,
        height = side;

  final double x;
  final double y;
  final double width;
  final double height;
  final double ratio;
  final Widget child;
  Widget build(BuildContext context) {
    return Positioned(
        left: x * ratio,
        top: y * ratio,
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
