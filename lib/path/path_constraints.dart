class PathConstraints {
  num maxVelocity;
  num maxAcceleration;
  num maxAngularVelocity;
  num maxAngularAcceleration;

  PathConstraints({
    this.maxVelocity = 3,
    this.maxAcceleration = 3,
    this.maxAngularVelocity = 540,
    this.maxAngularAcceleration = 720,
  });
}
