const { 
  Glossary, 
  Tutorial, 
  Comparison, 
  UserProgress, 
  ContextualHelp 
} = require('../models/Education');

class EducationService {
  
  // Initialize default educational content
  async initializeDefaultContent() {
    try {
      await this.createDefaultGlossary();
      await this.createDefaultTutorials();
      await this.createDefaultComparisons();
      await this.createDefaultContextualHelp();
      console.log('Default education content initialized successfully');
    } catch (error) {
      console.error('Error initializing default education content:', error);
      throw error;
    }
  }
  
  async createDefaultGlossary() {
    const defaultTerms = [
      {
        term: 'Aperture',
        category: 'exposure',
        plainLanguageExplanation: 'The opening in your lens that controls how much light enters the camera. A wider opening (lower f-number like f/1.4) lets in more light and creates a blurry background. A smaller opening (higher f-number like f/8) lets in less light but keeps more things in focus.',
        technicalDefinition: 'The diaphragm opening in a lens, measured in f-stops, that controls the amount of light entering the camera and affects depth of field.',
        relatedTerms: ['f-stop', 'depth of field', 'bokeh'],
        examples: [
          {
            scenario: 'Portrait photography',
            explanation: 'Use a wide aperture (f/1.4-f/2.8) to blur the background and make your subject stand out',
            visualExample: '/examples/portrait-aperture.jpg'
          }
        ],
        difficulty: 'beginner',
        tags: ['exposure triangle', 'basics']
      },
      {
        term: 'ISO',
        category: 'exposure',
        plainLanguageExplanation: 'How sensitive your camera sensor is to light. Lower ISO (100-400) is used in bright light and produces cleaner images. Higher ISO (1600+) is used in dark conditions but can make images look grainy or "noisy".',
        technicalDefinition: 'The sensor sensitivity to light, measured numerically (ISO 100, 200, 400, etc.). Higher values amplify the sensor signal but also increase digital noise.',
        relatedTerms: ['noise', 'grain', 'exposure'],
        examples: [
          {
            scenario: 'Indoor photography',
            explanation: 'Increase ISO to 800-1600 to capture images in dim lighting without using flash',
            visualExample: '/examples/iso-comparison.jpg'
          }
        ],
        difficulty: 'beginner',
        tags: ['exposure triangle', 'low light']
      },
      {
        term: 'Shutter Speed',
        category: 'exposure',
        plainLanguageExplanation: 'How long the camera sensor is exposed to light. Fast shutter speeds (1/500s) freeze motion but let in less light. Slow shutter speeds (1/30s) can blur motion but let in more light.',
        technicalDefinition: 'The duration for which the camera shutter remains open, controlling exposure time and motion blur effects.',
        relatedTerms: ['motion blur', 'camera shake', 'exposure'],
        examples: [
          {
            scenario: 'Sports photography',
            explanation: 'Use fast shutter speeds (1/500s or faster) to freeze moving subjects',
            visualExample: '/examples/shutter-speed-sports.jpg'
          }
        ],
        difficulty: 'beginner',
        tags: ['exposure triangle', 'motion']
      },
      {
        term: 'Bokeh',
        category: 'composition',
        plainLanguageExplanation: 'The quality of the blurred, out-of-focus areas in your photo. Good bokeh is smooth and creamy, while bad bokeh can be harsh or distracting.',
        technicalDefinition: 'The aesthetic quality of blur produced in out-of-focus areas of an image, influenced by lens design and aperture shape.',
        relatedTerms: ['aperture', 'depth of field', 'background blur'],
        difficulty: 'intermediate',
        tags: ['artistic effect', 'lens quality']
      }
    ];
    
    for (const term of defaultTerms) {
      await Glossary.findOneAndUpdate(
        { term: term.term },
        term,
        { upsert: true, new: true }
      );
    }
  }
  
