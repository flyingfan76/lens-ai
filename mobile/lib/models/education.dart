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
  final TutorialMetadata metadata;

  Tutorial({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.difficulty,
    required this.estimatedDuration,
    this.steps = const [],
    this.isCompleted = false,
    TutorialMetadata? metadata,
  }) : metadata = metadata ?? TutorialMetadata();

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

// Enhanced Comparison Model for widget compatibility
class Comparison {
  final String id;
  final String title;
  final String description;
  final ComparisonImage beforeImage;
  final ComparisonImage afterImage;
  final List<KeyChange> keyChanges;
  final String lesson;
  final String difficulty;
  final String category;

  Comparison({
    required this.id,
    required this.title,
    required this.description,
    required this.beforeImage,
    required this.afterImage,
    this.keyChanges = const [],
    required this.lesson,
    this.difficulty = 'beginner',
    this.category = 'general',
  });

  factory Comparison.fromJson(Map<String, dynamic> json) {
    return Comparison(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      beforeImage: ComparisonImage.fromJson(json['beforeImage'] ?? {}),
      afterImage: ComparisonImage.fromJson(json['afterImage'] ?? {}),
      keyChanges: (json['keyChanges'] as List?)
          ?.map((e) => KeyChange.fromJson(e))
          .toList() ?? [],
      lesson: json['lesson'] ?? '',
      difficulty: json['difficulty'] ?? 'beginner',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'beforeImage': beforeImage.toJson(),
      'afterImage': afterImage.toJson(),
      'keyChanges': keyChanges.map((e) => e.toJson()).toList(),
      'lesson': lesson,
      'difficulty': difficulty,
    };
  }
}

// Comparison Image Model
class ComparisonImage {
  final String url;
  final CameraSettings settings;
  final String caption;

  ComparisonImage({
    required this.url,
    required this.settings,
    this.caption = '',
  });

  factory ComparisonImage.fromJson(Map<String, dynamic> json) {
    return ComparisonImage(
      url: json['url'] ?? '',
      settings: CameraSettings.fromJson(json['settings'] ?? {}),
      caption: json['caption'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'url': url,
      'settings': settings.toJson(),
      'caption': caption,
    };
  }
}

// Camera Settings Model
class CameraSettings {
  final int? iso;
  final String? aperture;
  final String? shutterSpeed;
  final String? whiteBalance;
  final String? focusMode;

  CameraSettings({
    this.iso,
    this.aperture,
    this.shutterSpeed,
    this.whiteBalance,
    this.focusMode,
  });

  factory CameraSettings.fromJson(Map<String, dynamic> json) {
    return CameraSettings(
      iso: json['iso'],
      aperture: json['aperture'],
      shutterSpeed: json['shutterSpeed'],
      whiteBalance: json['whiteBalance'],
      focusMode: json['focusMode'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'iso': iso,
      'aperture': aperture,
      'shutterSpeed': shutterSpeed,
      'whiteBalance': whiteBalance,
      'focusMode': focusMode,
    };
  }
}

// Key Change Model  
class KeyChange {
  final String parameter;
  final String change;
  final String explanation;

  KeyChange({
    required this.parameter,
    required this.change,
    required this.explanation,
  });

