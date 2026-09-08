/// A named GUI event at a fraction of the distance along a branch.
class BranchEvent {
  final String name;
  final double position;

  BranchEvent({required this.name, num position = 0.5})
    : position = position.toDouble() {
    if (name.trim().isEmpty) {
      throw ArgumentError('Event names must be nonempty');
    }
    if (!position.isFinite || position < 0 || position > 1) {
      throw ArgumentError('Event position must be between 0 and 1');
    }
  }

  factory BranchEvent.fromJson(Object? value) {
    if (value is! Map ||
        value['name'] is! String ||
        value['position'] is! num) {
      throw const FormatException('Branch event requires a name and position');
    }
    try {
      return BranchEvent(
        name: value['name'] as String,
        position: value['position'] as num,
      );
    } on ArgumentError catch (error) {
      throw FormatException(error.message.toString());
    }
  }

  static List<BranchEvent> listFromJson(Object? value) {
    if (value == null) return [];
    if (value is! List) {
      throw const FormatException('Branch events must be a list');
    }
    return value.map(BranchEvent.fromJson).toList();
  }

  BranchEvent clone() => BranchEvent(name: name, position: position);
  Map<String, dynamic> toJson() => {'name': name, 'position': position};
  @override
  bool operator ==(Object other) =>
      other is BranchEvent && other.name == name && other.position == position;
  @override
  int get hashCode => Object.hash(name, position);
}
