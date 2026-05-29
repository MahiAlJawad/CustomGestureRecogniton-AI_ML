import os
import glob
import numpy as np
import pandas as pd
import tensorflow as tf

MODEL_PATH = "gesture_rotate_model.tflite"
LABELS_PATH = "labels.txt"
DATA_DIR = "data"

FEATURE_COLUMNS = ["ax", "ay", "az", "gx", "gy", "gz"]

WINDOW_SIZE = 64
STEP_SIZE = 32


def load_labels():
    with open(LABELS_PATH, "r") as file:
        return [line.strip() for line in file if line.strip()]


def load_test_windows():
    """
    For this first verification, this loads available CSV files
    and creates windows. It is only checking that the TFLite model
    runs and produces meaningful output.
    """

    csv_paths = glob.glob(os.path.join(DATA_DIR, "*", "*.csv"))

    X = []
    y = []

    for path in sorted(csv_paths):
        label = os.path.basename(os.path.dirname(path))
        df = pd.read_csv(path)

        values = df[FEATURE_COLUMNS].dropna().values.astype(np.float32)

        if len(values) < WINDOW_SIZE:
            continue

        for start in range(0, len(values) - WINDOW_SIZE + 1, STEP_SIZE):
            window = values[start:start + WINDOW_SIZE]
            X.append(window)
            y.append(label)

    return np.array(X, dtype=np.float32), np.array(y)


def main():
    labels = load_labels()

    print("Labels:", labels)

    interpreter = tf.lite.Interpreter(model_path=MODEL_PATH)
    interpreter.allocate_tensors()

    input_details = interpreter.get_input_details()
    output_details = interpreter.get_output_details()

    print("\nTFLite input details:")
    print(input_details)

    print("\nTFLite output details:")
    print(output_details)

    X, actual_labels = load_test_windows()

    print("\nWindows available for verification:", len(X))

    correct = 0

    for index, window in enumerate(X):
        # Model expects a batch dimension: 1 × 64 × 6
        model_input = np.expand_dims(window, axis=0).astype(np.float32)

        interpreter.set_tensor(input_details[0]["index"], model_input)
        interpreter.invoke()

        output = interpreter.get_tensor(output_details[0]["index"])

        rotate_probability = float(output[0][0])
        predicted_label = "rotate" if rotate_probability >= 0.5 else "noise"
        actual_label = actual_labels[index]

        if predicted_label == actual_label:
            correct += 1

        print(
            f"Window {index + 1:02d}: "
            f"rotate_probability={rotate_probability:.3f}, "
            f"predicted={predicted_label}, "
            f"actual={actual_label}"
        )

    accuracy = correct / len(X) if len(X) > 0 else 0

    print(f"\nVerification accuracy on available windows: {accuracy:.4f}")


if __name__ == "__main__":
    main()