import 'dart:math';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';
import '../models/data_models.dart';

class PoseDetectorService {
  final PoseDetector _poseDetector;
  bool _isProcessing = false;
  String _currentStage = 'up';
  bool _isCalibrated = false;
  final List<double> _qualityScores = [];
  final List<String> _errorLog = [];
  
  late ExerciseType _currentExercise;

  // НОВЫЕ ПОЛЯ ДЛЯ FPS
  int _frameCounter = 0;
  int _lastTimestamp = DateTime.now().millisecondsSinceEpoch;
  final ValueNotifier<int> fpsNotifier = ValueNotifier(0);
  // КОНЕЦ НОВЫХ ПОЛЕЙ

  // Метрики задержки обработки кадра
  final ValueNotifier<double> lastLatencyMs = ValueNotifier(0); // последний кадр
  final ValueNotifier<double> avgLatencyMs = ValueNotifier(0); // скользящее среднее
  double _latencyEma = 0;
  int _latencySamples = 0;

  // Адаптивный размер скелета (EMA доли высоты bbox)
  double _sizeEma = 0;
  int _sizeSamples = 0;

  // Одноразовая проверка полной видимости для pushups/crunches
  bool _initialVisibilityOk = false;

  final ValueNotifier<ExerciseFeedback> feedbackNotifier = ValueNotifier(ExerciseFeedback());
  final ValueNotifier<PoseData?> poseDataNotifier = ValueNotifier(null);

  PoseDetectorService()
      : _poseDetector = PoseDetector(
          options: PoseDetectorOptions(model: PoseDetectionModel.accurate, mode: PoseDetectionMode.stream),
        );

  void setExercise(ExerciseType exercise) {
    _currentExercise = exercise;
    _currentStage = exercise == ExerciseType.crunches ? 'down' : 'up';
    _qualityScores.clear();
    _errorLog.clear();
    _initialVisibilityOk = false;
    feedbackNotifier.value = ExerciseFeedback(isCalibrated: feedbackNotifier.value.isCalibrated);
  }

  Future<void> processImage(CameraImage image, CameraDescription camera) async {
    if (_isProcessing) return;
    _isProcessing = true;
    final t0 = DateTime.now().microsecondsSinceEpoch;

    // ЛОГИКА ПОДСЧЕТА FPS
    final currentTime = DateTime.now().millisecondsSinceEpoch;
    _frameCounter++;
    if (currentTime - _lastTimestamp >= 1000) {
      fpsNotifier.value = _frameCounter;
      _frameCounter = 0;
      _lastTimestamp = currentTime;
    }
    // КОНЕЦ ЛОГИКИ FPS

    final inputImage = _inputImageFromCameraImage(image, camera);
    if (inputImage == null) {
      _isProcessing = false; return;
    }

    final poses = await _poseDetector.processImage(inputImage);
    poseDataNotifier.value = PoseData(
      pose: poses.isNotEmpty ? poses.first : null,
      imageSize: Size(image.width.toDouble(), image.height.toDouble()),
      rotation: inputImage.metadata!.rotation,
      cameraLensDirection: camera.lensDirection,
    );

    if (poses.isNotEmpty) {
      final pose = poses.first;
      var imgW = image.width.toDouble();
      var imgH = image.height.toDouble();
      final rot = inputImage.metadata!.rotation;
      if (rot == InputImageRotation.rotation90deg || rot == InputImageRotation.rotation270deg) {
        final t = imgW; imgW = imgH; imgH = t;
      }
      // Для pushups/crunches — требуем полную видимость только один раз в начале,
      // затем не блокируем по кадрированию; для squats продолжаем обычную проверку
      final frameSize = Size(imgW, imgH);
      if (_currentExercise == ExerciseType.pushups || _currentExercise == ExerciseType.crunches) {
        if (!_initialVisibilityOk) {
          if (!_isInitialVisibilityOk(pose, frameSize)) {
            _isCalibrated = false;
            feedbackNotifier.value = ExerciseFeedback(isCalibrated: false, repCount: feedbackNotifier.value.repCount);
            _isProcessing = false; return;
          }
          _initialVisibilityOk = true;
        }
      } else {
        // squats: мягкая проверка кадрирования на каждом кадре
        if (!_isFramingOk(pose, frameSize)) {
          _isCalibrated = false;
          feedbackNotifier.value = ExerciseFeedback(isCalibrated: false, repCount: feedbackNotifier.value.repCount);
          _isProcessing = false; return;
        }
      }

      if (!_isCalibrated) {
        _calibrate(pose);
      } else {
        _analyzePose(pose);
      }
    }
    // Обновляем метрики задержки
    final t1 = DateTime.now().microsecondsSinceEpoch;
    final latencyMs = (t1 - t0) / 1000.0;
    lastLatencyMs.value = latencyMs;
    _latencySamples += 1;
    // EMA с альфой в зависимости от кол-ва сэмплов (быстрое схождение сначала)
    final alpha = _latencySamples < 20 ? 0.3 : 0.1;
    _latencyEma = _latencySamples == 1 ? latencyMs : (_latencyEma * (1 - alpha) + latencyMs * alpha);
    avgLatencyMs.value = _latencyEma;

    _isProcessing = false;
  }
  
