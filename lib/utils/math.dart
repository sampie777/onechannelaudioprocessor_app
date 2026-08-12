import 'dart:math';

const double minDBFS = -60.0;

// Raw float [0.0 - 1.0] to dBFS [<minDBFS> dBFS to 0 dBFS]
double rawToDbfs(double value) {
  if (value <= 0.00001) return minDBFS;
  double db = 20 * log(value) / ln10;
  return db.clamp(minDBFS, 0.0);
}

double dbfsToRaw(double value) {
  if (value <= minDBFS) return 0.0;
  return pow(10, value / 20).toDouble().clamp(0.0, 1.0);
}

double dbfsToDbLinear(double value) {
  return 1 - ((value - minDBFS) / (0.0 - minDBFS));
}

// Raw linear float [0.0 - 1.0] to raw log float [0.0 - 1.0]
double rawToDbLinear(double value) {
  return 1 - dbfsToDbLinear(rawToDbfs(value));
}

double dbToVisualLinear(List<double> meterStops, double db) {
  if (db <= meterStops.first) return 0.0;
  if (db >= meterStops.last) return 1.0;

  for (int i = 0; i < meterStops.length - 1; i++) {
    if (db >= meterStops[i] && db <= meterStops[i + 1]) {
      double range = meterStops[i + 1] - meterStops[i];
      double fraction = (db - meterStops[i]) / range;
      // Each segment represents an equal fraction of the physical meter
      return (i + fraction) / (meterStops.length - 1);
    }
  }
  return 0.0;
}

// Converts incoming raw telemetry [0.0 - 1.0] directly to the new visual height fraction
double rawToVisualLinear(List<double> meterStops, double value) {
  return dbToVisualLinear(meterStops, rawToDbfs(value));
}
