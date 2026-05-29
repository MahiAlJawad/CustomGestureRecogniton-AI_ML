import os
import glob
import numpy as np
import pandas as pd
import tensorflow as tf

from sklearn.model_selection import train_test_split
from sklearn.preprocessing import LabelEncoder


# ============================================================
# Configuration
# ============================================================

DATA_DIR = "data"

FEATURE_COLUMNS = ["ax", "ay", "az", "gx", "gy", "gz"]
REQUIRED_COLUMNS = FEATURE_COLUMNS + ["label"]

# Your rotate attempts are around 66-109 rows,
# so 64 samples is a better first window size than 100.
WINDOW_SIZE = 64       # About 1.28 seconds at 50 Hz
STEP_SIZE = 32         # 50% overlap

TEST_SIZE = 0.25       # Reserve 25% of original files for testing
RANDOM_STATE = 42

EPOCHS = 30
BATCH_SIZE = 8


# ============================================================
# Load Recorded CSV Files
# ============================================================

def load_recordings():
    """
    Loads raw CSV recordings from folders such as:

    data/
      rotate/
        rotate_001.csv
      noise/
        noise_001.csv

    Each CSV is kept as an individual recording so that we can
    split recording files before generating overlapping windows.
    """

    csv_paths = glob.glob(os.path.join(DATA_DIR, "*", "*.csv"))

    if not csv_paths:
        raise FileNotFoundError(
            "No CSV files found. "
            "Expected files such as data/rotate/rotate_001.csv "
            "and data/noise/noise_001.csv."
        )

    recordings = []

    for path in sorted(csv_paths):
        df = pd.read_csv(path)

        missing_columns = set(REQUIRED_COLUMNS) - set(df.columns)

        if missing_columns:
            raise ValueError(
                f"{path} is missing required columns: {missing_columns}"
            )

        # Keep only the columns used for training.
        df = df[REQUIRED_COLUMNS].dropna()

        folder_label = os.path.basename(os.path.dirname(path))
        labels_in_csv = set(df["label"].unique())

        # The folder and the CSV label should represent the same class.
        if labels_in_csv != {folder_label}:
            print(
                f"Warning: {path} is inside folder '{folder_label}', "
                f"but CSV labels are {labels_in_csv}."
            )

        recordings.append({
            "path": path,
            "label": folder_label,
            "df": df
        })

        print(f"Loaded {path}: {len(df)} rows")

    return recordings


# ============================================================
# Split Original Recordings
# ============================================================

def split_recordings_by_label(recordings):
    """
    Splits original recording files into training and testing sets.

    Important:
    We split files before generating sliding windows.

    Otherwise, overlapping windows from the same original file
    could appear in both training and testing, producing misleading
    test accuracy.
    """

    train_recordings = []
    test_recordings = []

    labels = sorted(set(recording["label"] for recording in recordings))

    print("\nAvailable classes:")
    for label in labels:
        print(f"  {label}")

    if len(labels) != 2:
        raise ValueError(
            "This first model expects exactly two classes. "
            "For now keep only 'noise' and 'rotate' data folders."
        )

    for label in labels:
        label_recordings = [
            recording
            for recording in recordings
            if recording["label"] == label
        ]

        if len(label_recordings) < 2:
            raise ValueError(
                f"Class '{label}' needs at least 2 CSV recording files "
                "so one file can be held out for testing."
            )

        train_items, test_items = train_test_split(
            label_recordings,
            test_size=TEST_SIZE,
            random_state=RANDOM_STATE
        )

        train_recordings.extend(train_items)
        test_recordings.extend(test_items)

    return train_recordings, test_recordings


# ============================================================
# Create Fixed-Length Motion Windows
# ============================================================