  // ... (остальной код _analyzePose, _calibrate и т.д. остается без изменений)
  void _analyzePose(Pose pose) {
    switch (_currentExercise) {
      case ExerciseType.squats: _analyzeSquat(pose); break;
      case ExerciseType.pushups: _analyzePushup(pose); break;
      case ExerciseType.crunches: _analyzeCrunch(pose); break;
    }
  }

  void _calibrate(Pose pose) {
    // Упражнение-зависимая калибровка с частичной видимостью (degrade gracefully)
    List<PoseLandmarkType> group;
    int minRequired;
    switch (_currentExercise) {
      case ExerciseType.squats:
        group = [
          PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder,
          PoseLandmarkType.leftHip, PoseLandmarkType.rightHip,
          PoseLandmarkType.leftKnee, PoseLandmarkType.rightKnee,
          PoseLandmarkType.leftAnkle, PoseLandmarkType.rightAnkle,
        ];
        minRequired = 5; // из 8
        break;
      case ExerciseType.pushups:
        group = [
          PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder,
          PoseLandmarkType.leftElbow, PoseLandmarkType.rightElbow,
          PoseLandmarkType.leftWrist, PoseLandmarkType.rightWrist,
          PoseLandmarkType.leftHip, PoseLandmarkType.rightHip,
        ];
        minRequired = 5; // из 8
        break;
      case ExerciseType.crunches:
        group = [
          PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder,
          PoseLandmarkType.leftHip, PoseLandmarkType.rightHip,
          PoseLandmarkType.leftEar, PoseLandmarkType.rightEar,
        ];
        minRequired = 4; // из 6
        break;
    }
    int visible = 0;
    for (final t in group) {
      final p = pose.landmarks[t];
      if (p != null && p.likelihood > 0.25) visible++;
    }
    _isCalibrated = visible >= minRequired;
    feedbackNotifier.value = ExerciseFeedback(isCalibrated: _isCalibrated, repCount: feedbackNotifier.value.repCount);
  }

