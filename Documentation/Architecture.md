# Gesture KNN Demo Architecture

The project is organized by responsibility so the Xcode navigator mirrors how the app behaves.

## Folders

- `App`: SwiftUI entry point and root tab container.
- `Models`: Codable data structures shared across storage, motion, and ML.
- `Storage`: Local persistence for saved gesture examples.
- `Motion`: CoreMotion recording and continuous gesture segmentation.
- `ML`: Feature extraction plus k-NN classification with DTW sequence distance.
- `Views`: SwiftUI screens for registering, detecting, and reviewing gestures.
- `Support`: Shared errors and small cross-cutting types.
- `Base.lproj`: Launch screen resources.

## Detection Pipeline

1. `ContinuousGestureDetector` keeps CoreMotion running at 50 Hz.
2. It starts a candidate gesture when motion intensity crosses the start threshold.
3. It ends the candidate after quiet motion or the maximum gesture duration.
4. `KNNGestureClassifier.predictSequence` compares the candidate against saved examples.
5. DTW distance handles speed variation while coverage checks reject partial gestures.
6. A prediction triggers only when vote confidence and match distance both pass thresholds.

## Training Data

`GestureExample` stores both:

- raw `MotionSample` values for DTW classification
- extracted feature vectors for metadata and future comparison experiments

Older examples saved before raw samples were added cannot be used by DTW and should be re-recorded.
