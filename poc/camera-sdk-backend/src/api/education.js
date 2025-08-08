const express = require('express');
const router = express.Router();
const { 
  Glossary, 
  Tutorial, 
  Comparison, 
  UserProgress, 
  ContextualHelp 
} = require('../models/Education');
const { authMiddleware, optionalAuth } = require('../middleware/auth');

// Glossary endpoints
router.get('/glossary', async (req, res) => {
  try {
    const { category, difficulty, search, limit = 20, page = 1 } = req.query;
    
    let query = { isActive: true };
    if (category) query.category = category;
    if (difficulty) query.difficulty = difficulty;
    
    let glossaryQuery;
    if (search) {
      glossaryQuery = Glossary.searchTerms(search);
    } else {
      glossaryQuery = Glossary.find(query);
    }
    
    const glossary = await glossaryQuery
      .limit(parseInt(limit))
      .skip((parseInt(page) - 1) * parseInt(limit))
      .sort({ term: 1 });
    
    const total = await Glossary.countDocuments(query);
    
    res.json({
      glossary,
      pagination: {
        current: parseInt(page),
        total: Math.ceil(total / parseInt(limit)),
        count: glossary.length,
        totalItems: total
      }
    });
  } catch (error) {
    console.error('Error fetching glossary:', error);
    res.status(500).json({ error: 'Failed to fetch glossary' });
  }
});

router.get('/glossary/:term', optionalAuth, async (req, res) => {
  try {
    const glossaryItem = await Glossary.findOne({ 
      term: new RegExp(req.params.term, 'i'), 
      isActive: true 
    });
    
    if (!glossaryItem) {
      return res.status(404).json({ error: 'Glossary term not found' });
    }
    
    // Track lookup if user is authenticated
    if (req.user) {
      await UserProgress.findOneAndUpdate(
        { userId: req.user.id },
        { 
          $push: { 
            glossaryLookups: { 
              term: glossaryItem.term,
              context: req.headers.referer || 'direct'
            }
          }
        },
        { upsert: true }
      );
    }
    
    res.json(glossaryItem);
  } catch (error) {
    console.error('Error fetching glossary term:', error);
    res.status(500).json({ error: 'Failed to fetch glossary term' });
  }
});

// Tutorial endpoints
router.get('/tutorials', async (req, res) => {
  try {
    const { category, difficulty, featured, limit = 10, page = 1 } = req.query;
    
    let query = { isActive: true };
    if (category) query.category = category;
    if (difficulty) query.difficulty = difficulty;
    if (featured === 'true') query['metadata.featured'] = true;
    
    const tutorials = await Tutorial.find(query)
      .select('-steps') // Don't include full tutorial content in list
      .limit(parseInt(limit))
      .skip((parseInt(page) - 1) * parseInt(limit))
      .sort({ 'metadata.averageRating': -1, createdAt: -1 });
    
    const total = await Tutorial.countDocuments(query);
    
    res.json({
      tutorials,
      pagination: {
        current: parseInt(page),
        total: Math.ceil(total / parseInt(limit)),
        count: tutorials.length,
        totalItems: total
      }
    });
  } catch (error) {
    console.error('Error fetching tutorials:', error);
    res.status(500).json({ error: 'Failed to fetch tutorials' });
  }
});

router.get('/tutorials/:id', async (req, res) => {
  try {
    const tutorial = await Tutorial.findOne({ 
      id: req.params.id, 
      isActive: true 
    });
    
    if (!tutorial) {
      return res.status(404).json({ error: 'Tutorial not found' });
    }
    
    res.json(tutorial);
  } catch (error) {
    console.error('Error fetching tutorial:', error);
    res.status(500).json({ error: 'Failed to fetch tutorial' });
  }
});

