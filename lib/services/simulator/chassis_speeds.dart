class ChassisSpeeds {
  num vx;
  num vy;
  num omega;

  ChassisSpeeds({
    this.vx = 0,
    this.vy = 0,
    this.omega = 0,
  });

  @override
  bool operator ==(Object other) =>
      other is ChassisSpeeds &&
      other.runtimeType == runtimeType &&
      other.vx == vx &&
      other.vy == vy &&
      other.omega == omega;

  @override
  int get hashCode => Object.hash(vx, vy, omega);
}
