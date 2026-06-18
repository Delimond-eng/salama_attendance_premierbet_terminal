class Task {
  final int id;
  final int? stationId;
  final String title;
  final String? description;
  final String priority;
  final String status;
  final bool isGlobal;
  final DateTime? startDate;
  final DateTime? dueDate;
  final DateTime? completedAt;
  final double progress;
  final bool isOverdue;
  final List<Subtask> subtasks;
  final Station? station;

  Task({
    required this.id,
    this.stationId,
    required this.title,
    this.description,
    required this.priority,
    required this.status,
    required this.isGlobal,
    this.startDate,
    this.dueDate,
    this.completedAt,
    required this.progress,
    required this.isOverdue,
    required this.subtasks,
    this.station,
  });

  factory Task.fromJson(Map<String, dynamic> json) {
    // Conversion robuste du progrès
    double progressValue = 0;
    var rawProgress = json['progress'];
    if (rawProgress != null) {
      progressValue = double.tryParse(rawProgress.toString()) ?? 0;
      if (progressValue > 1.0) progressValue /= 100.0;
    }

    // Conversion robuste des booléens (pour supporter 0/1 ou true/false)
    bool toBool(dynamic val) => val == true || val == 1 || val.toString() == '1' || val.toString() == 'true';

    return Task(
      id: int.tryParse(json['id'].toString()) ?? 0,
      stationId: json['station_id'] != null ? int.tryParse(json['station_id'].toString()) : null,
      title: json['title'] ?? '',
      description: json['description'],
      priority: json['priority'] ?? 'medium',
      status: json['status'] ?? 'pending',
      isGlobal: toBool(json['is_global']),
      startDate: json['start_date'] != null ? DateTime.tryParse(json['start_date'].toString()) : null,
      dueDate: json['due_date'] != null ? DateTime.tryParse(json['due_date'].toString()) : null,
      completedAt: json['completed_at'] != null ? DateTime.tryParse(json['completed_at'].toString()) : null,
      progress: progressValue,
      isOverdue: toBool(json['is_overdue']),
      subtasks: (json['subtasks'] as List? ?? []).map((e) => Subtask.fromJson(e)).toList(),
      station: json['station'] != null ? Station.fromJson(json['station']) : null,
    );
  }
}

class Subtask {
  final int id;
  final int taskId;
  final String title;
  final bool isCompleted;
  final DateTime? completedAt;

  Subtask({
    required this.id,
    required this.taskId,
    required this.title,
    required this.isCompleted,
    this.completedAt,
  });

  factory Subtask.fromJson(Map<String, dynamic> json) {
    return Subtask(
      id: int.tryParse(json['id'].toString()) ?? 0,
      taskId: int.tryParse(json['task_id'].toString()) ?? 0,
      title: json['title'] ?? '',
      isCompleted: json['is_completed'] == true || json['is_completed'] == 1 || json['is_completed'].toString() == '1',
      completedAt: json['completed_at'] != null ? DateTime.tryParse(json['completed_at'].toString()) : null,
    );
  }
}

class Station {
  final int id;
  final String name;
  final String code;
  final String? type;
  final String? adresse;
  final String? phone;
  final String status;

  Station({
    required this.id,
    required this.name,
    required this.code,
    this.type,
    this.adresse,
    this.phone,
    required this.status,
  });

  factory Station.fromJson(Map<String, dynamic> json) {
    return Station(
      id: int.tryParse(json['id'].toString()) ?? 0,
      name: json['name'] ?? '',
      code: json['code'] ?? '',
      type: json['type'],
      adresse: json['adresse'],
      phone: json['phone'],
      status: json['status'] ?? 'actif',
    );
  }
}
