/// Calculates the next volume step based on a logarithmic scale.
/// Returns the un-clamped new volume value.
double calculateNextVolumeStep(double currentVolume, bool isUp) {
  double newVal;

  // Determine the step size based on the region we are moving INTO.
  // We use a tiny offset to detect if we are crossing a boundary.
  double testVal = currentVolume + (isUp ? 0.1 : -0.1);
  double step;

  if (testVal < -60) {
    step = 10.0;
  } else if (testVal < -40) {
    step = 5.0;
  } else if (testVal < -20) {
    step = 2.0;
  } else if (testVal < -10) {
    step = 1.0;
  } else {
    step = 0.5;
  }

  if (isUp) {
    // Add a tiny epsilon to ensure we move past the current value,
    // then ceil to the next exact step multiple.
    newVal = ((currentVolume + 0.01) / step).ceil() * step;
  } else {
    // Subtract a tiny epsilon, then floor to the previous step multiple.
    newVal = ((currentVolume - 0.01) / step).floor() * step;
  }

  // Clean up any floating point math errors (e.g., -9.9999999999)
  return double.parse(newVal.toStringAsFixed(1));
}