  async createDefaultTutorials() {
    const defaultTutorials = [
      {
        id: 'exposure-triangle-basics',
        title: 'Understanding the Exposure Triangle',
        description: 'Master the fundamental relationship between aperture, shutter speed, and ISO',
        category: 'basics',
        difficulty: 'beginner',
        estimatedDuration: 15,
        steps: [
          {
            stepNumber: 1,
            title: 'What is the Exposure Triangle?',
            content: 'The exposure triangle consists of three elements that control how bright or dark your photo will be: Aperture (how wide the lens opening is), Shutter Speed (how long light hits the sensor), and ISO (how sensitive the sensor is to light).',
            contentType: 'text',
            tips: ['Think of it like filling a bucket with water - you can control the faucet opening (aperture), how long you leave it on (shutter speed), or use a more absorbent material (ISO)']
          },
          {
            stepNumber: 2,
            title: 'Aperture Control',
            content: 'Try adjusting your camera aperture. Notice how f/1.4 creates a shallow depth of field while f/8 keeps more in focus.',
            contentType: 'interactive',
            interactiveElements: [
              {
                type: 'slider',
                id: 'aperture-slider',
                label: 'Aperture (f-stop)',
                options: ['f/1.4', 'f/2.8', 'f/5.6', 'f/8', 'f/11'],
                explanation: 'Lower f-numbers = wider aperture = more background blur'
              }
            ],
            tips: ['Start with f/2.8 for portraits', 'Use f/8-f/11 for landscapes']
          }
        ],
        learningObjectives: [
          'Understand how aperture, shutter speed, and ISO work together',
          'Know when to adjust each setting',
          'Take properly exposed photos in any lighting condition'
        ],
        keyTakeaways: [
          'Each exposure setting affects both brightness and creative effects',
          'Changing one setting requires adjusting others to maintain proper exposure',
          'Practice with each setting individually before combining them'
        ],
        relatedGlossaryTerms: ['aperture', 'iso', 'shutter speed'],
        metadata: {
          featured: true
        }
      },
      {
        id: 'portrait-photography-basics',
        title: 'Portrait Photography Essentials',
        description: 'Learn to take stunning portraits with proper focus, lighting, and composition',
        category: 'scene_types',
        difficulty: 'beginner',
        estimatedDuration: 20,
        prerequisites: ['exposure-triangle-basics'],
        steps: [
          {
            stepNumber: 1,
            title: 'Camera Settings for Portraits',
            content: 'For portraits, use a wide aperture (f/1.4-f/2.8) to blur the background and make your subject stand out. Keep ISO low (100-400) when possible, and use a shutter speed fast enough to avoid camera shake.',
            contentType: 'text',
            tips: ['Focus on the eyes - they should always be sharp', 'Consider using single-point autofocus for precision']
          }
        ],
        learningObjectives: [
          'Master portrait camera settings',
          'Understand portrait composition rules',
          'Learn basic portrait lighting techniques'
        ]
      }
    ];
    
    for (const tutorial of defaultTutorials) {
      await Tutorial.findOneAndUpdate(
        { id: tutorial.id },
        tutorial,
        { upsert: true, new: true }
      );
    }
  }
  
  async createDefaultComparisons() {
    const defaultComparisons = [
      {
        id: 'aperture-comparison-portrait',
        title: 'Aperture Effects on Portrait Background',
        description: 'See how different aperture settings affect background blur in portrait photography',
        category: 'aperture',
        beforeImage: {
          url: '/comparisons/before-f8-portrait.jpg',
          settings: {
            iso: 200,
            aperture: 'f/8',
            shutterSpeed: '1/125',
            focusMode: 'Single Point AF'
          },
          issues: ['Background is distracting', 'Subject doesn\'t stand out', 'Everything is in focus']
        },
        afterImage: {
          url: '/comparisons/after-f1.4-portrait.jpg',
          settings: {
            iso: 200,
            aperture: 'f/1.4',
            shutterSpeed: '1/250',
            focusMode: 'Single Point AF'
          },
          improvements: ['Beautiful background blur', 'Subject is isolated', 'Professional look']
        },
        keyChanges: [
          {
            parameter: 'Aperture',
            change: 'f/8 → f/1.4',
            explanation: 'Opened aperture to create shallow depth of field',
            impact: 'Background became beautifully blurred (bokeh effect)'
          },
          {
            parameter: 'Shutter Speed',
            change: '1/125 → 1/250',
            explanation: 'Increased to compensate for wider aperture',
            impact: 'Maintained proper exposure despite more light entering'
          }
        ],
        lesson: 'Wide apertures (low f-numbers) create background blur that helps isolate your portrait subject, making them the clear focus of the image.',
        difficulty: 'beginner',
        tags: ['portrait', 'aperture', 'bokeh'],
        relatedTutorials: ['portrait-photography-basics']
      }
    ];
    
    for (const comparison of defaultComparisons) {
      await Comparison.findOneAndUpdate(
        { id: comparison.id },
        comparison,
        { upsert: true, new: true }
      );
    }
  }
  
