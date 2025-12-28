# FitAI: Real-Time Pose Estimation for Exercise Form Correction

[![Flutter](https://img.shields.io/badge/Flutter-3.0+-02569B?logo=flutter)](https://flutter.dev)
[![BlazePose](https://img.shields.io/badge/BlazePose-MediaPipe-00897B)](https://google.github.io/mediapipe/)
[![Android](https://img.shields.io/badge/Android-15+-3DDC84?logo=android)](https://developer.android.com)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

> A mobile fitness application that combines computer vision with gamification to help university students maintain consistent exercise habits while protecting their privacy.

## 📄 Research Paper

Our research paper *"Development of a Fitness Application: Case Study for Astana IT University Students"* is currently under review for publication. You can read the full paper here: [FinalDreamTeam.pdf](https://drive.google.com/file/d/1YOfYR0dVPmJe8tf4d8grbwzznwWOcDHn/view?usp=sharing)

**Download App**: [FitAI.apk](https://drive.google.com/file/d/1sw4Ne4pN99hj5yAL8tBItFe8X-ZyB4u9/view?usp=sharing)

---

## Why This Project Exists

University students spend around 7 hours a day sitting, which leads to all sorts of health issues - bad posture, muscle problems, fatigue. We all know we should exercise more, but gym memberships are expensive, and honestly, who has time? Plus, most fitness apps just show you videos without actually checking if you're doing the exercises correctly.

That's where FitAI comes in. We built an Android app that uses your phone's camera to watch your form in real-time and tell you if you're doing squats or push-ups correctly. And here's the interesting part - instead of just giving you badges or points, the app lets you earn time on Instagram or YouTube by working out. Sounds weird, but it actually works (we tested it with 54 students from our university).

The whole thing runs on your phone, so your workout videos never leave your device. Privacy matters, especially when you're exercising at home.

---

## The Research Behind It

### What We Were Trying to Figure Out

**Main Question**: Can an AI-powered fitness app that combines real-time pose correction with gamified rewards actually get students to exercise more consistently?

**Our Hypothesis**: If we build an app that (1) checks your exercise form in real-time using AI and (2) rewards you with social media time, students will be more motivated and stick to their workouts better than with a regular fitness app.

**Spoiler**: The data supports this. 59.3% of students we surveyed said they'd use AI pose correction, and 55.6% liked the idea of earning app time through workouts. The statistical tests showed significant differences (p < 0.05) between students who used fitness apps before and those who didn't.

### How It Actually Works

The technical stuff involves some math, but here's the gist:

When you do a squat, the app tracks three points on your leg - your hip, knee, and ankle. It treats these as vectors and calculates the angle at your knee using basic trigonometry (the cosine theorem from high school math). If the angle goes below 100 degrees, that's a proper squat. The app counts it and gives you coins.

```
For three body points A (hip), B (knee), C (ankle):
We calculate vectors: a⃗ = CB⃗, b⃗ = CA⃗, c⃗ = AB⃗

Then find the knee angle using:
cos α = (b² + c² - a²) / (2bc)

If α ≤ 100°, it's a valid squat rep.
```

This happens 30 times per second (that's the frame rate we achieved), so you get instant feedback. The math runs entirely on your phone using Google's BlazePose model, which is specifically designed to work on mobile devices without needing cloud servers.

### The Gamification Part

This was actually the tricky part to get right. We didn't just want to give people points - that gets boring fast. Instead, we tied the rewards to something students actually care about: screen time.

Here's how it works:
- Complete a workout → earn coins
- Use coins to "buy" time on apps like Instagram or YouTube
- When your time runs out, the app blocks access until you do another workout

It sounds harsh, but it creates a real connection between physical activity and digital rewards. We based this on Self-Determination Theory from psychology - people are more motivated when they feel autonomous (choose their own rewards), competent (get feedback on form), and connected (maintain streaks).

The native Android part (written in Kotlin) uses `UsageStatsManager` and `AccessibilityService` to actually monitor and block apps. It's the same system parents use for parental controls, just repurposed for fitness.

---

## What We Found

We tested the app on a CMF Nothing Phone 1 (mid-range Android phone) and surveyed 54 students from Astana IT University. Here's what happened:

**Technical Performance**:
- Frame rate: 28.7-31 FPS (smooth enough for real-time feedback)
- Latency: 53.2ms from camera to feedback (you barely notice it)
- Battery usage: under 1% per workout session
- App blocking: worked 100% of the time without fails

**User Response**:
- 57.4% prefer home workouts (validates the mobile approach)
- 59.3% interested in AI pose correction (p = 0.0007, highly significant)
- 55.6% approve of the reward system (p = 0.0367)
- Students with prior fitness app experience were significantly more interested in the smart features

The statistical tests (chi-square) showed that people who'd used fitness apps before really valued the pose detection more than newbies. Makes sense - if you've struggled with form before, you appreciate automated feedback.

---

## Technical Stack

I built this using:

**Frontend**: Flutter (Dart) - chose this because it compiles to native code and handles 60 FPS animations well
**Pose Estimation**: MediaPipe BlazePose Lite - detects 33 body keypoints in real-time
**Local Storage**: Hive - keeps workout history on device
**Native Layer**: Kotlin - for the app blocking functionality
**Camera**: camera plugin for Flutter with custom processing pipeline

The architecture looks like this:

```
User Camera Input
    ↓
BlazePose Model (33 keypoints)
    ↓
Angle Calculator (trigonometry)
    ↓
Exercise Validator (threshold checking)
    ↓
Gamification Engine (coins, streaks)
    ↓
Native Blocker (Kotlin) ←→ Android System APIs
```

Everything runs locally. No servers, no cloud processing, no sending your workout videos anywhere.

---

## Getting Started

### What You Need

- Flutter SDK (3.0 or newer)
- Android Studio
- An Android phone running Android 9.0+ (API 28)
- About 2GB free space for development

### Installation

```bash
# Clone the repo
git clone https://github.com/Dariya57/ml.git
cd ml

# Get dependencies
flutter pub get

# The BlazePose model should already be in assets/
# If not, download it from MediaPipe

# Build the APK
flutter build apk --release

# Or just install directly to your phone
flutter run --release
```

### Permissions

The app needs:
- Camera (obviously, for pose detection)
- Usage Stats (to track app time)
- Accessibility Service (to block apps when time expires)

Android will ask for these on first run.

---

## Project Structure

Here's what's in the codebase:

```
lib/
├── main.dart                    # App entry point
├── models/
│   ├── pose_model.dart         # Wrapper for BlazePose
│   ├── exercise_model.dart     # Exercise definitions and validation
│   └── user_model.dart         # User data (coins, streaks, etc)
├── services/
│   ├── pose_detection.dart     # Real-time pose processing
│   ├── angle_calculator.dart   # All the trigonometry
│   └── gamification.dart       # Coin system and rewards
├── screens/
│   ├── home_screen.dart        # Main dashboard
│   ├── workout_screen.dart     # Live camera with feedback overlay
│   └── shop_screen.dart        # Where you spend coins
└── widgets/
    ├── pose_painter.dart       # Draws skeleton on camera view
    └── feedback_widget.dart    # Shows "Good squat!" messages

android/app/src/main/kotlin/
└── com/fitai/
    ├── AppBlockerService.kt    # Blocks apps when time is up
    └── UsageMonitor.kt         # Tracks time spent in apps
```

The Kotlin code was the hardest part to get right - Android's accessibility APIs are powerful but not well documented.

---

## Supported Exercises

Right now the app recognizes four exercises:

| Exercise | What We Track | How We Validate | Threshold |
|----------|--------------|-----------------|-----------|
| Squats | Hip-Knee-Ankle angle | Knee flexion depth | ≤ 100° |
| Push-ups | Shoulder-Elbow-Wrist | Elbow bend | 70-90° |
| Lunges | Both legs' hip-knee-ankle | Bilateral validation | ≤ 110° |
| Planks | Shoulder-Hip-Knee alignment | Body straightness | 160-180° |

Each exercise has slightly different validation logic, but they all use the same angle calculation approach.

---

## Known Issues and Limitations

Let's be honest about what doesn't work perfectly:

**Lighting**: The pose detection struggles in dim lighting. If your room is too dark, the skeleton tracking gets jittery. We tried adding a moving average filter to smooth it out, but it's still not great.

**Occlusions**: If your leg goes behind your body during a lunge, the app loses tracking for a second. This is a fundamental computer vision problem - the model can only see what the camera sees.

**Device Dependency**: We only tested on one phone model. Cheaper phones with slower processors might not hit 30 FPS consistently.

**Exercise Variety**: Only four exercises right now. Adding more requires defining new keypoint combinations and validation thresholds.

**Gamification Rigidity**: Everyone gets the same reward structure. Some people might need more/different incentives to stay motivated.

**Long-term Data**: We validated this with a pre-deployment survey, not by tracking actual usage over months. We can't say for sure if people stick with it long-term.

---

## What's Next

We have several ideas for improving this:

### Technical Improvements
1. **3D Pose Estimation**: Upgrade to BlazePose GHUM to get depth information
2. **Auto-Exercise Detection**: Use ML to automatically recognize what exercise you're doing instead of making you select it
3. **Adaptive Thresholds**: Adjust difficulty based on user progression
4. **Better Low-Light Performance**: Maybe add an IR sensor or use image enhancement

### Research Extensions
1. **Longitudinal Study**: Track actual users for 6 months to see if they maintain habits
2. **Controlled Trial**: Compare against a control group using a standard fitness app
3. **Personalized Gamification**: Test different reward structures for different personality types
4. **Injury Prevention**: Analyze biomechanics to warn about risky form before injury occurs

### Feature Ideas
- Social features
- Custom workout routines
- Voice feedback
- Apple Watch integration for heart rate
- Export workout data

---

## The Team

This started as a university project, but we ended up putting way more work into it than required:

**Anuar Sultanbekov** - Did all the coding: Flutter frontend, pose estimation integration, native Android stuff, basically everything you see running. Also handled the system architecture.

**Dariya Oktash** - Worked on the pose estimation algorithms and helped integrate BlazePose. Did a lot of the math for angle calculations.

**Marzhan Yakhiyayeva** - Project management and system architecture design. Kept everyone on track and made sure components worked together.

**Zhanel Adylbekova** - Designed the gamification system and analyzed survey results. Figured out how to make the rewards actually motivating.

**Advisor**: Ruslan Omirgaliev (Senior Lecturer at Astana IT University)

Big thanks to the 54 students who tested the app and filled out our survey. And to Astana IT University for supporting the research.

---

## For Researchers

If you're working on something similar, here are some things we learned:

**MediaPipe is Great, But**: BlazePose Lite works well on phones, but you need to handle edge cases yourself. The model sometimes outputs impossible angles (like knee bent backwards) that you need to filter out.

**Gamification is Hard**: We tried several reward schemes before settling on app time. Virtual badges didn't work. Leaderboards made people competitive but not consistent. Tying rewards to actual screen time (something students care about) was the breakthrough.

**Privacy Sells**: When we surveyed students, the on-device processing was a major selling point. People don't want their workout videos on some company's servers.

**Android Accessibility is Powerful**: The app blocking feature uses the same APIs as parental control apps. It's extremely reliable but requires careful permission handling and user education.

**Performance Matters**: Getting to 30 FPS required serious optimization. Originally, we were at 15 FPS and the feedback felt laggy. Moved more processing to native code and it made all the difference.

---

## Citation

If you use this work in academic research:

```bibtex
@article{sultanbekov2024fitai,
  title={Development of a Fitness Application: Case Study for Astana IT University Students},
  author={Sultanbekov, Anuar and Oktash, Dariya and Adylbekova, Zhanel and Yakhiyayeva, Marzhan},
  year={2024},
  institution={Astana IT University},
  note={Under review for conference publication}
}
```

---

## License

MIT License - feel free to use this for your own research or projects. If you build something cool with it, let me know!

Full license text in [LICENSE](LICENSE) file.

---

## Contact

**Lead Developer**: Anuar Sultanbekov  
📧 230032@astanait.edu.kz  
🏛️ Astana IT University, Kazakhstan

---

**Note**: This project started as an academic exercise but turned into something we're genuinely proud of. The code isn't perfect, but it works, and the research shows it actually helps people exercise more. That's what matters.

If you're a student struggling with sedentary habits, maybe this helps. If you're a researcher working on fitness tech, maybe our approach gives you ideas. And if you're just here to see how to do pose estimation on Android, well, the code's all here.

— Team FitAI, December 2024
