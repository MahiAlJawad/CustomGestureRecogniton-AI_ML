# CustomGestureRecogniton-AI_ML
ML based custom gesture recognition project
=======
# Gesture KNN Demo

A minimal SwiftUI iOS demo for custom phone-motion gesture registration and continuous detection using CoreMotion + k-nearest-neighbor classification with DTW sequence distance.

## What it does

- Register custom gesture examples from iPhone motion data
- Save examples locally using `UserDefaults`
- Detect gestures continuously from live CoreMotion samples
- Compare raw motion sequences against saved examples using k-NN + DTW
- Reject short partial gestures with whole-gesture coverage checks
- Show predicted gesture, vote confidence, nearest saved examples, and a temporary detection toast

## How to run

1. Open `GestureKNNDemo.xcodeproj` in Xcode.
2. Select a real iPhone as the run destination.
3. Update the Signing Team if Xcode asks.
4. Build and run.

This app should be tested on a real iPhone. The iOS Simulator does not provide normal device-motion data.

## Recommended test flow

1. Open the **Register** tab.
2. Enter a gesture name such as `Dim Light`.
3. Record the same motion 3–5 times.
4. Register another gesture such as `Open Curtain`.
5. Open the **Detect** tab.
6. Tap **Start Listening**.
7. Perform a saved gesture.
8. The app predicts the closest saved gesture and shows a temporary toast for each fresh detection.

## Project structure

- `GestureKNNDemo/App`: app entry point and root tab view
- `GestureKNNDemo/Models`: Codable gesture and motion data models
- `GestureKNNDemo/Storage`: local saved-example persistence
- `GestureKNNDemo/Motion`: CoreMotion recording and continuous gesture segmentation
- `GestureKNNDemo/ML`: feature extraction, k-NN, and DTW sequence distance
- `GestureKNNDemo/Views`: SwiftUI screens
- `Documentation/Architecture.md`: architecture notes and detection pipeline

## ML approach

This demo uses classical ML/pattern recognition:

CoreMotion samples → motion segmentation → DTW sequence distance → k-NN vote → predicted gesture label

There is no Core ML model file yet. The saved gesture examples act as the local training dataset.
