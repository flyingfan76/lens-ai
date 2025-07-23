const mongoose = require('mongoose');
const dotenv = require('dotenv');
const StylePresetService = require('../services/style_preset_service');
const EducationService = require('../services/education_service');
const logger = require('../utils/logger');

dotenv.config();

async function initializePresets() {
  try {
    // Connect to MongoDB
    if (!process.env.MONGODB_URI) {
      logger.error('MONGODB_URI environment variable not set');
      process.exit(1);
    }

    await mongoose.connect(process.env.MONGODB_URI);
    logger.info('Connected to MongoDB');

    // Initialize preset service and built-in presets
    const presetService = new StylePresetService();
    await presetService.initializeBuiltInPresets();

    logger.info('Built-in presets initialization completed successfully');
    
    // Initialize education content
    await EducationService.initializeDefaultContent();
    logger.info('Education content initialization completed successfully');
    
    // Get statistics
    const stats = await presetService.getPresetStatistics();
    logger.info('Preset Statistics:', stats);

  } catch (error) {
    logger.error('Failed to initialize presets:', error);
    process.exit(1);
  } finally {
    await mongoose.disconnect();
    logger.info('Disconnected from MongoDB');
  }
}

// Run the initialization
if (require.main === module) {
  initializePresets().then(() => {
    logger.info('Preset initialization script completed');
    process.exit(0);
  }).catch((error) => {
    logger.error('Preset initialization script failed:', error);
    process.exit(1);
  });
}

module.exports = { initializePresets };