  bool _isFullBodyVisible(Pose pose, Size imageSize) {
    final lm = pose.landmarks;

    if (_currentExercise == ExerciseType.pushups) {
      // Для отжиманий достаточно устойчиво видеть верх тела
      final sL = lm[PoseLandmarkType.leftShoulder];
      final sR = lm[PoseLandmarkType.rightShoulder];
      final eL = lm[PoseLandmarkType.leftElbow];
      final eR = lm[PoseLandmarkType.rightElbow];
      final wL = lm[PoseLandmarkType.leftWrist];
      final wR = lm[PoseLandmarkType.rightWrist];
      final hipL = lm[PoseLandmarkType.leftHip];
      final hipR = lm[PoseLandmarkType.rightHip];

      // Требуем наличие хотя бы по одной стороне (лево/право) плечо-локоть-запястье
      final leftChainOk = [sL, eL, wL].every((p) => p != null && p.likelihood > 0.3);
      final rightChainOk = [sR, eR, wR].every((p) => p != null && p.likelihood > 0.3);
      if (!(leftChainOk || rightChainOk)) return false;

      // Торс в кадре по бедрам (если видны). Это необязательно, но поможет отсечь крайние случаи
      final torsoPoints = [sL, sR, hipL, hipR].whereType<PoseLandmark>().toList();
      if (torsoPoints.isNotEmpty) {
        final minX = torsoPoints.map((p) => p.x).reduce(min);
        final maxX = torsoPoints.map((p) => p.x).reduce(max);
        final minY = torsoPoints.map((p) => p.y).reduce(min);
        final maxY = torsoPoints.map((p) => p.y).reduce(max);
        final margin = 0.02; // Очень мягкие поля
        if (minX < imageSize.width * margin || maxX > imageSize.width * (1 - margin)) return false;
        if (minY < imageSize.height * margin || maxY > imageSize.height * (1 - margin)) return false;
      }
      return true;
    }

    // По умолчанию (присед, пресс): проверяем большую часть тела
    final head = lm[PoseLandmarkType.leftEar] ?? lm[PoseLandmarkType.rightEar] ?? lm[PoseLandmarkType.leftEye] ?? lm[PoseLandmarkType.rightEye];
    final ankleL = lm[PoseLandmarkType.leftAnkle] ?? lm[PoseLandmarkType.leftKnee];
    final ankleR = lm[PoseLandmarkType.rightAnkle] ?? lm[PoseLandmarkType.rightKnee];
    final shoulderL = lm[PoseLandmarkType.leftShoulder];
    final shoulderR = lm[PoseLandmarkType.rightShoulder];
    if (head == null || ankleL == null || ankleR == null || shoulderL == null || shoulderR == null) return false;
    final xs = [head.x, ankleL.x, ankleR.x, shoulderL.x, shoulderR.x];
    final ys = [head.y, ankleL.y, ankleR.y, shoulderL.y, shoulderR.y];
    final minX = xs.reduce((a,b)=>a<b?a:b);
    final maxX = xs.reduce((a,b)=>a>b?a:b);
    final minY = ys.reduce((a,b)=>a<b?a:b);
    final maxY = ys.reduce((a,b)=>a>b?a:b);
    final boxH = (maxY - minY).abs();
    final heightFrac = boxH / imageSize.height;
    if (heightFrac < 0.35) return false; // немного мягче
    if (heightFrac > 0.98) return false;
    final margin = 0.08;
    if (minX < imageSize.width * margin || maxX > imageSize.width * (1 - margin)) return false;
    if (minY < imageSize.height * margin || maxY > imageSize.height * (1 - margin)) return false;
    return true;
  }