// Mark tutorial as completed (requires auth)
router.post('/tutorials/:id/complete', authMiddleware, async (req, res) => {
  try {
    const { completionTime, rating, feedback, score } = req.body;
    
    const tutorial = await Tutorial.findOne({ 
      id: req.params.id, 
      isActive: true 
    });
    
    if (!tutorial) {
      return res.status(404).json({ error: 'Tutorial not found' });
    }
    
    // Update user progress
    const userProgress = await UserProgress.findOneAndUpdate(
      { userId: req.user.id },
      {
        $push: {
          completedTutorials: {
            tutorialId: req.params.id,
            completionTime: completionTime || 0,
            rating,
            feedback,
            score
          }
        },
        $inc: {
          'statistics.tutorialsCompleted': 1,
          'statistics.totalLearningTime': completionTime || 0
        },
        $set: {
          'statistics.lastActiveDate': new Date()
        }
      },
      { upsert: true, new: true }
    );
    
    // Update tutorial rating if provided
    if (rating) {
      await tutorial.updateRating(rating);
    }
    
    // Update user's learning path
    await userProgress.updateLearningPath();
    
    res.json({ message: 'Tutorial marked as completed', userProgress });
  } catch (error) {
    console.error('Error completing tutorial:', error);
    res.status(500).json({ error: 'Failed to complete tutorial' });
  }
});

// Comparisons endpoints
router.get('/comparisons', async (req, res) => {
  try {
    const { category, difficulty, limit = 10, page = 1 } = req.query;
    
    let query = { isActive: true };
    if (category) query.category = category;
    if (difficulty) query.difficulty = difficulty;
    
    const comparisons = await Comparison.find(query)
      .limit(parseInt(limit))
      .skip((parseInt(page) - 1) * parseInt(limit))
      .sort({ difficulty: 1, createdAt: -1 });
    
    const total = await Comparison.countDocuments(query);
    
    res.json({
      comparisons,
      pagination: {
        current: parseInt(page),
        total: Math.ceil(total / parseInt(limit)),
        count: comparisons.length,
        totalItems: total
      }
    });
  } catch (error) {
    console.error('Error fetching comparisons:', error);
    res.status(500).json({ error: 'Failed to fetch comparisons' });
  }
});

router.get('/comparisons/:id', optionalAuth, async (req, res) => {
  try {
    const comparison = await Comparison.findOne({ 
      id: req.params.id, 
      isActive: true 
    });
    
    if (!comparison) {
      return res.status(404).json({ error: 'Comparison not found' });
    }
    
    // Track view if user is authenticated
    if (req.user) {
      await UserProgress.findOneAndUpdate(
        { userId: req.user.id },
        { 
          $push: { 
            viewedComparisons: { 
              comparisonId: req.params.id 
            }
          }
        },
        { upsert: true }
      );
    }
    
    res.json(comparison);
  } catch (error) {
    console.error('Error fetching comparison:', error);
    res.status(500).json({ error: 'Failed to fetch comparison' });
  }
});

// User progress endpoints (requires auth)
router.get('/progress', authMiddleware, async (req, res) => {
  try {
    let userProgress = await UserProgress.findOne({ userId: req.user.id });
    
    if (!userProgress) {
      userProgress = new UserProgress({ userId: req.user.id });
      await userProgress.save();
    }
    
    res.json(userProgress);
  } catch (error) {
    console.error('Error fetching user progress:', error);
    res.status(500).json({ error: 'Failed to fetch user progress' });
  }
});

router.put('/progress/preferences', authMiddleware, async (req, res) => {
  try {
    const { preferredDifficulty, enableNotifications, preferredLearningStyle } = req.body;
    
    const userProgress = await UserProgress.findOneAndUpdate(
      { userId: req.user.id },
      {
        $set: {
          'preferences.preferredDifficulty': preferredDifficulty,
          'preferences.enableNotifications': enableNotifications,
          'preferences.preferredLearningStyle': preferredLearningStyle
        }
      },
      { upsert: true, new: true }
    );
    
    res.json(userProgress);
  } catch (error) {
    console.error('Error updating preferences:', error);
    res.status(500).json({ error: 'Failed to update preferences' });
  }
});

