import 'package:json_annotation/json_annotation.dart';

part 'education.g.dart';

// Glossary Models
@JsonSerializable()
class GlossaryTerm {
  final String term;
  final String category;
  final String plainLanguageExplanation;
  final String technicalDefinition;
  final List<String> relatedTerms;
  final List<GlossaryExample> examples;
  final String difficulty;
  final List<String> tags;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  GlossaryTerm({
    required this.term,
    required this.category,
    required this.plainLanguageExplanation,
    required this.technicalDefinition,
    this.relatedTerms = const [],
    this.examples = const [],
    required this.difficulty,
    this.tags = const [],
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory GlossaryTerm.fromJson(Map<String, dynamic> json) =>
      _$GlossaryTermFromJson(json);

  Map<String, dynamic> toJson() => _$GlossaryTermToJson(this);
}

@JsonSerializable()
class GlossaryExample {
  final String scenario;
  final String explanation;
  final String? visualExample;

  GlossaryExample({
    required this.scenario,
    required this.explanation,
    this.visualExample,
  });

  factory GlossaryExample.fromJson(Map<String, dynamic> json) =>
      _$GlossaryExampleFromJson(json);

  Map<String, dynamic> toJson() => _$GlossaryExampleToJson(this);
}

// Tutorial Models
@JsonSerializable()
class Tutorial {
  final String id;
  final String title;
  final String description;
  final String category;
  final String difficulty;
  final int estimatedDuration;
  final List<String> prerequisites;
  final List<TutorialStep> steps;
  final List<String> learningObjectives;
  final List<String> keyTakeaways;
  final List<PracticeExercise> practiceExercises;
  final List<String> relatedTutorials;
  final List<String> relatedGlossaryTerms;
  final TutorialMetadata metadata;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  Tutorial({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.difficulty,
    required this.estimatedDuration,
    this.prerequisites = const [],
    required this.steps,
    this.learningObjectives = const [],
    this.keyTakeaways = const [],
    this.practiceExercises = const [],
    this.relatedTutorials = const [],
    this.relatedGlossaryTerms = const [],
    required this.metadata,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Tutorial.fromJson(Map<String, dynamic> json) =>
      _$TutorialFromJson(json);

  Map<String, dynamic> toJson() => _$TutorialToJson(this);
}

@JsonSerializable()
class TutorialStep {
  final int stepNumber;
  final String title;
  final String content;
  final String contentType;
  final String? mediaUrl;
  final List<InteractiveElement> interactiveElements;
  final List<String> tips;
  final List<String> commonMistakes;

  TutorialStep({
    required this.stepNumber,
    required this.title,
    required this.content,
    this.contentType = 'text',
    this.mediaUrl,
    this.interactiveElements = const [],
    this.tips = const [],
    this.commonMistakes = const [],
  });

  factory TutorialStep.fromJson(Map<String, dynamic> json) =>
      _$TutorialStepFromJson(json);

  Map<String, dynamic> toJson() => _$TutorialStepToJson(this);
}

@JsonSerializable()
class InteractiveElement {
  final String type;
  final String id;
  final String label;
  final List<String> options;
  final String? correctAnswer;
  final String? explanation;

  InteractiveElement({
    required this.type,
    required this.id,
    required this.label,
    this.options = const [],
    this.correctAnswer,
    this.explanation,
  });

  factory InteractiveElement.fromJson(Map<String, dynamic> json) =>
      _$InteractiveElementFromJson(json);

  Map<String, dynamic> toJson() => _$InteractiveElementToJson(this);
}

@JsonSerializable()
class PracticeExercise {
  final String title;
  final String description;
  final String difficulty;
  final String expectedOutcome;

  PracticeExercise({
    required this.title,
    required this.description,
    required this.difficulty,
    required this.expectedOutcome,
  });

  factory PracticeExercise.fromJson(Map<String, dynamic> json) =>
      _$PracticeExerciseFromJson(json);

  Map<String, dynamic> toJson() => _$PracticeExerciseToJson(this);
}

@JsonSerializable()
class TutorialMetadata {
  final double completionRate;
  final double averageRating;
  final int totalRatings;
  final bool featured;

  TutorialMetadata({
    this.completionRate = 0.0,
    this.averageRating = 0.0,
    this.totalRatings = 0,
    this.featured = false,
  });

  factory TutorialMetadata.fromJson(Map<String, dynamic> json) =>
      _$TutorialMetadataFromJson(json);

  Map<String, dynamic> toJson() => _$TutorialMetadataToJson(this);
}

// Comparison Models
@JsonSerializable()
class Comparison {
  final String id;
  final String title;
  final String description;
  final String category;
  final ComparisonImage beforeImage;
  final ComparisonImage afterImage;
  final List<KeyChange> keyChanges;
  final String lesson;
  final String difficulty;
  final List<String> tags;
  final List<String> relatedTutorials;
  final List<String> relatedComparisons;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  Comparison({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.beforeImage,
    required this.afterImage,
    required this.keyChanges,
    required this.lesson,
    this.difficulty = 'beginner',
    this.tags = const [],
    this.relatedTutorials = const [],
    this.relatedComparisons = const [],
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Comparison.fromJson(Map<String, dynamic> json) =>
      _$ComparisonFromJson(json);

  Map<String, dynamic> toJson() => _$ComparisonToJson(this);
}

@JsonSerializable()
class ComparisonImage {
  final String url;
  final CameraSettings settings;
  final List<String> issues;
  final List<String>? improvements;

  ComparisonImage({
    required this.url,
    required this.settings,
    this.issues = const [],
    this.improvements,
  });

  factory ComparisonImage.fromJson(Map<String, dynamic> json) =>
      _$ComparisonImageFromJson(json);

  Map<String, dynamic> toJson() => _$ComparisonImageToJson(this);
}

@JsonSerializable()
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

  factory CameraSettings.fromJson(Map<String, dynamic> json) =>
      _$CameraSettingsFromJson(json);

  Map<String, dynamic> toJson() => _$CameraSettingsToJson(this);
}

@JsonSerializable()
class KeyChange {
  final String parameter;
  final String change;
  final String explanation;
  final String impact;

  KeyChange({
    required this.parameter,
    required this.change,
    required this.explanation,
    required this.impact,
  });

  factory KeyChange.fromJson(Map<String, dynamic> json) =>
      _$KeyChangeFromJson(json);

  Map<String, dynamic> toJson() => _$KeyChangeToJson(this);
}

// User Progress Models
@JsonSerializable()
class UserProgress {
  final String userId;
  final List<CompletedTutorial> completedTutorials;
  final List<ViewedComparison> viewedComparisons;
  final List<GlossaryLookup> glossaryLookups;
  final LearningPath learningPath;
  final List<Achievement> achievements;
  final LearningPreferences preferences;
  final LearningStatistics statistics;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserProgress({
    required this.userId,
    this.completedTutorials = const [],
    this.viewedComparisons = const [],
    this.glossaryLookups = const [],
    required this.learningPath,
    this.achievements = const [],
    required this.preferences,
    required this.statistics,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserProgress.fromJson(Map<String, dynamic> json) =>
      _$UserProgressFromJson(json);

  Map<String, dynamic> toJson() => _$UserProgressToJson(this);
}

@JsonSerializable()
class CompletedTutorial {
  final String tutorialId;
  final DateTime completedAt;
  final int? completionTime;
  final int? rating;
  final String? feedback;
  final int? score;

  CompletedTutorial({
    required this.tutorialId,
    required this.completedAt,
    this.completionTime,
    this.rating,
    this.feedback,
    this.score,
  });

  factory CompletedTutorial.fromJson(Map<String, dynamic> json) =>
      _$CompletedTutorialFromJson(json);

  Map<String, dynamic> toJson() => _$CompletedTutorialToJson(this);
}

@JsonSerializable()
class ViewedComparison {
  final String comparisonId;
  final DateTime viewedAt;
  final int? timeSpent;

  ViewedComparison({
    required this.comparisonId,
    required this.viewedAt,
    this.timeSpent,
  });

  factory ViewedComparison.fromJson(Map<String, dynamic> json) =>
      _$ViewedComparisonFromJson(json);

  Map<String, dynamic> toJson() => _$ViewedComparisonToJson(this);
}

@JsonSerializable()
class GlossaryLookup {
  final String term;
  final DateTime lookedUpAt;
  final String? context;

  GlossaryLookup({
    required this.term,
    required this.lookedUpAt,
    this.context,
  });

  factory GlossaryLookup.fromJson(Map<String, dynamic> json) =>
      _$GlossaryLookupFromJson(json);

  Map<String, dynamic> toJson() => _$GlossaryLookupToJson(this);
}

@JsonSerializable()
class LearningPath {
  final String currentLevel;
  final List<String> recommendedTutorials;
  final String? nextSuggestedTutorial;
  final double completionPercentage;

  LearningPath({
    this.currentLevel = 'beginner',
    this.recommendedTutorials = const [],
    this.nextSuggestedTutorial,
    this.completionPercentage = 0.0,
  });

  factory LearningPath.fromJson(Map<String, dynamic> json) =>
      _$LearningPathFromJson(json);

  Map<String, dynamic> toJson() => _$LearningPathToJson(this);
}

@JsonSerializable()
class Achievement {
  final String id;
  final String name;
  final String description;
  final DateTime earnedAt;
  final String? icon;

  Achievement({
    required this.id,
    required this.name,
    required this.description,
    required this.earnedAt,
    this.icon,
  });

  factory Achievement.fromJson(Map<String, dynamic> json) =>
      _$AchievementFromJson(json);

  Map<String, dynamic> toJson() => _$AchievementToJson(this);
}

@JsonSerializable()
class LearningPreferences {
  final String preferredDifficulty;
  final bool enableNotifications;
  final String preferredLearningStyle;

  LearningPreferences({
    this.preferredDifficulty = 'beginner',
    this.enableNotifications = true,
    this.preferredLearningStyle = 'mixed',
  });

  factory LearningPreferences.fromJson(Map<String, dynamic> json) =>
      _$LearningPreferencesFromJson(json);

  Map<String, dynamic> toJson() => _$LearningPreferencesToJson(this);
}

@JsonSerializable()
class LearningStatistics {
  final int totalLearningTime;
  final int tutorialsCompleted;
  final double averageCompletionTime;
  final String? favoriteCategory;
  final int consistencyStreak;
  final DateTime? lastActiveDate;

  LearningStatistics({
    this.totalLearningTime = 0,
    this.tutorialsCompleted = 0,
    this.averageCompletionTime = 0.0,
    this.favoriteCategory,
    this.consistencyStreak = 0,
    this.lastActiveDate,
  });

  factory LearningStatistics.fromJson(Map<String, dynamic> json) =>
      _$LearningStatisticsFromJson(json);

  Map<String, dynamic> toJson() => _$LearningStatisticsToJson(this);
}

// Contextual Help Models
@JsonSerializable()
class ContextualHelp {
  final HelpTrigger trigger;
  final List<HelpSuggestion> suggestions;
  final bool isActive;

  ContextualHelp({
    required this.trigger,
    required this.suggestions,
    this.isActive = true,
  });

  factory ContextualHelp.fromJson(Map<String, dynamic> json) =>
      _$ContextualHelpFromJson(json);

  Map<String, dynamic> toJson() => _$ContextualHelpToJson(this);
}

@JsonSerializable()
class HelpTrigger {
  final String? sceneType;
  final CameraSettings? cameraSettings;
  final String? userLevel;
  final List<String> commonIssues;

  HelpTrigger({
    this.sceneType,
    this.cameraSettings,
    this.userLevel,
    this.commonIssues = const [],
  });

  factory HelpTrigger.fromJson(Map<String, dynamic> json) =>
      _$HelpTriggerFromJson(json);

  Map<String, dynamic> toJson() => _$HelpTriggerToJson(this);
}

@JsonSerializable()
class HelpSuggestion {
  final String type;
  final String title;
  final String content;
  final String actionText;
  final String? actionTarget;
  final String priority;

  HelpSuggestion({
    required this.type,
    required this.title,
    required this.content,
    required this.actionText,
    this.actionTarget,
    this.priority = 'medium',
  });

  factory HelpSuggestion.fromJson(Map<String, dynamic> json) =>
      _$HelpSuggestionFromJson(json);

  Map<String, dynamic> toJson() => _$HelpSuggestionToJson(this);
}

// API Response Models
@JsonSerializable()
class GlossaryResponse {
  final List<GlossaryTerm> glossary;
  final PaginationInfo pagination;

  GlossaryResponse({
    required this.glossary,
    required this.pagination,
  });

  factory GlossaryResponse.fromJson(Map<String, dynamic> json) =>
      _$GlossaryResponseFromJson(json);

  Map<String, dynamic> toJson() => _$GlossaryResponseToJson(this);
}

@JsonSerializable()
class TutorialResponse {
  final List<Tutorial> tutorials;
  final PaginationInfo pagination;

  TutorialResponse({
    required this.tutorials,
    required this.pagination,
  });

  factory TutorialResponse.fromJson(Map<String, dynamic> json) =>
      _$TutorialResponseFromJson(json);

  Map<String, dynamic> toJson() => _$TutorialResponseToJson(this);
}

@JsonSerializable()
class ComparisonResponse {
  final List<Comparison> comparisons;
  final PaginationInfo pagination;

  ComparisonResponse({
    required this.comparisons,
    required this.pagination,
  });

  factory ComparisonResponse.fromJson(Map<String, dynamic> json) =>
      _$ComparisonResponseFromJson(json);

  Map<String, dynamic> toJson() => _$ComparisonResponseToJson(this);
}

@JsonSerializable()
class PaginationInfo {
  final int current;
  final int total;
  final int count;
  final int totalItems;

  PaginationInfo({
    required this.current,
    required this.total,
    required this.count,
    required this.totalItems,
  });

  factory PaginationInfo.fromJson(Map<String, dynamic> json) =>
      _$PaginationInfoFromJson(json);

  Map<String, dynamic> toJson() => _$PaginationInfoToJson(this);
}

@JsonSerializable()
class LearningRecommendations {
  final List<Tutorial> recommendedTutorials;
  final String reason;
  final String userLevel;
  final double? completionPercentage;

  LearningRecommendations({
    required this.recommendedTutorials,
    required this.reason,
    required this.userLevel,
    this.completionPercentage,
  });

  factory LearningRecommendations.fromJson(Map<String, dynamic> json) =>
      _$LearningRecommendationsFromJson(json);

  Map<String, dynamic> toJson() => _$LearningRecommendationsToJson(this);
}

@JsonSerializable()
class ContextualHelpResponse {
  final List<ContextualHelp> contextualHelp;

  ContextualHelpResponse({
    required this.contextualHelp,
  });

  factory ContextualHelpResponse.fromJson(Map<String, dynamic> json) =>
      _$ContextualHelpResponseFromJson(json);

  Map<String, dynamic> toJson() => _$ContextualHelpResponseToJson(this);
}