  // Мягкая проверка: расстояние/центрирование по ключевым точкам, зависит от упражнения
  bool _isFramingOk(Pose pose, Size imageSize) {
    final lm = pose.landmarks;
    final points = <PoseLandmark?>[];
    switch (_currentExercise) {
      case ExerciseType.squats:
        points.addAll([
          lm[PoseLandmarkType.leftShoulder], lm[PoseLandmarkType.rightShoulder],
          lm[PoseLandmarkType.leftHip], lm[PoseLandmarkType.rightHip],
          lm[PoseLandmarkType.leftKnee], lm[PoseLandmarkType.rightKnee],
        ]);
        break;
      case ExerciseType.pushups:
        points.addAll([
          lm[PoseLandmarkType.leftShoulder], lm[PoseLandmarkType.rightShoulder],
          lm[PoseLandmarkType.leftWrist], lm[PoseLandmarkType.rightWrist],
          lm[PoseLandmarkType.leftHip], lm[PoseLandmarkType.rightHip],
        ]);
        break;
      case ExerciseType.crunches:
        points.addAll([
          lm[PoseLandmarkType.leftShoulder], lm[PoseLandmarkType.rightShoulder],
          lm[PoseLandmarkType.leftHip], lm[PoseLandmarkType.rightHip],
          lm[PoseLandmarkType.leftKnee], lm[PoseLandmarkType.rightKnee],
        ]);
        break;
    }

    final valid = points.whereType<PoseLandmark>().toList();
    // Если слишком мало точек, не блокируем — дадим шансы трекингу стабилизироваться
    if (valid.length < 3) return true;

    double minX = valid.first.x, maxX = valid.first.x, minY = valid.first.y, maxY = valid.first.y;
    for (final p in valid) {
      if (p.x < minX) minX = p.x; if (p.x > maxX) maxX = p.x;
      if (p.y < minY) minY = p.y; if (p.y > maxY) maxY = p.y;
    }
    final boxH = (maxY - minY).abs();
    final heightFrac = boxH / imageSize.height;

    // Обновляем EMA размера скелета (быстрое схождение в начале)
    _sizeSamples += 1;
    final sizeAlpha = _sizeSamples < 20 ? 0.3 : 0.1;
    _sizeEma = _sizeSamples == 1 ? heightFrac : (_sizeEma * (1 - sizeAlpha) + heightFrac * sizeAlpha);

    double minFrac, maxFrac, margin;
    switch (_currentExercise) {
      case ExerciseType.squats:
        minFrac = 0.30; maxFrac = 0.96; margin = 0.05; break;
      case ExerciseType.pushups:
        minFrac = 0.30; maxFrac = 0.95; margin = 0.05; break;
      case ExerciseType.crunches:
        minFrac = 0.30; maxFrac = 0.85; margin = 0.08; break;
    }
    // Адаптивные границы вокруг среднего размера, чтобы не блокировать стабильную дистанцию
    final minAdaptive = (_sizeSamples >= 3) ? (_sizeEma * 0.6) : minFrac;
    final maxAdaptive = (_sizeSamples >= 3) ? (_sizeEma * 1.8) : maxFrac;
    final lower = min(minFrac, minAdaptive);
    final upper = max(maxFrac, maxAdaptive);
    if (heightFrac < lower || heightFrac > upper) return false;
    if (minX < imageSize.width * margin || maxX > imageSize.width * (1 - margin)) return false;
    if (minY < imageSize.height * margin || maxY > imageSize.height * (1 - margin)) return false;
    return true;
  }

  // Одноразовая проверка полной видимости для pushups/crunches
  bool _isInitialVisibilityOk(Pose pose, Size imageSize) {
    final lm = pose.landmarks;
    double minX, maxX, minY, maxY;

    if (_currentExercise == ExerciseType.pushups) {
      final sL = lm[PoseLandmarkType.leftShoulder];
      final sR = lm[PoseLandmarkType.rightShoulder];
      final eL = lm[PoseLandmarkType.leftElbow];
      final eR = lm[PoseLandmarkType.rightElbow];
      final wL = lm[PoseLandmarkType.leftWrist];
      final wR = lm[PoseLandmarkType.rightWrist];
      if ([sL, sR, eL, eR, wL, wR].any((p) => p == null || p!.likelihood <= 0.3)) return false;
      final pts = [sL!, sR!, eL!, eR!, wL!, wR!];
      minX = pts.map((p) => p.x).reduce(min);
      maxX = pts.map((p) => p.x).reduce(max);
      minY = pts.map((p) => p.y).reduce(min);
      maxY = pts.map((p) => p.y).reduce(max);
      final hFrac = (maxY - minY).abs() / imageSize.height;
      if (hFrac < 0.28 || hFrac > 0.97) return false;
      final margin = 0.05;
      if (minX < imageSize.width * margin || maxX > imageSize.width * (1 - margin)) return false;
      if (minY < imageSize.height * margin || maxY > imageSize.height * (1 - margin)) return false;
      return true;
    }

    // crunches
    final shL = lm[PoseLandmarkType.leftShoulder];
    final shR = lm[PoseLandmarkType.rightShoulder];
    final hipL = lm[PoseLandmarkType.leftHip];
    final hipR = lm[PoseLandmarkType.rightHip];
    final knL = lm[PoseLandmarkType.leftKnee];
    final knR = lm[PoseLandmarkType.rightKnee];
    // требуем видеть хотя бы плечи и бёдра по обе стороны, колени приветствуются
    if ([shL, shR, hipL, hipR].any((p) => p == null || p!.likelihood <= 0.3)) return false;
    final pts = [shL!, shR!, hipL!, hipR!, if (knL != null) knL, if (knR != null) knR].whereType<PoseLandmark>().toList();
    minX = pts.map((p) => p.x).reduce(min);
    maxX = pts.map((p) => p.x).reduce(max);
    minY = pts.map((p) => p.y).reduce(min);
    maxY = pts.map((p) => p.y).reduce(max);
    final hFrac = (maxY - minY).abs() / imageSize.height;
    if (hFrac < 0.25 || hFrac > 0.95) return false;
    final margin = 0.08;
    if (minX < imageSize.width * margin || maxX > imageSize.width * (1 - margin)) return false;
    if (minY < imageSize.height * margin || maxY > imageSize.height * (1 - margin)) return false;
    return true;
  }

