const logger = require('../utils/logger');

class LearningEngine {
  constructor() {
    this.userModels = new Map();
    this.globalPatterns = new Map();
    this.adaptationRate = 0.1;
    this.confidenceThreshold = 0.7;
    
    // Learning configuration
    this.learningConfig = {
      minSamplesForAdaptation: 5,
      maxHistorySize: 1000,
      adaptationDecayRate: 0.95,
      patternDetectionThreshold: 0.6,
      personalizedWeighting: 0.3
    };
    
    // Pattern types we track
    this.patternTypes = {
      ISO_PREFERENCE: 'iso_preference',
      APERTURE_PREFERENCE: 'aperture_preference',
      SHUTTER_PREFERENCE: 'shutter_preference',
      SCENE_PREFERENCE: 'scene_preference',
      LIGHTING_ADAPTATION: 'lighting_adaptation',
      REJECTION_PATTERNS: 'rejection_patterns'
    };
  }

  // Initialize user model
  initializeUserModel(userId) {
    if (!this.userModels.has(userId)) {
      this.userModels.set(userId, {
        preferences: this.getDefaultPreferences(),
        patterns: new Map(),
        history: [],
        adaptationMetrics: {
          totalAdjustments: 0,
          acceptedSuggestions: 0,
          rejectedSuggestions: 0,
          manualOverrides: 0,
          learningScore: 0.5
        },
        lastUpdated: Date.now()
      });
    }
    return this.userModels.get(userId);
  }

  // Record user interaction with auto-adjustment
  recordUserFeedback(userId, interaction) {
    const userModel = this.initializeUserModel(userId);
    
    // Store interaction in history
    const record = {
      timestamp: Date.now(),
      sceneType: interaction.sceneType,
      lightingCondition: interaction.lightingCondition,
      originalSettings: interaction.originalSettings,
      suggestedSettings: interaction.suggestedSettings,
      finalSettings: interaction.finalSettings,
      userAction: interaction.userAction, // 'accepted', 'modified', 'rejected'
      confidence: interaction.confidence || 0.5,
      processingTime: interaction.processingTime
    };
    
    userModel.history.push(record);
    
    // Limit history size
    if (userModel.history.length > this.learningConfig.maxHistorySize) {
      userModel.history.shift();
    }
    
    // Update adaptation metrics
    this.updateAdaptationMetrics(userModel, record);
    
    // Learn from this interaction
    this.learnFromInteraction(userId, record);
    
    // Update global patterns
    this.updateGlobalPatterns(record);
    
    logger.debug(`Recorded user feedback for ${userId}: ${interaction.userAction}`);
  }

  // Learn patterns from user interaction
  learnFromInteraction(userId, record) {
    const userModel = this.userModels.get(userId);
    
    // Learn ISO preferences
    this.learnISOPreference(userModel, record);
    
    // Learn aperture preferences
    this.learnAperturePreference(userModel, record);
    
    // Learn shutter speed preferences
    this.learnShutterPreference(userModel, record);
    
    // Learn scene-specific preferences
    this.learnScenePreference(userModel, record);
    
    // Learn from rejections
    this.learnFromRejections(userModel, record);
    
    // Update overall learning score
    this.updateLearningScore(userModel);
    
    userModel.lastUpdated = Date.now();
  }

  learnISOPreference(userModel, record) {
    const patternKey = this.patternTypes.ISO_PREFERENCE;
    
    if (!userModel.patterns.has(patternKey)) {
      userModel.patterns.set(patternKey, {
        preferredRange: { min: 100, max: 800 },
        sceneSpecificPreferences: new Map(),
        confidence: 0.5,
        sampleCount: 0
      });
    }
    
    const pattern = userModel.patterns.get(patternKey);
    const finalISO = parseInt(record.finalSettings.iso);
    const suggestedISO = parseInt(record.suggestedSettings.iso);
    
    // If user accepted or only slightly modified ISO
    if (record.userAction === 'accepted' || Math.abs(finalISO - suggestedISO) < suggestedISO * 0.2) {
      // Reinforce current preference
      pattern.preferredRange.min = Math.min(pattern.preferredRange.min, finalISO * 0.8);
      pattern.preferredRange.max = Math.max(pattern.preferredRange.max, finalISO * 1.2);
    } else if (record.userAction === 'modified') {
      // Learn from user's modification
      const userPreference = finalISO / suggestedISO;
      
      if (userPreference < 0.8) {
        // User prefers lower ISO
        pattern.preferredRange.max = Math.min(pattern.preferredRange.max, finalISO * 1.1);
        userModel.preferences.preferLowISO = true;
        userModel.preferences.maxPreferredISO = Math.min(
          userModel.preferences.maxPreferredISO || 800,
          finalISO * 1.2
        );
      } else if (userPreference > 1.2) {
        // User accepts higher ISO
        pattern.preferredRange.max = Math.max(pattern.preferredRange.max, finalISO);
        userModel.preferences.allowHighISO = true;
      }
    }
    
    // Update scene-specific preferences
    const sceneKey = `${record.sceneType}_${record.lightingCondition}`;
    if (!pattern.sceneSpecificPreferences.has(sceneKey)) {
      pattern.sceneSpecificPreferences.set(sceneKey, { preferredISO: finalISO, samples: 1 });
    } else {
      const scenePreference = pattern.sceneSpecificPreferences.get(sceneKey);
      scenePreference.preferredISO = (scenePreference.preferredISO * scenePreference.samples + finalISO) / (scenePreference.samples + 1);
      scenePreference.samples++;
    }
    
    pattern.sampleCount++;
    pattern.confidence = Math.min(pattern.confidence + 0.1, 1.0);
  }

