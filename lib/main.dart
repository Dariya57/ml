import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'pose_detector_service.dart';

List<CameraDescription> cameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const SquatGameScreen(),
    );
  }
}

class SquatGameScreen extends StatefulWidget {
  const SquatGameScreen({super.key});

  @override
  State<SquatGameScreen> createState() => _SquatGameScreenState();
}

class _SquatGameScreenState extends State<SquatGameScreen> {
  CameraController? _controller;
  CameraDescription? _camera;
  bool _isInitializing = true;
  final PoseDetectorService _poseDetectorService = PoseDetectorService();

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    _camera = cameras.firstWhere(
      (cam) => cam.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );

    _controller = CameraController(
      _camera!,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.nv21,
    );

    await _controller!.initialize();
    _controller!.startImageStream((image) {
      if (mounted) {
        _poseDetectorService.processImage(image, _camera!);
      }
    });

    setState(() {
      _isInitializing = false;
    });
  }

  @override
  void dispose() {
    _controller?.stopImageStream();
    _controller?.dispose();
    _poseDetectorService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    
    return Scaffold(
      appBar: AppBar(title: const Text('Squat Challenge')),
      body: Column(
        children: [
          Expanded(
            flex: 3,
            child: CameraPreview(
              _controller!,
              child: ValueListenableBuilder<PoseData?>(
                valueListenable: _poseDetectorService.poseDataNotifier,
                builder: (context, poseData, child) {
                  return CustomPaint(painter: PosePainter(poseData));
                },
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Center(
              child: ValueListenableBuilder<ExerciseFeedback>(
                valueListenable: _poseDetectorService.feedbackNotifier,
                builder: (context, feedback, child) {
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Приседания: ${feedback.repCount}',
                        style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Качество последнего: ${feedback.qualityScore.toStringAsFixed(0)}%',
                        style: const TextStyle(fontSize: 20),
                      ),
                      const SizedBox(height: 8),
                      if (feedback.feedbackText.isNotEmpty)
                        Text(
                          feedback.feedbackText.join('\n'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: Colors.redAccent,
                              fontSize: 16,
                              fontWeight: FontWeight.bold),
                        ),
                    ],
                  );
                },
              ),
            ),
          )
        ],
      ),
    );
  }
}