  void _analyzeSquat(Pose pose) {
    final lm = pose.landmarks;
    final lHip = lm[PoseLandmarkType.leftHip];
    final rHip = lm[PoseLandmarkType.rightHip];
    final lKnee = lm[PoseLandmarkType.leftKnee];
    final rKnee = lm[PoseLandmarkType.rightKnee];
    final lAnkle = lm[PoseLandmarkType.leftAnkle];
    final rAnkle = lm[PoseLandmarkType.rightAnkle];
    final lShoulder = lm[PoseLandmarkType.leftShoulder];
    final rShoulder = lm[PoseLandmarkType.rightShoulder];

    // Если видны обе ноги — используем двустороннюю логику
    if (lHip != null && rHip != null && lKnee != null && rKnee != null && lAnkle != null && rAnkle != null) {
      final lKneeAngle = _calculateAngle(lHip, lKnee, lAnkle);
      final rKneeAngle = _calculateAngle(rHip, rKnee, rAnkle);

      // Анти-чит: требуем вертикальность только на старте (стадия 'up'),
      // в нижней точке таз может опускаться ниже колен — не блокируем
      if (_currentStage == 'up') {
        final leftUpright = _isShoulderAboveHip(lShoulder, lHip);
        final rightUpright = _isShoulderAboveHip(rShoulder, rHip);
        if (!(leftUpright && rightUpright)) return;
      }

      if (lKneeAngle < 100 && rKneeAngle < 100 && _currentStage == 'up') {
        _currentStage = 'down';
      } else if (lKneeAngle > 160 && rKneeAngle > 160 && _currentStage == 'down') {
        _currentStage = 'up';
        feedbackNotifier.value = ExerciseFeedback(
          repCount: feedbackNotifier.value.repCount + 1,
          isCalibrated: _isCalibrated,
        );
      }
    } else {
      // Фоллбэк: считаем по любой доступной ноге, но требуем вертикальный корпус на этой стороне
      if (lHip != null && lKnee != null && lAnkle != null) {
        final lKneeAngle = _calculateAngle(lHip, lKnee, lAnkle);
        final okStart = _currentStage == 'up' ? _isShoulderAboveHip(lShoulder, lHip) : true;
        if (okStart) {
          if (lKneeAngle < 95 && _currentStage == 'up') {
            _currentStage = 'down';
          } else if (lKneeAngle > 165 && _currentStage == 'down') {
            _currentStage = 'up';
            feedbackNotifier.value = ExerciseFeedback(
              repCount: feedbackNotifier.value.repCount + 1,
              isCalibrated: _isCalibrated,
            );
          }
        }
      } else if (rHip != null && rKnee != null && rAnkle != null) {
        final rKneeAngle = _calculateAngle(rHip, rKnee, rAnkle);
        final okStart = _currentStage == 'up' ? _isShoulderAboveHip(rShoulder, rHip) : true;
        if (okStart) {
          if (rKneeAngle < 95 && _currentStage == 'up') {
            _currentStage = 'down';
          } else if (rKneeAngle > 165 && _currentStage == 'down') {
            _currentStage = 'up';
            feedbackNotifier.value = ExerciseFeedback(
              repCount: feedbackNotifier.value.repCount + 1,
              isCalibrated: _isCalibrated,
            );
          }
        }
      }
    }
  }
  
