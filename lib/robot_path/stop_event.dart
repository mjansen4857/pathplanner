enum ExecutionBehavior { parallel, sequential, parallelDeadline }

enum WaitBehavior { none, before, after, deadline, minimum }

class StopEvent {
  List<String> eventNames;
  ExecutionBehavior executionBehavior;
  WaitBehavior waitBehavior;
  num waitTime;

  StopEvent({
    required this.eventNames,
    this.executionBehavior = ExecutionBehavior.parallel,
    this.waitBehavior = WaitBehavior.none,
    this.waitTime = 0,
  });

  StopEvent clone() {
    List<String> names = eventNames.toList();

    return StopEvent(
      eventNames: names,
      executionBehavior: executionBehavior,
      waitBehavior: waitBehavior,
      waitTime: waitTime,
    );
  }

  StopEvent.fromJson(Map<String, dynamic> json)
      : this(
          eventNames: List<String>.from(json['names'] ?? []),
          executionBehavior: ExecutionBehavior.values
              .byName(json['executionBehavior'] ?? 'parallel'),
          waitBehavior:
              WaitBehavior.values.byName(json['waitBehavior'] ?? 'none'),
          waitTime: json['waitTime'] ?? 0,
        );

  Map<String, dynamic> toJson() {
    return {
      'names': eventNames,
      'executionBehavior': executionBehavior.name,
      'waitBehavior': waitBehavior.name,
      'waitTime': waitTime,
    };
  }
}