  learnAperturePreference(userModel, record) {
    const patternKey = this.patternTypes.APERTURE_PREFERENCE;
    
    if (!userModel.patterns.has(patternKey)) {
      userModel.patterns.set(patternKey, {
        preferredRange: { min: 1.4, max: 11 },
        scenePreferences: new Map(),
        bokehPreference: 0.5, // 0 = sharp, 1 = shallow DOF
        confidence: 0.5,
        sampleCount: 0
      });
    }
    
    const pattern = userModel.patterns.get(patternKey);
    const finalF = parseFloat(record.finalSettings.aperture.replace('f/', ''));
    const suggestedF = parseFloat(record.suggestedSettings.aperture.replace('f/', ''));
    
    if (record.userAction === 'modified') {
      const sceneType = record.sceneType;
      
      if (finalF < suggestedF) {
        // User prefers wider aperture
        pattern.bokehPreference = Math.min(pattern.bokehPreference + 0.1, 1.0);
        
        if (sceneType === 'portrait') {
          userModel.preferences.preferWideAperture = true;
        }
      } else if (finalF > suggestedF) {
        // User prefers smaller aperture (more sharp)
        pattern.bokehPreference = Math.max(pattern.bokehPreference - 0.1, 0.0);
      }
      
      // Store scene-specific preferences
      if (!pattern.scenePreferences.has(sceneType)) {
        pattern.scenePreferences.set(sceneType, { preferredF: finalF, samples: 1 });
      } else {
        const scenePreference = pattern.scenePreferences.get(sceneType);
        scenePreference.preferredF = (scenePreference.preferredF * scenePreference.samples + finalF) / (scenePreference.samples + 1);
        scenePreference.samples++;
      }
    }
    
    pattern.sampleCount++;
    pattern.confidence = Math.min(pattern.confidence + 0.1, 1.0);
  }

  learnShutterPreference(userModel, record) {
    const patternKey = this.patternTypes.SHUTTER_PREFERENCE;
    
    if (!userModel.patterns.has(patternKey)) {
      userModel.patterns.set(patternKey, {
        minimumShutterSpeeds: new Map(),
        handShakeThreshold: 1/60,
        motionBlurTolerance: 0.5,
        confidence: 0.5,
        sampleCount: 0
      });
    }
    
    const pattern = userModel.patterns.get(patternKey);
    const finalShutter = this.parseShutterSpeed(record.finalSettings.shutter_speed);
    const suggestedShutter = this.parseShutterSpeed(record.suggestedSettings.shutter_speed);
    
    if (record.userAction === 'modified' && finalShutter !== suggestedShutter) {
      const sceneType = record.sceneType;
      
      // Learn minimum shutter speeds per scene type
      if (!pattern.minimumShutterSpeeds.has(sceneType)) {
        pattern.minimumShutterSpeeds.set(sceneType, finalShutter);
      } else {
        const currentMin = pattern.minimumShutterSpeeds.get(sceneType);
        if (finalShutter < currentMin) {
          pattern.minimumShutterSpeeds.set(sceneType, finalShutter);
        }
      }
      
      // Update user preferences
      if (sceneType === 'sports' && finalShutter < 1/500) {
        userModel.preferences.minSportsShutter = finalShutter;
      }
      
      if (!userModel.preferences.minimumShutterSpeed || finalShutter < this.parseShutterSpeed(userModel.preferences.minimumShutterSpeed)) {
        userModel.preferences.minimumShutterSpeed = record.finalSettings.shutter_speed;
      }
    }
    
    pattern.sampleCount++;
    pattern.confidence = Math.min(pattern.confidence + 0.1, 1.0);
  }