  void _analyzePushup(Pose pose) {
    final lm = pose.landmarks;
    final lShoulder = lm[PoseLandmarkType.leftShoulder];
    final rShoulder = lm[PoseLandmarkType.rightShoulder];
    final lElbow = lm[PoseLandmarkType.leftElbow];
    final rElbow = lm[PoseLandmarkType.rightElbow];
    final lWrist = lm[PoseLandmarkType.leftWrist];
    final rWrist = lm[PoseLandmarkType.rightWrist];
    final lHip = lm[PoseLandmarkType.leftHip];
    final rHip = lm[PoseLandmarkType.rightHip];
    final lKnee = lm[PoseLandmarkType.leftKnee];
    final rKnee = lm[PoseLandmarkType.rightKnee];

    // Если видны обе руки — используем двустороннюю логику
    if (lShoulder != null && rShoulder != null && lElbow != null && rElbow != null && lWrist != null && rWrist != null) {
      final lElbowAngle = _calculateAngle(lShoulder, lElbow, lWrist);
      final rElbowAngle = _calculateAngle(rShoulder, rElbow, rWrist);

      // Анти-чит: проверяем горизонтальность/прямоту только на старте (стадия 'up')
      if (_currentStage == 'up') {
        final proneOk = (lHip != null && rHip != null) ? _isProne(lShoulder, lHip, rShoulder, rHip) : true;
        final leftStraightOk = (lHip != null && lKnee != null) ? _isBodyStraight(lShoulder, lHip, lKnee) : true;
        final rightStraightOk = (rHip != null && rKnee != null) ? _isBodyStraight(rShoulder, rHip, rKnee) : true;
        if (!proneOk || !leftStraightOk || !rightStraightOk) return;
      }

      if (lElbowAngle < 90 && rElbowAngle < 90 && _currentStage == 'up') {
        _currentStage = 'down';
      } else if (lElbowAngle > 160 && rElbowAngle > 160 && _currentStage == 'down') {
        _currentStage = 'up';
        feedbackNotifier.value = ExerciseFeedback(
          repCount: feedbackNotifier.value.repCount + 1,
          isCalibrated: _isCalibrated,
        );
      }
    } else {
      // Фоллбэк: считаем по любой доступной руке; проверку прямоты делаем только на старте
      if (lShoulder != null && lElbow != null && lWrist != null) {
        final lElbowAngle = _calculateAngle(lShoulder, lElbow, lWrist);
        final straightOk = _currentStage == 'up'
            ? ((lHip != null && lKnee != null) ? _isBodyStraight(lShoulder, lHip, lKnee) : true)
            : true;
        if (straightOk) {
          if (lElbowAngle < 90 && _currentStage == 'up') {
            _currentStage = 'down';
          } else if (lElbowAngle > 160 && _currentStage == 'down') {
            _currentStage = 'up';
            feedbackNotifier.value = ExerciseFeedback(
              repCount: feedbackNotifier.value.repCount + 1,
              isCalibrated: _isCalibrated,
            );
          }
        }
      } else if (rShoulder != null && rElbow != null && rWrist != null) {
        final rElbowAngle = _calculateAngle(rShoulder, rElbow, rWrist);
        final straightOk = _currentStage == 'up'
            ? ((rHip != null && rKnee != null) ? _isBodyStraight(rShoulder, rHip, rKnee) : true)
            : true;
        if (straightOk) {
          if (rElbowAngle < 90 && _currentStage == 'up') {
            _currentStage = 'down';
          } else if (rElbowAngle > 160 && _currentStage == 'down') {
            _currentStage = 'up';
            feedbackNotifier.value = ExerciseFeedback(
              repCount: feedbackNotifier.value.repCount + 1,
              isCalibrated: _isCalibrated,
            );
          }
        }
      }
    }
  }

  bool _isUpright(PoseLandmark? shoulder, PoseLandmark? hip, PoseLandmark? knee) {
    if (shoulder == null || hip == null || knee == null) return false;
    if (!(shoulder.y < hip.y && hip.y < knee.y)) return false;
    final dx = hip.x - shoulder.x;
    final dy = hip.y - shoulder.y;
    if (dy <= 0) return false;
    final angleToVerticalDeg = (atan2(dx.abs(), dy.abs()) * 180.0 / pi);
    return angleToVerticalDeg < 35.0; // немного мягче
  }

