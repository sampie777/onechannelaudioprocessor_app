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