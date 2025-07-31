// Simplified Education Models for fixing critical errors
// This file provides basic models to resolve import and type errors

// Basic Tutorial Model
class Tutorial {
  final String id;
  final String title;
  final String description;
  final String category;
  final String difficulty;
  final int estimatedDuration;
  final List<String> steps;
  final bool isCompleted;

  Tutorial({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.difficulty,
    required this.estimatedDuration,
    this.steps = const [],
    this.isCompleted = false,
  });

  factory Tutorial.fromJson(Map<String, dynamic> json) {
    return Tutorial(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      category: json['category'] ?? '',
      difficulty: json['difficulty'] ?? 'beginner',
      estimatedDuration: json['estimatedDuration'] ?? 0,
      steps: List<String>.from(json['steps'] ?? []),
      isCompleted: json['isCompleted'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'category': category,
      'difficulty': difficulty,
      'estimatedDuration': estimatedDuration,
      'steps': steps,
      'isCompleted': isCompleted,
    };
  }
}

// Basic Comparison Model
class Comparison {
  final String id;
  final String title;
  final String description;
  final String beforeImageUrl;
  final String afterImageUrl;
  final List<String> keyChanges;
  final String lesson;

  Comparison({
    required this.id,
    required this.title,
    required this.description,
    required this.beforeImageUrl,
    required this.afterImageUrl,
    this.keyChanges = const [],
    required this.lesson,
  });

  factory Comparison.fromJson(Map<String, dynamic> json) {
    return Comparison(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      beforeImageUrl: json['beforeImageUrl'] ?? '',
      afterImageUrl: json['afterImageUrl'] ?? '',
      keyChanges: List<String>.from(json['keyChanges'] ?? []),
      lesson: json['lesson'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'beforeImageUrl': beforeImageUrl,
      'afterImageUrl': afterImageUrl,
      'keyChanges': keyChanges,
      'lesson': lesson,
    };
  }
}

// Basic User Progress Model
class UserProgress {
  final String userId;
  final List<String> completedTutorials;
  final int totalLearningTime;
  final String currentLevel;
  final double completionPercentage;

  UserProgress({
    required this.userId,
    this.completedTutorials = const [],
    this.totalLearningTime = 0,
    this.currentLevel = 'beginner',
    this.completionPercentage = 0.0,
  });

  factory UserProgress.fromJson(Map<String, dynamic> json) {
    return UserProgress(
      userId: json['userId'] ?? '',
      completedTutorials: List<String>.from(json['completedTutorials'] ?? []),
      totalLearningTime: json['totalLearningTime'] ?? 0,
      currentLevel: json['currentLevel'] ?? 'beginner',
      completionPercentage: (json['completionPercentage'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'completedTutorials': completedTutorials,
      'totalLearningTime': totalLearningTime,
      'currentLevel': currentLevel,
      'completionPercentage': completionPercentage,
    };
  }
}

// Basic Learning Recommendations Model
class LearningRecommendations {
  final List<Tutorial> recommendedTutorials;
  final String reason;
  final String userLevel;

  LearningRecommendations({
    this.recommendedTutorials = const [],
    required this.reason,
    required this.userLevel,
  });

  factory LearningRecommendations.fromJson(Map<String, dynamic> json) {
    return LearningRecommendations(
      recommendedTutorials: (json['recommendedTutorials'] as List?)
          ?.map((e) => Tutorial.fromJson(e))
          .toList() ?? [],
      reason: json['reason'] ?? '',
      userLevel: json['userLevel'] ?? 'beginner',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'recommendedTutorials': recommendedTutorials.map((e) => e.toJson()).toList(),
      'reason': reason,
      'userLevel': userLevel,
    };
  }
}

// API Response Models
class TutorialResponse {
  final List<Tutorial> tutorials;
  final int total;

  TutorialResponse({
    this.tutorials = const [],
    this.total = 0,
  });

  factory TutorialResponse.fromJson(Map<String, dynamic> json) {
    return TutorialResponse(
      tutorials: (json['tutorials'] as List?)
          ?.map((e) => Tutorial.fromJson(e))
          .toList() ?? [],
      total: json['total'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'tutorials': tutorials.map((e) => e.toJson()).toList(),
      'total': total,
    };
  }
}

class ComparisonResponse {
  final List<Comparison> comparisons;
  final int total;

  ComparisonResponse({
    this.comparisons = const [],
    this.total = 0,
  });

  factory ComparisonResponse.fromJson(Map<String, dynamic> json) {
    return ComparisonResponse(
      comparisons: (json['comparisons'] as List?)
          ?.map((e) => Comparison.fromJson(e))
          .toList() ?? [],
      total: json['total'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'comparisons': comparisons.map((e) => e.toJson()).toList(),
      'total': total,
    };
  }
}