  factory KeyChange.fromJson(Map<String, dynamic> json) {
    return KeyChange(
      parameter: json['parameter'] ?? '',
      change: json['change'] ?? '',
      explanation: json['explanation'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'parameter': parameter,
      'change': change,
      'explanation': explanation,
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
  final LearningPath learningPath;
  final ProgressStatistics statistics;
  final List<Achievement> achievements;

  UserProgress({
    required this.userId,
    this.completedTutorials = const [],
    this.totalLearningTime = 0,
    this.currentLevel = 'beginner',
    this.completionPercentage = 0.0,
    LearningPath? learningPath,
    ProgressStatistics? statistics,
    this.achievements = const [],
  }) : learningPath = learningPath ?? LearningPath(),
       statistics = statistics ?? ProgressStatistics();

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

// Missing types for education service
class GlossaryResponse {
  final List<GlossaryTerm> terms;
  final List<GlossaryTerm> glossary;
  final int total;

  GlossaryResponse({
    this.terms = const [],
    this.total = 0,
  }) : glossary = terms;

  factory GlossaryResponse.fromJson(Map<String, dynamic> json) {
    return GlossaryResponse(
      terms: (json['terms'] as List?)
          ?.map((e) => GlossaryTerm.fromJson(e))
          .toList() ?? [],
      total: json['total'] ?? 0,
    );
  }
}

class GlossaryTerm {
  final String id;
  final String term;
  final String definition;
  final String category;
  final String plainLanguageExplanation;
  final String difficulty;
  final List<String> tags;
  final List<String> examples;
  final List<String> relatedTerms;

  GlossaryTerm({
    required this.id,
    required this.term,
    required this.definition,
    required this.category,
    this.plainLanguageExplanation = '',
    this.difficulty = 'beginner',
    this.tags = const [],
    this.examples = const [],
    this.relatedTerms = const [],
  });

  factory GlossaryTerm.fromJson(Map<String, dynamic> json) {
    return GlossaryTerm(
      id: json['id'] ?? '',
      term: json['term'] ?? '',
      definition: json['definition'] ?? '',
      category: json['category'] ?? '',
      plainLanguageExplanation: json['plainLanguageExplanation'] ?? '',
      difficulty: json['difficulty'] ?? 'beginner',
      tags: List<String>.from(json['tags'] ?? []),
      examples: List<String>.from(json['examples'] ?? []),
      relatedTerms: List<String>.from(json['relatedTerms'] ?? []),
    );
  }
}

class LearningPreferences {
  final String userId;
  final String difficulty;
  final List<String> interests;

  LearningPreferences({
    required this.userId,
    this.difficulty = 'beginner',
    this.interests = const [],
  });

  factory LearningPreferences.fromJson(Map<String, dynamic> json) {
    return LearningPreferences(
      userId: json['userId'] ?? '',
      difficulty: json['difficulty'] ?? 'beginner',
      interests: List<String>.from(json['interests'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'difficulty': difficulty,
      'interests': interests,
    };
  }
}

class ContextualHelpResponse {
  final String help;
  final List<String> tips;
  final String contextualHelp;

  ContextualHelpResponse({
    this.help = '',
    this.tips = const [],
  }) : contextualHelp = help;

  factory ContextualHelpResponse.fromJson(Map<String, dynamic> json) {
    return ContextualHelpResponse(
      help: json['help'] ?? '',
      tips: List<String>.from(json['tips'] ?? []),
    );
  }
}

// Additional missing classes
class HelpSuggestion {
  final String id;
  final String suggestion;
  final String type;
  final String title;
  final String content;
  final String actionText;
  final String actionTarget;

  HelpSuggestion({
    required this.id,
    required this.suggestion,
    this.type = 'general',
    this.title = '',
    this.content = '',
    this.actionText = '',
    this.actionTarget = '',
  });

  factory HelpSuggestion.fromJson(Map<String, dynamic> json) {
    return HelpSuggestion(
      id: json['id'] ?? '',
      suggestion: json['suggestion'] ?? '',
      type: json['type'] ?? 'general',
      title: json['title'] ?? '',
      content: json['content'] ?? '',
      actionText: json['actionText'] ?? '',
      actionTarget: json['actionTarget'] ?? '',
    );
  }
}

class GlossaryExample {
  final String example;
  final String description;

  GlossaryExample({
    required this.example,
    required this.description,
  });

  factory GlossaryExample.fromJson(Map<String, dynamic> json) {
    return GlossaryExample(
      example: json['example'] ?? '',
      description: json['description'] ?? '',
    );
  }
}

// Additional missing model classes
class TutorialMetadata {
  final bool featured;
  final double averageRating;
  final int ratingCount;

  TutorialMetadata({
    this.featured = false,
    this.averageRating = 0.0,
    this.ratingCount = 0,
  });

  factory TutorialMetadata.fromJson(Map<String, dynamic> json) {
    return TutorialMetadata(
      featured: json['featured'] ?? false,
      averageRating: (json['averageRating'] ?? 0.0).toDouble(),
      ratingCount: json['ratingCount'] ?? 0,
    );
  }
}

class LearningPath {
  final String currentStep;
  final int totalSteps;
  final double progress;

  LearningPath({
    this.currentStep = '',
    this.totalSteps = 0,
    this.progress = 0.0,
  });

  factory LearningPath.fromJson(Map<String, dynamic> json) {
    return LearningPath(
      currentStep: json['currentStep'] ?? '',
      totalSteps: json['totalSteps'] ?? 0,
      progress: (json['progress'] ?? 0.0).toDouble(),
    );
  }
}

class ProgressStatistics {
  final int completedTutorials;
  final int totalTime;
  final double averageScore;

  ProgressStatistics({
    this.completedTutorials = 0,
    this.totalTime = 0,
    this.averageScore = 0.0,
  });

  factory ProgressStatistics.fromJson(Map<String, dynamic> json) {
    return ProgressStatistics(
      completedTutorials: json['completedTutorials'] ?? 0,
      totalTime: json['totalTime'] ?? 0,
      averageScore: (json['averageScore'] ?? 0.0).toDouble(),
    );
  }
}

class Achievement {
  final String id;
  final String name;
  final String description;
  final bool unlocked;

  Achievement({
    required this.id,
    required this.name,
    required this.description,
    this.unlocked = false,
  });

  factory Achievement.fromJson(Map<String, dynamic> json) {
    return Achievement(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      unlocked: json['unlocked'] ?? false,
    );
  }
}