def make_windows(recordings):
    """
    Converts each variable-length CSV recording into fixed-length
    model inputs.

    Every output window has this shape:

        64 rows x 6 sensor features

    Sensor feature order:

        ax, ay, az, gx, gy, gz
    """

    windows = []
    labels = []
    skipped_files = []

    for recording in recordings:
        path = recording["path"]
        label = recording["label"]
        df = recording["df"]

        sensor_values = df[FEATURE_COLUMNS].values.astype(np.float32)

        if len(sensor_values) < WINDOW_SIZE:
            skipped_files.append((path, len(sensor_values)))
            continue

        for start_index in range(
            0,
            len(sensor_values) - WINDOW_SIZE + 1,
            STEP_SIZE
        ):
            end_index = start_index + WINDOW_SIZE
            window = sensor_values[start_index:end_index]

            windows.append(window)
            labels.append(label)

    X = np.array(windows, dtype=np.float32)
    text_labels = np.array(labels)

    return X, text_labels, skipped_files


def print_dataset_summary(name, X, labels):
    """
    Prints the number of generated windows for each class.
    """

    print(f"\n{name} dataset:")
    print("X shape:", X.shape)
    print("Labels shape:", labels.shape)

    unique_labels, counts = np.unique(labels, return_counts=True)

    print("Window label count:")

    for label, count in zip(unique_labels, counts):
        print(f"  {label}: {count}")


# ============================================================
# Build Small Motion Classification Model
# ============================================================

def build_model(X_train):
    """
    Builds a small 1D Convolutional Neural Network.

    Why 1D CNN?
    Motion data is a sequence over time. Conv1D can learn patterns
    such as changes in acceleration and rotation across nearby
    sensor samples.

    Input shape:
        64 time steps x 6 sensor values

    Output:
        One probability:
        close to 0 = noise
        close to 1 = rotate
    """

    normalizer = tf.keras.layers.Normalization(axis=-1)

    # The normalizer learns average and variation for each sensor
    # feature using training data only.
    normalizer.adapt(X_train)

    model = tf.keras.Sequential([
        tf.keras.layers.Input(
            shape=(WINDOW_SIZE, len(FEATURE_COLUMNS)),
            name="motion_input"
        ),

        normalizer,

        tf.keras.layers.Conv1D(
            filters=16,
            kernel_size=5,
            activation="relu",
            name="conv_motion_patterns_1"
        ),

        tf.keras.layers.MaxPooling1D(
            pool_size=2,
            name="pool_1"
        ),

        tf.keras.layers.Conv1D(
            filters=32,
            kernel_size=3,
            activation="relu",
            name="conv_motion_patterns_2"
        ),

        tf.keras.layers.GlobalAveragePooling1D(
            name="combine_time_patterns"
        ),

        tf.keras.layers.Dense(
            16,
            activation="relu",
            name="dense_features"
        ),

        tf.keras.layers.Dense(
            1,
            activation="sigmoid",
            name="rotate_probability"
        )
    ])

    model.compile(
        optimizer="adam",
        loss="binary_crossentropy",
        metrics=["accuracy"]
    )

    return model


# ============================================================
# Print Model Predictions
# ============================================================

def print_predictions(model, X_test, y_test, label_encoder):
    """
    Prints the predicted probability and result for each unseen
    test window.
    """

    probabilities = model.predict(X_test, verbose=0).flatten()

    print("\nPredictions on held-out testing windows:")

    for index, probability in enumerate(probabilities):
        predicted_numeric_label = 1 if probability >= 0.5 else 0

        predicted_label = label_encoder.inverse_transform(
            [predicted_numeric_label]
        )[0]

        actual_label = label_encoder.inverse_transform(
            [y_test[index]]
        )[0]

        is_correct = predicted_label == actual_label
        result_text = "correct" if is_correct else "wrong"

        print(
            f"Window {index + 1:02d}: "
            f"rotate_probability={probability:.3f}, "
            f"predicted={predicted_label}, "
            f"actual={actual_label}, "
            f"{result_text}"
        )


# ============================================================
# Main Training Pipeline
# ============================================================

