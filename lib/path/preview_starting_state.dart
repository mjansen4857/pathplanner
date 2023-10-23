class PreviewStartingState {
  num rotation;
  num velocity;

  PreviewStartingState({this.rotation = 0, this.velocity = 0});

  PreviewStartingState.fromJson(Map<String, dynamic> json)
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

  PreviewStartingState clone() {
    return PreviewStartingState(
      rotation: rotation,
      velocity: velocity,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is PreviewStartingState &&
      other.runtimeType == runtimeType &&
      other.velocity == velocity &&
      other.rotation == rotation;

  @override
  int get hashCode => Object.hash(velocity, rotation);
}
