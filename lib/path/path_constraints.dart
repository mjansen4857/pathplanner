class PathConstraints {
  num maxVelocityMPS;
  num maxAccelerationMPSSq;
  num maxAngularVelocityDeg;
  num maxAngularAccelerationDeg;
  num nominalVoltage;
  bool unlimited;

  PathConstraints({
    this.maxVelocityMPS = 3,
    this.maxAccelerationMPSSq = 3,
    this.maxAngularVelocityDeg = 540,
    this.maxAngularAccelerationDeg = 720,
    this.nominalVoltage = 12.0,
    this.unlimited = false,
  });

  PathConstraints.fromJson(Map<String, dynamic> json)
      : maxVelocityMPS = json['maxVelocity'] ?? 3,
        maxAccelerationMPSSq = json['maxAcceleration'] ?? 3,
        maxAngularVelocityDeg = json['maxAngularVelocity'] ?? 540,
        maxAngularAccelerationDeg = json['maxAngularAcceleration'] ?? 720,
        nominalVoltage = json['nominalVoltage'] ?? 12.0,
        unlimited = json['unlimited'] ?? false;

  PathConstraints clone() {
    return PathConstraints(
      maxVelocityMPS: maxVelocityMPS,
      maxAccelerationMPSSq: maxAccelerationMPSSq,
      maxAngularVelocityDeg: maxAngularVelocityDeg,
      maxAngularAccelerationDeg: maxAngularAccelerationDeg,
      nominalVoltage: nominalVoltage,
      unlimited: unlimited,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'maxVelocity': maxVelocityMPS,
      'maxAcceleration': maxAccelerationMPSSq,
      'maxAngularVelocity': maxAngularVelocityDeg,
      'maxAngularAcceleration': maxAngularAccelerationDeg,
      'nominalVoltage': nominalVoltage,
      'unlimited': unlimited,
    };
  }

  @override
  bool operator ==(Object other) =>
      other is PathConstraints &&
      other.runtimeType == runtimeType &&
      other.maxVelocityMPS == maxVelocityMPS &&
      other.maxAccelerationMPSSq == maxAccelerationMPSSq &&
      other.maxAngularVelocityDeg == maxAngularVelocityDeg &&
      other.maxAngularAccelerationDeg == maxAngularAccelerationDeg &&
      other.nominalVoltage == nominalVoltage &&
      other.unlimited == unlimited;

  @override
  int get hashCode => Object.hash(
      maxVelocityMPS,
      maxAccelerationMPSSq,
      maxAngularVelocityDeg,
      maxAngularAccelerationDeg,
      nominalVoltage,
      unlimited);
}