def main():
    print("TensorFlow version:", tf.__version__)
    print("\nLoading CSV recordings...")

    recordings = load_recordings()

    print("\nSplitting original recording files...")
    train_recordings, test_recordings = split_recordings_by_label(recordings)

    print("\nRecording file split:")
    print(f"Training files: {len(train_recordings)}")
    print(f"Testing files:  {len(test_recordings)}")

    print("\nFiles reserved for testing:")
    for recording in test_recordings:
        print(f"  {recording['path']}")

    print("\nCreating motion windows...")

    X_train, train_text_labels, train_skipped = make_windows(
        train_recordings
    )

    X_test, test_text_labels, test_skipped = make_windows(
        test_recordings
    )

    if len(X_train) == 0:
        raise ValueError(
            "No training windows were generated. "
            "Record longer gesture samples or reduce WINDOW_SIZE."
        )

    if len(X_test) == 0:
        raise ValueError(
            "No testing windows were generated. "
            "Record longer test samples or reduce WINDOW_SIZE."
        )

    print_dataset_summary("Training", X_train, train_text_labels)
    print_dataset_summary("Testing", X_test, test_text_labels)

    skipped_files = train_skipped + test_skipped

    if skipped_files:
        print("\nSkipped files because they were shorter than "
              f"{WINDOW_SIZE} samples:")

        for path, row_count in skipped_files:
            print(f"  {path}: {row_count} rows")

    # --------------------------------------------------------
    # Convert text labels into numeric TensorFlow labels
    # --------------------------------------------------------

    label_encoder = LabelEncoder()

    y_train = label_encoder.fit_transform(train_text_labels)
    y_test = label_encoder.transform(test_text_labels)

    print("\nNumeric label mapping:")

    for numeric_value, label_name in enumerate(label_encoder.classes_):
        print(f"  {label_name} = {numeric_value}")

    # For this binary sigmoid model, we require:
    # noise = 0 and rotate = 1.
    expected_classes = ["noise", "rotate"]

    if list(label_encoder.classes_) != expected_classes:
        raise ValueError(
            "Expected exactly these alphabetically encoded classes: "
            "noise = 0 and rotate = 1."
        )

    print("\nFinal arrays ready for model training:")
    print("X_train:", X_train.shape)
    print("y_train:", y_train.shape)
    print("X_test: ", X_test.shape)
    print("y_test: ", y_test.shape)

    # --------------------------------------------------------
    # Build and train model
    # --------------------------------------------------------

    print("\nBuilding neural-network model...")

    model = build_model(X_train)

    model.summary()

    print("\nTraining model...")

    model.fit(
        X_train,
        y_train,
        epochs=EPOCHS,
        batch_size=BATCH_SIZE,
        verbose=1
    )

    # --------------------------------------------------------
    # Evaluate on unseen recording files
    # --------------------------------------------------------

    print("\nEvaluating model on held-out testing recordings...")

    test_loss, test_accuracy = model.evaluate(
        X_test,
        y_test,
        verbose=0
    )

    print(f"\nTest loss: {test_loss:.4f}")
    print(f"Test accuracy: {test_accuracy:.4f}")

    print_predictions(
        model=model,
        X_test=X_test,
        y_test=y_test,
        label_encoder=label_encoder
    )

        # --------------------------------------------------------
    # Save label order used by the model
    # --------------------------------------------------------

    with open("labels.txt", "w") as label_file:
        for label_name in label_encoder.classes_:
            label_file.write(f"{label_name}\n")

    print("\nSaved label mapping to labels.txt")

    # --------------------------------------------------------
    # Save the original trained Keras model
    # --------------------------------------------------------

    model.save("gesture_rotate_model.keras")

    print("Saved trained Keras model: gesture_rotate_model.keras")

    # --------------------------------------------------------
    # Convert trained model into TensorFlow Lite format
    # --------------------------------------------------------

    converter = tf.lite.TFLiteConverter.from_keras_model(model)

    tflite_model = converter.convert()

    with open("gesture_rotate_model.tflite", "wb") as model_file:
        model_file.write(tflite_model)

    print("Saved TensorFlow Lite model: gesture_rotate_model.tflite")

    tflite_size_kb = os.path.getsize("gesture_rotate_model.tflite") / 1024

    print(f"TFLite model size: {tflite_size_kb:.2f} KB")


if __name__ == "__main__":
    main()