class GoalEndState {
  num velocity;
  num rotation;

  GoalEndState({
    this.velocity = 0,
    this.rotation = 0,
  });

  GoalEndState.fromJson(Map<String, dynamic> json)
      : velocity = json['velocity'] ?? 0,
        rotation = json['rotation'] ?? 0;

  Map<String, dynamic> toJson() {
    return {
      'velocity': velocity,
      'rotation': rotation,
    };
  }

  GoalEndState clone() {
    return GoalEndState(velocity: velocity, rotation: rotation);
  }

  @override
  bool operator ==(Object other) =>
      other is GoalEndState &&
      other.runtimeType == runtimeType &&
      other.velocity == velocity &&
      other.rotation == rotation;

  @override
  int get hashCode => Object.hash(velocity, rotation);
}