  bool _isShoulderAboveHip(PoseLandmark? shoulder, PoseLandmark? hip) {
    if (shoulder == null || hip == null) return false;
    return shoulder.y < hip.y;
  }

  bool _isProne(PoseLandmark? lShoulder, PoseLandmark? lHip, PoseLandmark? rShoulder, PoseLandmark? rHip) {
    if (lShoulder == null || rShoulder == null || lHip == null || rHip == null) return false;
    final sMidX = (lShoulder.x + rShoulder.x) / 2.0;
    final sMidY = (lShoulder.y + rShoulder.y) / 2.0;
    final hMidX = (lHip.x + rHip.x) / 2.0;
    final hMidY = (lHip.y + rHip.y) / 2.0;
    final dx = hMidX - sMidX;
    final dy = hMidY - sMidY;
    if (dx == 0 && dy == 0) return false;
    final angleToHorizontalDeg = (atan2(dy.abs(), dx.abs()) * 180.0 / pi);
    return angleToHorizontalDeg < 35.0; // немного мягче
  }

  bool _isBodyStraight(PoseLandmark? shoulder, PoseLandmark? hip, PoseLandmark? knee) {
    if (shoulder == null || hip == null || knee == null) return false;
    final bodyAngle = _calculateAngle(shoulder, hip, knee);
    return bodyAngle > 165.0; // почти прямая линия
  }

  void _analyzeCrunch(Pose pose) {
    final lm = pose.landmarks;
    // Можно считать по любой стороне, используем доступные точки плечо–бедро–колено
    final lShoulder = lm[PoseLandmarkType.leftShoulder];
    final lHip = lm[PoseLandmarkType.leftHip];
    final lKnee = lm[PoseLandmarkType.leftKnee];
    final rShoulder = lm[PoseLandmarkType.rightShoulder];
    final rHip = lm[PoseLandmarkType.rightHip];
    final rKnee = lm[PoseLandmarkType.rightKnee];

    double? hipAngle;
    if (lShoulder != null && lHip != null && lKnee != null) {
      hipAngle = _calculateAngle(lShoulder, lHip, lKnee);
    } else if (rShoulder != null && rHip != null && rKnee != null) {
      hipAngle = _calculateAngle(rShoulder, rHip, rKnee);
    }

    if (hipAngle != null) {
      if (hipAngle < 135 && _currentStage == 'down') {
        _currentStage = 'up';
      } else if (hipAngle > 150 && _currentStage == 'up') {
        _currentStage = 'down';
        feedbackNotifier.value = ExerciseFeedback(
          repCount: feedbackNotifier.value.repCount + 1,
          isCalibrated: _isCalibrated,
        );
      }
    }
  }

  Map<String, dynamic> getWorkoutResults() {
    // Проверка качества отключена: возвращаем нули/пусто
    return {'avgQuality': 0.0, 'errorCounts': <String, int>{}};
  }

  double _calculateAngle(PoseLandmark a, PoseLandmark b, PoseLandmark c) {
    final radians = atan2(c.y - b.y, c.x - b.x) - atan2(a.y - b.y, a.x - b.x);
    double angle = radians.abs() * 180.0 / pi;
    if (angle > 180.0) angle = 360.0 - angle;
    return angle;
  }

  InputImage? _inputImageFromCameraImage(CameraImage image, CameraDescription camera) {
    final rotation = InputImageRotationValue.fromRawValue(camera.sensorOrientation);
    if (rotation == null) return null;
    return InputImage.fromBytes(
      bytes: image.planes.first.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: InputImageFormat.nv21,
        bytesPerRow: image.planes.first.bytesPerRow,
      ),
    );
  }

  void dispose() {
    _poseDetector.close();
    feedbackNotifier.dispose();
    poseDataNotifier.dispose();
    fpsNotifier.dispose(); // НЕ ЗАБЫВАЕМ УДАЛИТЬ
    lastLatencyMs.dispose();
    avgLatencyMs.dispose();
  }
}