  learnScenePreference(userModel, record) {
    const patternKey = this.patternTypes.SCENE_PREFERENCE;
    
    if (!userModel.patterns.has(patternKey)) {
      userModel.patterns.set(patternKey, {
        sceneFrequency: new Map(),
        timeOfDayPreferences: new Map(),
        settingPatterns: new Map(),
        confidence: 0.5
      });
    }
    
    const pattern = userModel.patterns.get(patternKey);
    const sceneType = record.sceneType;
    
    // Track scene frequency
    const currentCount = pattern.sceneFrequency.get(sceneType) || 0;
    pattern.sceneFrequency.set(sceneType, currentCount + 1);
    
    // Track time of day preferences
    const hour = new Date(record.timestamp).getHours();
    const timeSlot = this.getTimeSlot(hour);
    const timeKey = `${sceneType}_${timeSlot}`;
    
    if (!pattern.timeOfDayPreferences.has(timeKey)) {
      pattern.timeOfDayPreferences.set(timeKey, 1);
    } else {
      pattern.timeOfDayPreferences.set(timeKey, pattern.timeOfDayPreferences.get(timeKey) + 1);
    }
    
    // Store successful setting patterns for this scene
    if (record.userAction === 'accepted') {
      const settingKey = `${sceneType}_${record.lightingCondition}`;
      if (!pattern.settingPatterns.has(settingKey)) {
        pattern.settingPatterns.set(settingKey, []);
      }
      
      pattern.settingPatterns.get(settingKey).push({
        settings: record.finalSettings,
        timestamp: record.timestamp,
        confidence: record.confidence
      });
      
      // Keep only recent successful patterns
      const patterns = pattern.settingPatterns.get(settingKey);
      if (patterns.length > 10) {
        pattern.settingPatterns.set(settingKey, patterns.slice(-10));
      }
    }
    
    pattern.confidence = Math.min(pattern.confidence + 0.05, 1.0);
  }

  learnFromRejections(userModel, record) {
    if (record.userAction !== 'rejected') return;
    
    const patternKey = this.patternTypes.REJECTION_PATTERNS;
    
    if (!userModel.patterns.has(patternKey)) {
      userModel.patterns.set(patternKey, {
        rejectedSettings: [],
        commonRejectionReasons: new Map(),
        avoidancePatterns: new Map()
      });
    }
    
    const pattern = userModel.patterns.get(patternKey);
    
    // Store rejected setting for future avoidance
    pattern.rejectedSettings.push({
      settings: record.suggestedSettings,
      sceneType: record.sceneType,
      lightingCondition: record.lightingCondition,
      timestamp: record.timestamp
    });
    
    // Analyze rejection reasons
    const rejectionReason = this.analyzeRejectionReason(record);
    if (rejectionReason) {
      const currentCount = pattern.commonRejectionReasons.get(rejectionReason) || 0;
      pattern.commonRejectionReasons.set(rejectionReason, currentCount + 1);
    }
    
    // Keep only recent rejections
    if (pattern.rejectedSettings.length > 50) {
      pattern.rejectedSettings = pattern.rejectedSettings.slice(-50);
    }
  }

  // Generate personalized recommendations
  generatePersonalizedRecommendations(userId, analysis, baseSettings) {
    const userModel = this.userModels.get(userId);
    if (!userModel || userModel.adaptationMetrics.totalAdjustments < this.learningConfig.minSamplesForAdaptation) {
      return baseSettings; // Not enough data for personalization
    }
    
    const personalizedSettings = { ...baseSettings };
    
    // Apply learned preferences
    this.applyISOLearning(personalizedSettings, userModel, analysis);
    this.applyApertureLearning(personalizedSettings, userModel, analysis);
    this.applyShutterLearning(personalizedSettings, userModel, analysis);
    
    // Check against rejection patterns
    this.avoidRejectedPatterns(personalizedSettings, userModel, analysis);
    
    return personalizedSettings;
  }

