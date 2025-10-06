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

    // Используем Stack, чтобы наложить виджеты друг на друга
    return Scaffold(
      body: Stack(
        fit: StackFit.expand, // Растягиваем Stack на весь экран
        children: [
          // 1. Камера на весь фон
          SizedBox.expand(
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

          // 2. Текст и информация поверх камеры
          Positioned.fill(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween, // Размещаем элементы сверху и снизу
              children: [
                // Верхний блок: Заголовок
                SafeArea(
                  child: Container(
                    padding: const EdgeInsets.all(16.0),
                    child: const Text(
                      'Squat Challenge',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        shadows: [ // ВОТ ТА САМАЯ ЧЕРНАЯ ОБВОДКА
                          Shadow(blurRadius: 1.0, color: Colors.black, offset: Offset(1.0, 1.0)),
                          Shadow(blurRadius: 1.0, color: Colors.black, offset: Offset(-1.0, -1.0)),
                        ],
                      ),
                    ),
                  ),
                ),

                // Нижний блок: Счет и фидбэк
                SafeArea(
                  child: Container(
                    padding: const EdgeInsets.all(24.0),
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.4), // Полупрозрачный фон
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: ValueListenableBuilder<ExerciseFeedback>(
                      valueListenable: _poseDetectorService.feedbackNotifier,
                      builder: (context, feedback, child) {
                        return Column(
                          mainAxisSize: MainAxisSize.min, // Чтобы контейнер не растягивался
                          children: [
                            Text(
                              'Приседания: ${feedback.repCount}',
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                shadows: [Shadow(blurRadius: 2.0, color: Colors.black, offset: Offset(1.0, 1.0))],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Качество последнего: ${feedback.qualityScore.toStringAsFixed(0)}%',
                              style: const TextStyle(fontSize: 20, color: Colors.white70),
                            ),
                            const SizedBox(height: 12),
                            if (feedback.feedbackText.isNotEmpty)
                              Text(
                                feedback.feedbackText.join('\n'),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.redAccent,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  shadows: [Shadow(blurRadius: 2.0, color: Colors.black, offset: Offset(1.0, 1.0))],
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}