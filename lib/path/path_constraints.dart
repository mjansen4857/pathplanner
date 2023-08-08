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

  PathConstraints.fromJson(Map<String, dynamic> json)
      : maxVelocity = json['maxVelocity'] ?? 3,
        maxAcceleration = json['maxAcceleration'] ?? 3,
        maxAngularVelocity = json['maxAngularVelocity'] ?? 540,
        maxAngularAcceleration = json['maxAngularAcceleration'] ?? 720;

  PathConstraints clone() {
    return PathConstraints(
      maxVelocity: maxVelocity,
      maxAcceleration: maxAcceleration,
      maxAngularVelocity: maxAngularVelocity,
      maxAngularAcceleration: maxAngularAcceleration,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'maxVelocity': maxVelocity,
      'maxAcceleration': maxAcceleration,
      'maxAngularVelocity': maxAngularVelocity,
      'maxAngularAcceleration': maxAngularAcceleration,
    };
  }

  @override
  bool operator ==(Object other) =>
      other is PathConstraints &&
      other.runtimeType == runtimeType &&
      other.maxVelocity == maxVelocity &&
      other.maxAcceleration == maxAcceleration &&
      other.maxAngularVelocity == maxAngularVelocity &&
      other.maxAngularAcceleration == other.maxAngularAcceleration;

  @override
  int get hashCode => Object.hash(
      maxVelocity, maxAcceleration, maxAngularVelocity, maxAngularAcceleration);
}
