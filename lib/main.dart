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
  PoseDetectorService? _poseDetectorService;
  CameraDescription? _camera;
  bool _isInitializing = true;
  final PosePainter _painter = PosePainter();

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

    _poseDetectorService = PoseDetectorService(_painter);

    _controller = CameraController(
      _camera!,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.nv21,
    );

    await _controller!.initialize();
    _controller!.startImageStream((image) {
      if (mounted) {
        _poseDetectorService!.processImage(image, _camera!).then((_) {
          setState(() {});
        });
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
    _poseDetectorService?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    
    return Scaffold(
      appBar: AppBar(title: const Text('Squat Challenge')),
      body: Column(
        children: [
          Expanded(
            flex: 3,
            child: CameraPreview(
              _controller!,
              child: CustomPaint(painter: _painter),
            ),
          ),
          Expanded(
            flex: 1,
            child: Center(
              child: Text(
                'Приседания: ${_poseDetectorService?.squatCount ?? 0}',
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
              ),
            ),
          )
        ],
      ),
    );
  }
}