  applyISOLearning(settings, userModel, analysis) {
    const isoPattern = userModel.patterns.get(this.patternTypes.ISO_PREFERENCE);
    if (!isoPattern || isoPattern.confidence < this.confidenceThreshold) return;
    
    const currentISO = parseInt(settings.iso);
    const sceneKey = `${analysis.scene_type}_${analysis.lighting_condition}`;
    
    // Use scene-specific preference if available
    if (isoPattern.sceneSpecificPreferences.has(sceneKey)) {
      const scenePreference = isoPattern.sceneSpecificPreferences.get(sceneKey);
      if (scenePreference.samples >= 3) {
        settings.iso = Math.round(scenePreference.preferredISO);
        return;
      }
    }
    
    // Apply general ISO range preference
    const clampedISO = Math.max(
      isoPattern.preferredRange.min,
      Math.min(isoPattern.preferredRange.max, currentISO)
    );
    
    if (clampedISO !== currentISO) {
      settings.iso = clampedISO;
    }
  }

  applyApertureLearning(settings, userModel, analysis) {
    const aperturePattern = userModel.patterns.get(this.patternTypes.APERTURE_PREFERENCE);
    if (!aperturePattern || aperturePattern.confidence < this.confidenceThreshold) return;
    
    const sceneType = analysis.scene_type;
    
    // Use scene-specific aperture preference
    if (aperturePattern.scenePreferences.has(sceneType)) {
      const scenePreference = aperturePattern.scenePreferences.get(sceneType);
      if (scenePreference.samples >= 3) {
        settings.aperture = `f/${scenePreference.preferredF}`;
        return;
      }
    }
    
    // Apply bokeh preference for portraits
    if (sceneType === 'portrait' && aperturePattern.bokehPreference > 0.7) {
      const currentF = parseFloat(settings.aperture.replace('f/', ''));
      if (currentF > 2.8) {
        settings.aperture = 'f/2.8';
      }
    }
  }

  applyShutterLearning(settings, userModel, analysis) {
    const shutterPattern = userModel.patterns.get(this.patternTypes.SHUTTER_PREFERENCE);
    if (!shutterPattern || shutterPattern.confidence < this.confidenceThreshold) return;
    
    const sceneType = analysis.scene_type;
    
    // Apply learned minimum shutter speeds
    if (shutterPattern.minimumShutterSpeeds.has(sceneType)) {
      const minShutter = shutterPattern.minimumShutterSpeeds.get(sceneType);
      const currentShutter = this.parseShutterSpeed(settings.shutter_speed);
      
      if (currentShutter > minShutter) {
        settings.shutter_speed = this.formatShutterSpeed(minShutter);
      }
    }
  }

  avoidRejectedPatterns(settings, userModel, analysis) {
    const rejectionPattern = userModel.patterns.get(this.patternTypes.REJECTION_PATTERNS);
    if (!rejectionPattern) return;
    
    // Check if current settings are too similar to previously rejected ones
    const similarRejections = rejectionPattern.rejectedSettings.filter(rejection => {
      return rejection.sceneType === analysis.scene_type &&
             rejection.lightingCondition === analysis.lighting_condition &&
             this.settingsSimilarity(settings, rejection.settings) > 0.8;
    });
    
    if (similarRejections.length > 2) {
      // Modify settings to avoid pattern
      this.modifyToAvoidRejection(settings, similarRejections);
    }
  }

  // Helper methods
  updateAdaptationMetrics(userModel, record) {
    const metrics = userModel.adaptationMetrics;
    metrics.totalAdjustments++;
    
    switch (record.userAction) {
      case 'accepted':
        metrics.acceptedSuggestions++;
        break;
      case 'rejected':
        metrics.rejectedSuggestions++;
        break;
      case 'modified':
        metrics.manualOverrides++;
        break;
    }
  }

  updateLearningScore(userModel) {
    const metrics = userModel.adaptationMetrics;
    if (metrics.totalAdjustments === 0) return;
    
    const acceptanceRate = metrics.acceptedSuggestions / metrics.totalAdjustments;
    const rejectionRate = metrics.rejectedSuggestions / metrics.totalAdjustments;
    
    // Learning score improves with higher acceptance and lower rejection
    metrics.learningScore = acceptanceRate * 0.7 + (1 - rejectionRate) * 0.3;
  }

  updateGlobalPatterns(record) {
    // Update global patterns for new users and fallback recommendations
    const globalKey = `${record.sceneType}_${record.lightingCondition}`;
    
    if (!this.globalPatterns.has(globalKey)) {
      this.globalPatterns.set(globalKey, {
        successfulSettings: [],
        commonAdjustments: new Map(),
        sampleCount: 0
      });
    }
    
    const globalPattern = this.globalPatterns.get(globalKey);
    
    if (record.userAction === 'accepted') {
      globalPattern.successfulSettings.push({
        settings: record.finalSettings,
        confidence: record.confidence,
        timestamp: record.timestamp
      });
      
      // Keep only recent successful settings
      if (globalPattern.successfulSettings.length > 100) {
        globalPattern.successfulSettings = globalPattern.successfulSettings.slice(-100);
      }
    }
    
    globalPattern.sampleCount++;
  }

