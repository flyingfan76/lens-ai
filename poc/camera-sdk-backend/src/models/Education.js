const mongoose = require('mongoose');

// Glossary for technical terms and plain language explanations
const GlossarySchema = new mongoose.Schema({
  term: {
    type: String,
    required: true,
    unique: true,
    trim: true,
    index: true
  },
  category: {
    type: String,
    enum: ['exposure', 'focus', 'composition', 'camera_controls', 'lighting', 'post_processing'],
    required: true,
    index: true
  },
  plainLanguageExplanation: {
    type: String,
    required: true,
    trim: true
  },
  technicalDefinition: {
    type: String,
    required: true,
    trim: true
  },
  relatedTerms: [String],
  examples: [{
    scenario: String,
    explanation: String,
    visualExample: String // URL to example image
  }],
  difficulty: {
    type: String,
    enum: ['beginner', 'intermediate', 'advanced'],
    default: 'beginner'
  },
  tags: [String],
  isActive: {
    type: Boolean,
    default: true
  }
}, {
  timestamps: true
});

// Interactive tutorials and lessons
const TutorialSchema = new mongoose.Schema({
  id: {
    type: String,
    required: true,
    unique: true,
    index: true
  },
  title: {
    type: String,
    required: true,
    trim: true
  },
  description: {
    type: String,
    required: true,
    trim: true
  },
  category: {
    type: String,
    enum: ['basics', 'exposure', 'composition', 'scene_types', 'advanced_techniques'],
    required: true,
    index: true
  },
  difficulty: {
    type: String,
    enum: ['beginner', 'intermediate', 'advanced'],
    required: true,
    index: true
  },
  estimatedDuration: {
    type: Number, // in minutes
    required: true
  },
  prerequisites: [String], // IDs of other tutorials
  
  steps: [{
    stepNumber: {
      type: Number,
      required: true
    },
    title: {
      type: String,
      required: true
    },
    content: {
      type: String,
      required: true
    },
    contentType: {
      type: String,
      enum: ['text', 'image', 'video', 'interactive', 'quiz'],
      default: 'text'
    },
    mediaUrl: String,
    interactiveElements: [{
      type: {
        type: String,
        enum: ['slider', 'button', 'dropdown', 'input', 'camera_control']
      },
      id: String,
      label: String,
      options: [String],
      correctAnswer: String,
      explanation: String
    }],
    tips: [String],
    commonMistakes: [String]
  }],
  
  learningObjectives: [String],
  keyTakeaways: [String],
  practiceExercises: [{
    title: String,
    description: String,
    difficulty: String,
    expectedOutcome: String
  }],
  
  relatedTutorials: [String],
  relatedGlossaryTerms: [String],
  
  metadata: {
    completionRate: {
      type: Number,
      default: 0
    },
    averageRating: {
      type: Number,
      default: 0
    },
    totalRatings: {
      type: Number,
      default: 0
    },
    featured: {
      type: Boolean,
      default: false
    }
  },
  
  isActive: {
    type: Boolean,
    default: true
  }
}, {
  timestamps: true
});

// Before/After comparison examples
const ComparisonSchema = new mongoose.Schema({
  id: {
    type: String,
    required: true,
    unique: true,
    index: true
  },
  title: {
    type: String,
    required: true,
    trim: true
  },
  description: {
    type: String,
    required: true,
    trim: true
  },
  category: {
    type: String,
    enum: ['exposure', 'aperture', 'shutter_speed', 'iso', 'white_balance', 'focus', 'composition'],
    required: true,
    index: true
  },
  
  beforeImage: {
    url: {
      type: String,
      required: true
    },
    settings: {
      iso: Number,
      aperture: String,
      shutterSpeed: String,
      whiteBalance: String,
      focusMode: String
    },
    issues: [String] // What's wrong with this shot
  },
  
  afterImage: {
    url: {
      type: String,
      required: true
    },
    settings: {
      iso: Number,
      aperture: String,
      shutterSpeed: String,
      whiteBalance: String,
      focusMode: String
    },
    improvements: [String] // What was fixed
  },
  
  keyChanges: [{
    parameter: String,
    change: String,
    explanation: String,
    impact: String
  }],
  
  lesson: {
    type: String,
    required: true
  },
  
  difficulty: {
    type: String,
    enum: ['beginner', 'intermediate', 'advanced'],
    default: 'beginner'
  },
  
  tags: [String],
  relatedTutorials: [String],
  relatedComparisons: [String],
  
  isActive: {
    type: Boolean,
    default: true
  }
}, {
  timestamps: true
});

