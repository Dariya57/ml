import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:provider/provider.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../services/pose_detector_service.dart';
import '../painters/pose_painter.dart';
import '../models/data_models.dart';
import '../providers/workout_provider.dart';
import 'results_screen.dart';
import '../utils/strings.dart';

class WorkoutScreen extends StatefulWidget {
  final int targetReps;
  final ExerciseType exerciseType;
  final String exerciseName;

  const WorkoutScreen({
    super.key,
    required this.targetReps,
    required this.exerciseType,
    required this.exerciseName,
  });

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> {
  CameraController? _controller;
  CameraDescription? _camera;
  bool _isInitializing = true;
  late PoseDetectorService _poseDetectorService;

  // Метрики производительности
  double _fps = 0;
  double _ramUsage = 0;
  int _frameCount = 0;
  DateTime _lastFpsUpdate = DateTime.now();
  Timer? _metricsTimer;

  @override
  void initState() {
    super.initState();
    _poseDetectorService = PoseDetectorService();
    _poseDetectorService.feedbackNotifier.addListener(_onFeedback);
    _poseDetectorService.setExercise(widget.exerciseType);
    _initialize();
    _startMetricsMonitoring();
  }

  void _startMetricsMonitoring() {
    _metricsTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      _updateSystemMetrics();
    });
  }

  Future<void> _updateSystemMetrics() async {
    try {
      if (Platform.isAndroid || Platform.isLinux) {
        // Чтение /proc/meminfo для RAM
        final memFile = File('/proc/meminfo');
        if (await memFile.exists()) {
          final lines = await memFile.readAsLines();
          int totalMem = 0;
          int availMem = 0;

          for (var line in lines) {
            if (line.startsWith('MemTotal:')) {
              totalMem = int.tryParse(line.split(RegExp(r'\s+'))[1]) ?? 0;
            } else if (line.startsWith('MemAvailable:')) {
              availMem = int.tryParse(line.split(RegExp(r'\s+'))[1]) ?? 0;
            }
          }

          if (totalMem > 0) {
            _ramUsage = ((totalMem - availMem) / totalMem * 100).clamp(0, 100);
          }
        }
      }

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('Ошибка получения метрик: $e');
    }
  }

  void _updateFps() {
    _frameCount++;
    final now = DateTime.now();
    final diff = now.difference(_lastFpsUpdate).inMilliseconds;

    if (diff >= 1000) {
      if (mounted) {
        setState(() {
          _fps = (_frameCount * 1000) / diff;
          _frameCount = 0;
          _lastFpsUpdate = now;
        });
      }
    }
  }

  void _onFeedback() {
    final feedback = _poseDetectorService.feedbackNotifier.value;
    if (feedback.repCount >= widget.targetReps) {
      _controller?.stopImageStream();
      final results = _poseDetectorService.getWorkoutResults();
      context.read<WorkoutProvider>().completeWorkout(
          widget.exerciseName, feedback.repCount, results['avgQuality']);

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
            builder: (context) => ResultsScreen(
                  reps: feedback.repCount,
                  avgQuality: results['avgQuality'],
                  errorCounts: results['errorCounts'],
                )),
      );
    }
  }

  Future<void> _initialize() async {
    final cameras = await availableCameras();
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
        _updateFps();
        _poseDetectorService.processImage(image, _camera!);
      }
    });

    setState(() {
      _isInitializing = false;
    });
  }

  @override
  void dispose() {
    _metricsTimer?.cancel();
    _poseDetectorService.feedbackNotifier.removeListener(_onFeedback);
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
      body: Stack(
        fit: StackFit.expand,
        children: [
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
          // Метрики производительности
          Positioned(
            top: 50,
            left: 16,
            child: Container(
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'FPS: ${_fps.toStringAsFixed(1)}',
                    style: const TextStyle(
                      color: Colors.greenAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Latency: ${_poseDetectorService.lastLatencyMs.value.toStringAsFixed(1)} ms (avg ${_poseDetectorService.avgLatencyMs.value.toStringAsFixed(1)})',
                    style: const TextStyle(
                      color: Colors.cyanAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'RAM: ${_ramUsage.toStringAsFixed(1)}%',
                    style: const TextStyle(
                      color: Colors.orangeAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
          ValueListenableBuilder<ExerciseFeedback>(
            valueListenable: _poseDetectorService.feedbackNotifier,
            builder: (context, feedback, child) {
              if (!feedback.isCalibrated) {
                return const CalibrationOverlay();
              }
              return WorkoutOverlay(
                  feedback: feedback, targetReps: widget.targetReps);
            },
          )
        ],
      ),
    );
  }
}

class CalibrationOverlay extends StatelessWidget {
  const CalibrationOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withOpacity(0.7),
      child: const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: _CalibrationText(),
        ),
      ),
    );
  }
}

class _CalibrationText extends StatelessWidget {
  const _CalibrationText();
  @override
  Widget build(BuildContext context) {
    final S = AppStrings.of(context);
    return Text(
      '${S.fullBodyRequired}.\n${S.stepBackHint}.',
      textAlign: TextAlign.center,
      style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
    );
  }
}

class WorkoutOverlay extends StatelessWidget {
  final ExerciseFeedback feedback;
  final int targetReps;
  const WorkoutOverlay(
      {super.key, required this.feedback, required this.targetReps});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        SafeArea(
          child: Align(
            alignment: Alignment.topRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ),
        ),
        Text(
          '${feedback.repCount} / $targetReps',
          style: const TextStyle(
            fontSize: 120,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            shadows: [
              Shadow(
                  blurRadius: 10.0, color: Colors.black, offset: Offset(2.0, 2.0))
            ],
          ),
        ),
        const SizedBox(height: 120),
      ],
    );
  }
}