/// The smallest allowable length which isn't zero.
const num nonZeroLength = 1e-5;

/// The smallest allowable angle which isn't zero.
const num nonZeroAngle = 0.1;

/// The smallest allowable time which isn't zero.
const num nonZeroTime = 0.001;

/// Adjusts an angle to be in the range (-180, 180].
num adjustAngle(num angle) {
  num rot = angle % 360;
  if (rot > 180) {
    rot -= 360;
  }
  return rot;
}