// Contextual help endpoint
router.post('/contextual-help', optionalAuth, async (req, res) => {
  try {
    const { sceneType, cameraSettings, userLevel, commonIssues } = req.body;
    
    // Find matching contextual help
    const help = await ContextualHelp.find({
      isActive: true,
      $or: [
        { 'trigger.sceneType': sceneType },
        { 'trigger.userLevel': userLevel },
        { 'trigger.commonIssues': { $in: commonIssues } }
      ]
    }).sort({ 'suggestions.priority': 1 });
    
    // Get user's learning level if authenticated
    let userProgress;
    if (req.user) {
      userProgress = await UserProgress.findOne({ userId: req.user.id });
    }
    
    // Filter suggestions based on user level
    const filteredHelp = help.map(h => ({
      ...h.toObject(),
      suggestions: h.suggestions.filter(s => {
        if (!userProgress) return true;
        const userLevelPriority = { beginner: 1, intermediate: 2, advanced: 3 };
        const userCurrentLevel = userProgress.learningPath.currentLevel;
        return userLevelPriority[userCurrentLevel] >= userLevelPriority[h.trigger.userLevel];
      })
    }));
    
    res.json({ contextualHelp: filteredHelp });
  } catch (error) {
    console.error('Error fetching contextual help:', error);
    res.status(500).json({ error: 'Failed to fetch contextual help' });
  }
});

// Get learning recommendations
router.get('/recommendations', authMiddleware, async (req, res) => {
  try {
    const userProgress = await UserProgress.findOne({ userId: req.user.id });
    
    if (!userProgress) {
      // New user - recommend beginner tutorials
      const beginnerTutorials = await Tutorial.findByDifficulty('beginner').limit(5);
      return res.json({
        recommendedTutorials: beginnerTutorials,
        reason: 'Welcome! Start with these beginner tutorials.',
        userLevel: 'beginner'
      });
    }
    
    const userLevel = userProgress.learningPath.currentLevel;
    const completedIds = userProgress.completedTutorials.map(t => t.tutorialId);
    
    // Find tutorials user hasn't completed at their level
    const recommendedTutorials = await Tutorial.find({
      difficulty: userLevel,
      id: { $nin: completedIds },
      isActive: true
    }).limit(5).sort({ 'metadata.averageRating': -1 });
    
    // If no tutorials at current level, suggest next level
    if (recommendedTutorials.length === 0) {
      const nextLevel = userLevel === 'beginner' ? 'intermediate' : 'advanced';
      const nextLevelTutorials = await Tutorial.findByDifficulty(nextLevel).limit(5);
      
      return res.json({
        recommendedTutorials: nextLevelTutorials,
        reason: `Great job completing ${userLevel} level! Ready for ${nextLevel}?`,
        userLevel: nextLevel
      });
    }
    
    res.json({
      recommendedTutorials,
      reason: `Continue your ${userLevel} learning journey`,
      userLevel
    });
  } catch (error) {
    console.error('Error fetching recommendations:', error);
    res.status(500).json({ error: 'Failed to fetch recommendations' });
  }
});

// Search across all education content
router.get('/search', async (req, res) => {
  try {
    const { query, type, limit = 10 } = req.query;
    
    if (!query) {
      return res.status(400).json({ error: 'Search query is required' });
    }
    
    const results = {};
    
    if (!type || type === 'glossary') {
      results.glossary = await Glossary.searchTerms(query).limit(parseInt(limit));
    }
    
    if (!type || type === 'tutorials') {
      results.tutorials = await Tutorial.find({
        $text: { $search: query },
        isActive: true
      }).select('-steps').limit(parseInt(limit));
    }
    
    if (!type || type === 'comparisons') {
      results.comparisons = await Comparison.find({
        $or: [
          { title: new RegExp(query, 'i') },
          { description: new RegExp(query, 'i') },
          { lesson: new RegExp(query, 'i') }
        ],
        isActive: true
      }).limit(parseInt(limit));
    }
    
    res.json(results);
  } catch (error) {
    console.error('Error searching education content:', error);
    res.status(500).json({ error: 'Failed to search education content' });
  }
});

module.exports = router;