  async createDefaultContextualHelp() {
    const defaultHelp = [
      {
        trigger: {
          sceneType: 'portrait',
          userLevel: 'beginner',
          commonIssues: ['blurry_background_needed']
        },
        suggestions: [
          {
            type: 'adjustment',
            title: 'Create Background Blur',
            content: 'Use a wider aperture (lower f-number) like f/1.4 or f/2.8 to blur the background and make your subject stand out.',
            actionText: 'Adjust Aperture',
            actionTarget: 'aperture_control',
            priority: 'high'
          },
          {
            type: 'tutorial',
            title: 'Learn Portrait Basics',
            content: 'Master the fundamentals of portrait photography including aperture, focus, and composition.',
            actionText: 'Start Tutorial',
            actionTarget: 'portrait-photography-basics',
            priority: 'medium'
          }
        ]
      },
      {
        trigger: {
          sceneType: 'landscape',
          userLevel: 'beginner'
        },
        suggestions: [
          {
            type: 'adjustment',
            title: 'Keep Everything Sharp',
            content: 'Use a narrower aperture (higher f-number) like f/8-f/11 to keep both foreground and background in focus.',
            actionText: 'Adjust Aperture',
            actionTarget: 'aperture_control',
            priority: 'high'
          },
          {
            type: 'tip',
            title: 'Use a Tripod',
            content: 'Narrower apertures require slower shutter speeds. Use a tripod to avoid camera shake.',
            actionText: 'Learn More',
            actionTarget: 'tripod_techniques',
            priority: 'medium'
          }
        ]
      }
    ];
    
    for (const help of defaultHelp) {
      await ContextualHelp.create(help);
    }
  }
  
  // Get personalized learning recommendations
  async getPersonalizedRecommendations(userId) {
    try {
      const userProgress = await UserProgress.findOne({ userId });
      
      if (!userProgress) {
        // New user recommendations
        return {
          recommendedTutorials: await Tutorial.findByDifficulty('beginner').limit(3),
          reason: 'Welcome! Start with these foundational tutorials.',
          nextSteps: ['Complete the Exposure Triangle tutorial', 'Practice with your camera', 'Try the Portrait Basics tutorial']
        };
      }
      
      const completedTutorials = userProgress.completedTutorials.map(t => t.tutorialId);
      const userLevel = userProgress.learningPath.currentLevel;
      
      // Find relevant tutorials they haven't completed
      const recommendations = await Tutorial.find({
        id: { $nin: completedTutorials },
        difficulty: userLevel,
        isActive: true
      }).limit(3).sort({ 'metadata.averageRating': -1 });
      
      return {
        recommendedTutorials: recommendations,
        reason: `Continue your ${userLevel} journey`,
        userLevel,
        completionPercentage: userProgress.learningPath.completionPercentage
      };
    } catch (error) {
      console.error('Error getting personalized recommendations:', error);
      throw error;
    }
  }
  
  // Analyze user learning patterns
  async analyzeUserLearningPatterns(userId) {
    try {
      const userProgress = await UserProgress.findOne({ userId });
      
      if (!userProgress) {
        return { message: 'No learning data available yet' };
      }
      
      const patterns = {
        preferredCategories: this.getPreferredCategories(userProgress),
        learningVelocity: this.calculateLearningVelocity(userProgress),
        consistencyScore: this.calculateConsistencyScore(userProgress),
        recommendations: await this.getPersonalizedRecommendations(userId)
      };
      
      return patterns;
    } catch (error) {
      console.error('Error analyzing learning patterns:', error);
      throw error;
    }
  }
  
  getPreferredCategories(userProgress) {
    const categoryCount = {};
    
    userProgress.completedTutorials.forEach(tutorial => {
      // You'd need to fetch tutorial details to get category
      // For now, return placeholder
    });
    
    return categoryCount;
  }
  
  calculateLearningVelocity(userProgress) {
    const totalTutorials = userProgress.completedTutorials.length;
    const totalTime = userProgress.statistics.totalLearningTime;
    
    if (totalTime === 0) return 0;
    
    return totalTutorials / (totalTime / 60); // tutorials per hour
  }
  
  calculateConsistencyScore(userProgress) {
    // Simple consistency based on streak
    return Math.min(userProgress.statistics.consistencyStreak / 7, 1) * 100;
  }
}

module.exports = new EducationService();