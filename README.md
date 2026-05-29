# Gesture KNN Demo

SwiftUI iOS demo for motion gesture recognition with a hybrid ML pipeline:

- TensorFlow Lite detects the built-in `rotate` gesture first.
- User-recorded gestures are matched afterward with DTW + k-NN.
- CoreMotion provides live accelerometer and gyroscope samples.

Test on a real iPhone. The iOS Simulator does not provide normal device-motion data.

## Solution Flow

```mermaid
flowchart TD
    A["Detect tab: Start Listening"] --> B["CoreMotion samples<br/>accelerometer + gyroscope"]
    B --> C["ContinuousGestureDetector<br/>segments motion"]
    C --> D{"Candidate gesture<br/>completed?"}
    D -- "No" --> B
    D -- "Yes" --> E["Resample segment<br/>64 x 6 sensor window"]
    E --> F["TFLite rotate/noise model"]
    F --> G{"Prediction"}
    G -- "rotate" --> H["Return rotate"]
    G -- "noise" --> I{"Saved gestures?"}
    I -- "No" --> J["Ignore as noise"]
    I -- "Yes" --> K["DTW distance vs<br/>saved gesture examples"]
    K --> L["k-NN vote"]
    L --> M{"Confidence + distance<br/>accepted?"}
    M -- "Yes" --> N["Return saved gesture label"]
    M -- "No" --> J
```

## App Flow

1. Open the **Register** tab and record custom gestures.
2. Open the **Detect** tab and tap **Start Listening**.
3. If the motion is `rotate`, the TFLite model returns it immediately.
4. If the model sees `noise`, the app checks saved user gestures with DTW + k-NN.

## ML Training Flow

Use this only when the built-in rotate/noise model needs to be retrained.

```mermaid
flowchart LR
    A["Record raw motion CSVs<br/>rotate + noise"] --> B["MLTraining/train_rotate_model.py"]
    B --> C["Train small 1D CNN"]
    C --> D["gesture_rotate_model.keras"]
    C --> E["gesture_rotate_model.tflite"]
    E --> F["GestureKNNDemo/MLModels"]
    F --> G["RotateNoiseTFLiteClassifier"]
    G --> H["Runtime rotate/noise prediction"]
```

## Project Map

- `GestureKNNDemo/App`: app entry point, tabs, app shortcut intent.
- `GestureKNNDemo/Motion`: CoreMotion recording and continuous segmentation.
- `GestureKNNDemo/ML`: TFLite wrapper, DTW, and k-NN logic.
- `GestureKNNDemo/MLModels`: bundled rotate/noise `.tflite` model and labels.
- `GestureKNNDemo/Storage`: saved custom gesture persistence.
- `GestureKNNDemo/Views`: SwiftUI screens.
- `MLTraining`: optional Python training scripts and sample CSV data.

## Run

1. Open `GestureKNNDemo.xcodeproj` in Xcode.
2. Select a real iPhone.
3. Update signing if needed.
4. Build and run.
