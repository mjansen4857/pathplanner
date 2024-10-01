class PathConstraints {
  num maxVelocityMPS;
  num maxAccelerationMPSSq;
  num maxAngularVelocityDeg;
  num maxAngularAccelerationDeg;

  PathConstraints({
    this.maxVelocityMPS = 3,
    this.maxAccelerationMPSSq = 3,
    this.maxAngularVelocityDeg = 540,
    this.maxAngularAccelerationDeg = 720,
  });

  PathConstraints.fromJson(Map<String, dynamic> json)
      : maxVelocityMPS = json['maxVelocity'] ?? 3,
        maxAccelerationMPSSq = json['maxAcceleration'] ?? 3,
        maxAngularVelocityDeg = json['maxAngularVelocity'] ?? 540,
        maxAngularAccelerationDeg = json['maxAngularAcceleration'] ?? 720;

  PathConstraints clone() {
    return PathConstraints(
      maxVelocityMPS: maxVelocityMPS,
      maxAccelerationMPSSq: maxAccelerationMPSSq,
      maxAngularVelocityDeg: maxAngularVelocityDeg,
      maxAngularAccelerationDeg: maxAngularAccelerationDeg,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'maxVelocity': maxVelocityMPS,
      'maxAcceleration': maxAccelerationMPSSq,
      'maxAngularVelocity': maxAngularVelocityDeg,
      'maxAngularAcceleration': maxAngularAccelerationDeg,
    };
  }

  @override
  bool operator ==(Object other) =>
      other is PathConstraints &&
      other.runtimeType == runtimeType &&
      other.maxVelocityMPS == maxVelocityMPS &&
      other.maxAccelerationMPSSq == maxAccelerationMPSSq &&
      other.maxAngularVelocityDeg == maxAngularVelocityDeg &&
      other.maxAngularAccelerationDeg == other.maxAngularAccelerationDeg;

  @override
  int get hashCode => Object.hash(maxVelocityMPS, maxAccelerationMPSSq,
      maxAngularVelocityDeg, maxAngularAccelerationDeg);
}
