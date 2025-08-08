const mongoose = require('mongoose');
const dotenv = require('dotenv');
const EducationService = require('../services/education_service');
const logger = require('../utils/logger');

dotenv.config();

async function initializeEducation() {
  try {
    // Connect to MongoDB
    if (!process.env.MONGODB_URI) {
      logger.error('MONGODB_URI environment variable not set');
      process.exit(1);
    }

    await mongoose.connect(process.env.MONGODB_URI);
    logger.info('Connected to MongoDB');

    // Initialize education service and default content
    await EducationService.initializeDefaultContent();

    logger.info('Education content initialization completed successfully');

  } catch (error) {
    logger.error('Failed to initialize education content:', error);
    process.exit(1);
  } finally {
    await mongoose.disconnect();
    logger.info('Disconnected from MongoDB');
  }
}

// Run the initialization
if (require.main === module) {
  initializeEducation().then(() => {
    logger.info('Education initialization script completed');
    process.exit(0);
  }).catch((error) => {
    logger.error('Education initialization script failed:', error);
    process.exit(1);
  });
}

module.exports = { initializeEducation };