  analyzeRejectionReason(record) {
    const suggested = record.suggestedSettings;
    const original = record.originalSettings;
    
    // Analyze what changed and might have caused rejection
    const isoChange = Math.abs(parseInt(suggested.iso) - parseInt(original.iso)) / parseInt(original.iso);
    const apertureChange = Math.abs(
      parseFloat(suggested.aperture.replace('f/', '')) - 
      parseFloat(original.aperture.replace('f/', ''))
    ) / parseFloat(original.aperture.replace('f/', ''));
    
    if (isoChange > 0.5) return 'iso_change_too_large';
    if (apertureChange > 0.3) return 'aperture_change_too_large';
    
    return 'unknown';
  }

  settingsSimilarity(settings1, settings2) {
    const iso1 = parseInt(settings1.iso);
    const iso2 = parseInt(settings2.iso);
    const isoSim = 1 - Math.abs(iso1 - iso2) / Math.max(iso1, iso2);
    
    const f1 = parseFloat(settings1.aperture.replace('f/', ''));
    const f2 = parseFloat(settings2.aperture.replace('f/', ''));
    const apertureSim = 1 - Math.abs(f1 - f2) / Math.max(f1, f2);
    
    return (isoSim + apertureSim) / 2;
  }

  modifyToAvoidRejection(settings, rejections) {
    // Simple avoidance strategy - make small adjustments
    const currentISO = parseInt(settings.iso);
    settings.iso = Math.round(currentISO * 0.9); // Slightly lower ISO
  }

  getDefaultPreferences() {
    return {
      preferLowISO: true,
      maxPreferredISO: 800,
      preferWideAperture: false,
      autoFocus: true,
      priorityMode: 'balanced',
      preserveAperture: false,
      allowHighISO: false
    };
  }

  parseShutterSpeed(shutterSpeedStr) {
    if (shutterSpeedStr.includes('/')) {
      const [numerator, denominator] = shutterSpeedStr.split('/').map(Number);
      return numerator / denominator;
    }
    return parseFloat(shutterSpeedStr);
  }

  formatShutterSpeed(seconds) {
    if (seconds < 1) {
      const denominator = Math.round(1 / seconds);
      return `1/${denominator}`;
    }
    return seconds.toString();
  }

  getTimeSlot(hour) {
    if (hour >= 6 && hour < 12) return 'morning';
    if (hour >= 12 && hour < 17) return 'afternoon';
    if (hour >= 17 && hour < 20) return 'evening';
    return 'night';
  }

  // Get learning insights for user
  getLearningInsights(userId) {
    const userModel = this.userModels.get(userId);
    if (!userModel) return [];
    
    const insights = [];
    const metrics = userModel.adaptationMetrics;
    
    // Acceptance rate insight
    if (metrics.totalAdjustments > 10) {
      const acceptanceRate = metrics.acceptedSuggestions / metrics.totalAdjustments;
      insights.push({
        type: 'acceptance_rate',
        message: `You accept ${Math.round(acceptanceRate * 100)}% of auto-adjustment suggestions`,
        confidence: 0.9
      });
    }
    
    // Scene preference insight
    const scenePattern = userModel.patterns.get(this.patternTypes.SCENE_PREFERENCE);
    if (scenePattern) {
      const mostCommonScene = [...scenePattern.sceneFrequency.entries()]
        .sort((a, b) => b[1] - a[1])[0];
      
      if (mostCommonScene && mostCommonScene[1] > 5) {
        insights.push({
          type: 'scene_preference',
          message: `You frequently shoot ${mostCommonScene[0]} scenes`,
          confidence: 0.8
        });
      }
    }
    
    // ISO preference insight
    const isoPattern = userModel.patterns.get(this.patternTypes.ISO_PREFERENCE);
    if (isoPattern && isoPattern.confidence > 0.7) {
      insights.push({
        type: 'iso_preference',
        message: `You prefer ISO range ${isoPattern.preferredRange.min}-${isoPattern.preferredRange.max}`,
        confidence: isoPattern.confidence
      });
    }
    
    return insights;
  }
}

module.exports = LearningEngine;