// User progress tracking
const UserProgressSchema = new mongoose.Schema({
  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
    index: true
  },
  
  completedTutorials: [{
    tutorialId: {
      type: String,
      required: true
    },
    completedAt: {
      type: Date,
      default: Date.now
    },
    completionTime: Number, // in minutes
    rating: {
      type: Number,
      min: 1,
      max: 5
    },
    feedback: String,
    score: Number // quiz score if applicable
  }],
  
  viewedComparisons: [{
    comparisonId: String,
    viewedAt: {
      type: Date,
      default: Date.now
    },
    timeSpent: Number // in seconds  
  }],
  
  glossaryLookups: [{
    term: String,
    lookedUpAt: {
      type: Date,
      default: Date.now
    },
    context: String // where they looked it up from
  }],
  
  learningPath: {
    currentLevel: {
      type: String,
      enum: ['beginner', 'intermediate', 'advanced'],
      default: 'beginner'
    },
    recommendedTutorials: [String],
    nextSuggestedTutorial: String,
    completionPercentage: {
      type: Number,
      default: 0
    }
  },
  
  achievements: [{
    id: String,
    name: String,
    description: String,
    earnedAt: {
      type: Date,
      default: Date.now
    },
    icon: String
  }],
  
  preferences: {
    preferredDifficulty: {
      type: String,
      enum: ['beginner', 'intermediate', 'advanced'],
      default: 'beginner'
    },
    enableNotifications: {
      type: Boolean,
      default: true
    },
    preferredLearningStyle: {
      type: String,
      enum: ['visual', 'hands_on', 'reading', 'mixed'],
      default: 'mixed'
    }
  },
  
  statistics: {
    totalLearningTime: {
      type: Number,
      default: 0 // in minutes
    },
    tutorialsCompleted: {
      type: Number,
      default: 0
    },
    averageCompletionTime: {
      type: Number,
      default: 0
    },
    favoriteCategory: String,
    consistencyStreak: {
      type: Number,
      default: 0 // days
    },
    lastActiveDate: Date
  }
}, {
  timestamps: true
});

// Contextual help suggestions
const ContextualHelpSchema = new mongoose.Schema({
  trigger: {
    sceneType: String,
    cameraSettings: {
      iso: String, // range like "high", "low", "normal"
      aperture: String,
      shutterSpeed: String
    },
    userLevel: {
      type: String,
      enum: ['beginner', 'intermediate', 'advanced']
    },
    commonIssues: [String] // "underexposed", "blurry", "noisy"
  },
  
  suggestions: [{
    type: {
      type: String,
      enum: ['tip', 'tutorial', 'comparison', 'glossary', 'adjustment']
    },
    title: String,
    content: String,
    actionText: String, // "Learn more", "View tutorial", etc.
    actionTarget: String, // tutorial ID, comparison ID, etc.
    priority: {
      type: String,
      enum: ['high', 'medium', 'low'],
      default: 'medium'
    }
  }],
  
  isActive: {
    type: Boolean,
    default: true
  }
}, {
  timestamps: true
});

// Add indexes for performance
GlossarySchema.index({ term: 'text', plainLanguageExplanation: 'text' });
TutorialSchema.index({ title: 'text', description: 'text' });
TutorialSchema.index({ category: 1, difficulty: 1 });
ComparisonSchema.index({ category: 1, difficulty: 1 });
UserProgressSchema.index({ userId: 1 }, { unique: true });

// Virtual fields
TutorialSchema.virtual('isCompleted').get(function() {
  return this.metadata.completionRate > 0.8;
});

UserProgressSchema.virtual('level').get(function() {
  const completed = this.completedTutorials.length;
  if (completed < 5) return 'beginner';
  if (completed < 15) return 'intermediate';
  return 'advanced';
});

// Methods
TutorialSchema.methods.updateRating = function(newRating) {
  const currentTotal = this.metadata.averageRating * this.metadata.totalRatings;
  this.metadata.totalRatings += 1;
  this.metadata.averageRating = (currentTotal + newRating) / this.metadata.totalRatings;
  return this.save();
};

UserProgressSchema.methods.addAchievement = function(achievement) {
  const exists = this.achievements.find(a => a.id === achievement.id);
  if (!exists) {
    this.achievements.push(achievement);
    return this.save();
  }
  return Promise.resolve(this);
};

UserProgressSchema.methods.updateLearningPath = function() {
  const level = this.level;
  this.learningPath.currentLevel = level;
  
  // Update completion percentage based on level
  const levelRequirements = {
    beginner: 5,
    intermediate: 15,
    advanced: 30
  };
  
  const completed = this.completedTutorials.length;
  const required = levelRequirements[level];
  this.learningPath.completionPercentage = Math.min((completed / required) * 100, 100);
  
  return this.save();
};

// Static methods
TutorialSchema.statics.findByDifficulty = function(difficulty) {
  return this.find({ difficulty, isActive: true }).sort({ 'metadata.averageRating': -1 });
};

GlossarySchema.statics.searchTerms = function(query) {
  return this.find({
    $text: { $search: query },
    isActive: true
  }).sort({ score: { $meta: 'textScore' } });
};

ComparisonSchema.statics.findByCategory = function(category) {
  return this.find({ category, isActive: true }).sort({ difficulty: 1 });
};

module.exports = {
  Glossary: mongoose.model('Glossary', GlossarySchema),
  Tutorial: mongoose.model('Tutorial', TutorialSchema),
  Comparison: mongoose.model('Comparison', ComparisonSchema),
  UserProgress: mongoose.model('UserProgress', UserProgressSchema),
  ContextualHelp: mongoose.model('ContextualHelp', ContextualHelpSchema)
};