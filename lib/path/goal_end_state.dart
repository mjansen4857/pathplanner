class GoalEndState {
  num velocity;
  num rotation;
  bool rotateFast;

  GoalEndState({
    this.velocity = 0,
    this.rotation = 0,
    this.rotateFast = false,
  });

  GoalEndState.fromJson(Map<String, dynamic> json)
      : velocity = json['velocity'] ?? 0,
        rotation = json['rotation'] ?? 0,
        rotateFast = json['rotateFast'] ?? false;

  Map<String, dynamic> toJson() {
    return {
      'velocity': velocity,
      'rotation': rotation,
      'rotateFast': rotateFast,
    };
  }

  GoalEndState clone() {
    return GoalEndState(
        velocity: velocity, rotation: rotation, rotateFast: rotateFast);
  }

  @override
  bool operator ==(Object other) =>
      other is GoalEndState &&
      other.runtimeType == runtimeType &&
      other.velocity == velocity &&
      other.rotation == rotation &&
      other.rotateFast == rotateFast;

  @override
  int get hashCode => Object.hash(velocity, rotation, rotateFast);
}
