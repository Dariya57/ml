import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

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
  CameraController? controller;
  int score = 0;

  @override
  void initState() {
    super.initState();
    initCamera();
  }

  Future<void> initCamera() async {
    // Ищем фронтальную камеру
    final frontCamera = cameras.firstWhere(
          (cam) => cam.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );

    controller = CameraController(frontCamera, ResolutionPreset.medium);
    await controller!.initialize();
    if (mounted) setState(() {});
  }

  void _analyzeExercise() {
    // Заглушка для анализа через OpenCV
    setState(() {
      score += 10; // +10 баллов за "правильное" приседание
    });
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Squat Challenge')),
      body: Column(
        children: [
          Expanded(
            flex: 3,
            child: controller == null || !controller!.value.isInitialized
                ? const Center(child: CircularProgressIndicator())
                : CameraPreview(controller!),
          ),
          Expanded(
            flex: 1,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Очки: $score',
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _analyzeExercise,
                  child: const Text('Сделать присед'),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}