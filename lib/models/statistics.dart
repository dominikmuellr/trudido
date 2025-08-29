class TodoStatistics {
  final int totalTasks;
  final int completedTasks;
  final int pendingTasks;
  final int overdueTasks;
  final int dueTodayTasks;
  final int dueSoonTasks;
  final Map<String, int> tasksByCategory;
  final Map<String, int> tasksByPriority;
  final double completionRate;
  final int streakDays;
  final DateTime? lastCompletedDate;

  TodoStatistics({
    required this.totalTasks,
    required this.completedTasks,
    required this.pendingTasks,
    required this.overdueTasks,
    required this.dueTodayTasks,
    required this.dueSoonTasks,
    required this.tasksByCategory,
    required this.tasksByPriority,
    required this.completionRate,
    required this.streakDays,
    this.lastCompletedDate,
  });

  factory TodoStatistics.empty() {
    return TodoStatistics(
      totalTasks: 0,
      completedTasks: 0,
      pendingTasks: 0,
      overdueTasks: 0,
      dueTodayTasks: 0,
      dueSoonTasks: 0,
      tasksByCategory: {},
      tasksByPriority: {},
      completionRate: 0.0,
      streakDays: 0,
    );
  }

  bool get hasActiveTasks => pendingTasks > 0;
  bool get hasOverdueTasks => overdueTasks > 0;
  bool get hasDueTodayTasks => dueTodayTasks > 0;

  String get motivationalMessage {
    if (completionRate >= 0.8) {
      return "Excellent work! You're crushing your goals! 🎉";
    } else if (completionRate >= 0.6) {
      return "Great progress! Keep up the momentum! 💪";
    } else if (completionRate >= 0.4) {
      return "You're making steady progress! 📈";
    } else if (completionRate > 0) {
      return "Every step counts! Keep going! 🌟";
    } else {
      return "Ready to start your productive journey? 🚀";
    }
  }

  @override
  String toString() {
    return 'TodoStatistics(total: $totalTasks, completed: $completedTasks, pending: $pendingTasks, rate: ${(completionRate * 100).toStringAsFixed(1)}%)';
  }
}
