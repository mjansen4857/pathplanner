class IdealStartingState {
  num rotation;
  num velocity;

  IdealStartingState({this.rotation = 0, this.velocity = 0});

  IdealStartingState.fromJson(Map<String, dynamic> json)
      : this(
          rotation: json['rotation'],
          velocity: json['velocity'],
        );

  Map<String, dynamic> toJson() {
    return {
      'rotation': rotation,
      'velocity': velocity,
    };
  }

  IdealStartingState clone() {
    return IdealStartingState(
      rotation: rotation,
      velocity: velocity,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is IdealStartingState &&
      other.runtimeType == runtimeType &&
      other.velocity == velocity &&
      other.rotation == rotation;

  @override
  int get hashCode => Object.hash(velocity, rotation);
}
