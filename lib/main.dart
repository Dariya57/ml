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
  int _squatCount = 0;

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

    // Подписываемся на обновления от Painter
    _painter.addListener(() {
      if (mounted) {
        setState(() {
          _squatCount = _poseDetectorService!.squatCount;
        });
      }
    });

    _controller = CameraController(
      _camera!,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.nv21,
    );

    await _controller!.initialize();
    _controller!.startImageStream((image) {
      _poseDetectorService!.processImage(image, _camera!);
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
    _painter.removeListener(() {}); // Отписываемся от слушателя
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
            // Используем AnimatedBuilder, чтобы перерисовывать только то, что нужно
            child: AnimatedBuilder(
              animation: _painter,
              builder: (context, child) {
                return CameraPreview(
                  _controller!,
                  child: CustomPaint(painter: _painter),
                );
              },
            ),
          ),
          Expanded(
            flex: 1,
            child: Center(
              child: Text(
                'Приседания: $_squatCount',
                style:
                    const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
              ),
            ),
          )
        ],
      ),
    );
  }
}