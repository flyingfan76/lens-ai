const express = require('express');
const multer = require('multer');
const sharp = require('sharp');
const fs = require('fs').promises;
const path = require('path');
const logger = require('../utils/logger');

const router = express.Router();

// Configure multer for image uploads
const upload = multer({
  storage: multer.memoryStorage(),
  limits: {
    fileSize: 10 * 1024 * 1024 // 10MB limit
  },
  fileFilter: (req, file, cb) => {
    if (file.mimetype.startsWith('image/')) {
      cb(null, true);
    } else {
      cb(new Error('Only image files are allowed'));
    }
  }
});

// Test AI provider connection
router.post('/test-connection', async (req, res) => {
  try {
    const { provider, apiKey, model, endpoint, advancedSettings } = req.body;
    
    logger.info(`Testing AI provider connection: ${provider} at ${endpoint || 'default endpoint'}`);
    
    const config = {
      provider,
      endpoint,
      advancedSettings
    };
    
    // Test connection based on provider
    let testResult;
    
    switch (provider) {
      case 'openai':
      case 'azure-openai':
        testResult = await testOpenAIConnection(apiKey, model, config);
        break;
      case 'gemini':
        testResult = await testGeminiConnection(apiKey, model, config);
        break;
      case 'claude':
        testResult = await testClaudeConnection(apiKey, model, config);
        break;
      // Chinese AI Providers
      case 'deepseek':
        testResult = await testChineseAIConnection('DeepSeek', apiKey, model, config);
        break;
      case 'zhipu':
        testResult = await testChineseAIConnection('智谱AI', apiKey, model, config);
        break;
      case 'baidu':
        testResult = await testChineseAIConnection('百度 ERNIE', apiKey, model, config);
        break;
      case 'alibaba':
        testResult = await testChineseAIConnection('阿里巴巴 通义千问', apiKey, model, config);
        break;
      case 'tencent':
        testResult = await testChineseAIConnection('腾讯 混元', apiKey, model, config);
        break;
      case 'moonshot':
        testResult = await testChineseAIConnection('月之暗面 Kimi', apiKey, model, config);
        break;
      case 'minimax':
        testResult = await testChineseAIConnection('MiniMax', apiKey, model, config);
        break;
      case 'sensetime':
        testResult = await testChineseAIConnection('商汤 日日新', apiKey, model, config);
        break;
      // Self-hosted
      case 'local':
        testResult = await testLocalAIConnection(config);
        break;
      case 'ollama':
        testResult = await testOllamaConnection(model, config);
        break;
      case 'custom':
        testResult = await testCustomEndpointConnection(apiKey, model, config);
        break;
      case 'mock':
        testResult = await testMockConnection();
        break;
      default:
        throw new Error(`Unsupported provider: ${provider}`);
    }
    
    res.json({
      success: true,
      provider,
      details: testResult
    });
    
  } catch (error) {
    logger.error('AI provider connection test failed:', error);
    res.status(400).json({
      success: false,
      error: error.message
    });
  }
});

// Analyze image with AI
router.post('/analyze-image', upload.single('image'), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ 
        success: false, 
        error: 'No image file provided' 
      });
    }

    const config = JSON.parse(req.body.config);
    const rawPrompt = req.body.prompt;
    
    // Extract context data from config for variable substitution
    const context = config.context || {};
    
    logger.info(`Analyzing image with ${config.provider}: ${req.file.originalname}`);
    
    // Process image
    const processedImage = await processImageForAI(req.file.buffer);
    
    // Run AI analysis
    const startTime = Date.now();
    let analysisResult;
    
    
    switch (config.provider) {
      case 'openai':
      case 'azure-openai':
        analysisResult = await analyzeWithOpenAI(processedImage, rawPrompt, config, context);
        break;
      case 'gemini':
        analysisResult = await analyzeWithGemini(processedImage, rawPrompt, config, context);
        break;
      case 'claude':
        analysisResult = await analyzeWithClaude(processedImage, rawPrompt, config, context);
        break;
      // Chinese AI Providers - use generic Chinese AI analysis
      case 'deepseek':
      case 'zhipu':
      case 'baidu':
      case 'alibaba':
      case 'tencent':
      case 'moonshot':
      case 'minimax':
      case 'sensetime':
        analysisResult = await analyzeWithChineseAI(processedImage, rawPrompt, config, context);
        break;
      case 'local':
        analysisResult = await analyzeWithLocalAI(processedImage, rawPrompt, config, context);
        break;
      case 'ollama':
        analysisResult = await analyzeWithOllama(processedImage, rawPrompt, config, context);
        break;
      case 'custom':
        analysisResult = await analyzeWithCustomEndpoint(processedImage, rawPrompt, config, context);
        break;
      case 'mock':
        analysisResult = await analyzeWithMockAI(processedImage, rawPrompt, config, context);
        break;
      default:
        throw new Error(`Unsupported provider: ${config.provider}`);
    }
    
    const responseTime = Date.now() - startTime;
    
    res.json({
      success: true,
      analysis: analysisResult.analysis,
      confidence: analysisResult.confidence,
      responseTime,
      usage: analysisResult.usage,
      cost: analysisResult.cost,
      provider: config.provider,
      model: config.model,
    });
    
  } catch (error) {
    logger.error('AI image analysis failed:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

// Batch compare providers
router.post('/compare-providers', upload.single('image'), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ 
        success: false, 
        error: 'No image file provided' 
      });
    }

    const { providers, prompt, baseConfig } = JSON.parse(req.body.config);
    
    logger.info(`Comparing providers: ${providers.join(', ')}`);
    
    const processedImage = await processImageForAI(req.file.buffer);
    const results = {};
    
    // Run analysis for each provider
    for (const provider of providers) {
      const config = { ...baseConfig, provider };
      const startTime = Date.now();
      
      try {
        let analysisResult;
        
        switch (provider) {
          case 'openai':
          case 'azure-openai':
            analysisResult = await analyzeWithOpenAI(processedImage, prompt, config);
            break;
          case 'gemini':
            analysisResult = await analyzeWithGemini(processedImage, prompt, config);
            break;
          case 'claude':
            analysisResult = await analyzeWithClaude(processedImage, prompt, config);
            break;
          case 'local':
            analysisResult = await analyzeWithLocalAI(processedImage, prompt, config);
            break;
          case 'ollama':
            analysisResult = await analyzeWithOllama(processedImage, prompt, config);
            break;
          case 'custom':
            analysisResult = await analyzeWithCustomEndpoint(processedImage, prompt, config);
            break;
          case 'mock':
            analysisResult = await analyzeWithMockAI(processedImage, prompt, config);
            break;
          default:
            throw new Error(`Unsupported provider: ${provider}`);
        }
        
        results[provider] = {
          success: true,
          analysis: analysisResult.analysis,
          confidence: analysisResult.confidence,
          responseTime: Date.now() - startTime,
          usage: analysisResult.usage,
          cost: analysisResult.cost
        };
        
      } catch (error) {
        results[provider] = {
          success: false,
          error: error.message,
          responseTime: Date.now() - startTime
        };
      }
    }
    
    res.json({
      success: true,
      results,
      timestamp: new Date().toISOString()
    });
    
  } catch (error) {
    logger.error('Provider comparison failed:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

// Provider-specific implementations

async function testOpenAIConnection(apiKey, model, config = {}) {
  if (!apiKey && config.provider !== 'ollama' && config.provider !== 'local') {
    throw new Error('API key is required for this provider');
  }
  
  // Mock test for now - in production, make actual API call to endpoint
  const endpoint = config.endpoint || 'https://api.openai.com/v1';
  
  return new Promise((resolve) => {
    setTimeout(() => {
      resolve({
        status: 'connected',
        endpoint,
        model,
        latency: '150ms',
        rateLimit: '10,000 tokens/min',
        provider: config.provider || 'openai'
      });
    }, 500);
  });
}

async function testGeminiConnection(apiKey, model, config = {}) {
  if (!apiKey) {
    throw new Error('Google API key is required');
  }
  
  const endpoint = config.endpoint || 'https://generativelanguage.googleapis.com/v1';
  
  return new Promise((resolve) => {
    setTimeout(() => {
      resolve({
        status: 'connected',
        endpoint,
        model,
        latency: '200ms',
        rateLimit: '60 requests/min'
      });
    }, 300);
  });
}

async function testClaudeConnection(apiKey, model, config = {}) {
  if (!apiKey) {
    throw new Error('Anthropic API key is required');
  }
  
  const endpoint = config.endpoint || 'https://api.anthropic.com';
  
  return new Promise((resolve) => {
    setTimeout(() => {
      resolve({
        status: 'connected',
        endpoint,
        model,
        latency: '250ms',
        rateLimit: '5 requests/min'
      });
    }, 400);
  });
}

async function testLocalAIConnection(config = {}) {
  const endpoint = config.endpoint || 'http://localhost:8000';
  
  return new Promise((resolve) => {
    setTimeout(() => {
      resolve({
        status: 'connected',
        endpoint,
        model: 'local-tensorflow',
        latency: '50ms',
        rateLimit: 'unlimited'
      });
    }, 100);
  });
}

async function testOllamaConnection(model, config = {}) {
  const endpoint = config.endpoint || 'http://localhost:11434';
  
  return new Promise((resolve) => {
    setTimeout(() => {
      resolve({
        status: 'connected',
        endpoint,
        model: model || 'llava:latest',
        latency: '80ms',
        rateLimit: 'unlimited',
        provider: 'ollama'
      });
    }, 200);
  });
}

async function testChineseAIConnection(providerName, apiKey, model, config = {}) {
  if (!apiKey) {
    throw new Error(`${providerName} API key is required`);
  }
  
  const endpoint = config.endpoint;
  
  return new Promise((resolve) => {
    setTimeout(() => {
      resolve({
        status: 'connected',
        endpoint,
        model,
        provider: providerName,
        latency: '180ms',
        rateLimit: 'varies by provider',
        region: 'China'
      });
    }, 400);
  });
}

async function testCustomEndpointConnection(apiKey, model, config = {}) {
  const endpoint = config.endpoint;
  const protocol = config.protocol || 'openai';
  
  if (!endpoint) {
    throw new Error('Custom endpoint URL is required');
  }
  
  return new Promise((resolve) => {
    setTimeout(() => {
      resolve({
        status: 'connected',
        endpoint,
        model: model || 'custom-model',
        protocol,
        latency: '120ms',
        rateLimit: 'depends on endpoint',
        provider: 'custom'
      });
    }, 300);
  });
}

async function testMockConnection() {
  return new Promise((resolve) => {
    setTimeout(() => {
      resolve({
        status: 'connected',
        model: 'mock-ai-v1',
        latency: '10ms',
        rateLimit: 'unlimited'
      });
    }, 50);
  });
}

// Variable substitution for custom prompts
function substitutePromptVariables(prompt, context = {}) {
  if (!prompt || typeof prompt !== 'string') {
    return prompt;
  }
  
  // Default context values
  const defaultContext = {
    camera_model: 'Test Camera',
    iso: '400',
    aperture: 'f/4.0',
    shutter_speed: '1/125',
    white_balance: 'auto',
    scene_type: 'general',
    lighting_conditions: 'normal',
    user_request: 'improve this photo',
    // Alternative naming conventions
    cameraModel: 'Test Camera',
    currentISO: '400',
    currentAperture: 'f/4.0',
    currentShutter: '1/125',
    currentWB: 'auto',
    sceneType: 'general',
    lightingConditions: 'normal',
    userRequest: 'improve this photo',
    // Additional variations
    current_iso: '400',
    current_aperture: 'f/4.0',
    current_shutter: '1/125',
    current_wb: 'auto',
    current_white_balance: 'auto',
    scene: 'general',
    lighting: 'normal'
  };
  
  // Merge with provided context
  const finalContext = { ...defaultContext, ...context };
  
  let result = prompt;
  
  // Replace all variable patterns
  Object.keys(finalContext).forEach(key => {
    const value = finalContext[key] || 'auto';
    result = result.replace(new RegExp(`\\{${key}\\}`, 'g'), value);
  });
  
  return result;
}

async function processImageForAI(imageBuffer) {
  // Resize and optimize image for AI processing
  const processedBuffer = await sharp(imageBuffer)
    .resize(1024, 1024, { fit: 'inside', withoutEnlargement: true })
    .jpeg({ quality: 90 })
    .toBuffer();
    
  return {
    buffer: processedBuffer,
    base64: processedBuffer.toString('base64'),
    mimeType: 'image/jpeg'
  };
}

async function analyzeWithOpenAI(image, prompt, config, context = {}) {
  // Substitute variables in prompt
  const processedPrompt = substitutePromptVariables(prompt, context);
  
  // Mock OpenAI analysis - replace with actual API call
  await new Promise(resolve => setTimeout(resolve, Math.random() * 1000 + 500));
  
  // Check if this is a JSON format request
  const isJSONRequest = processedPrompt.toLowerCase().includes('json format') || 
                       processedPrompt.toLowerCase().includes('return your response in json');
  
  let analysis;
  
  if (isJSONRequest) {
    // Return structured JSON response matching the requested format
    analysis = {
      recommended_settings: {
        iso: 800,
        aperture: 'f/2.8', 
        shutter_speed: '1/200',
        white_balance: 'daylight',
        scene: 'portrait',
        lighting: 'natural daylight'
      },
      reasoning: 'Based on OpenAI GPT-4V analysis of the image taken with Test Camera, the current settings (ISO 400, f/4.0, 1/125, auto WB) can be optimized. The scene appears to be a general scene in normal lighting conditions. Increasing ISO to 800 allows for a faster shutter speed of 1/200 to prevent motion blur, while opening the aperture to f/2.8 creates better subject separation. Daylight white balance will provide more accurate colors in the current lighting conditions.',
      alternative_approaches: [
        'Portrait mode with f/1.8 aperture for maximum background blur and subject isolation',
        'Use exposure compensation +0.3 stops to brighten the highlights while maintaining detail',
        'Switch to spot metering focused on the main subject for more precise exposure control'
      ],
      confidence: 0.87
    };
  } else {
    // Return regular analysis
    analysis = {
      recommended_settings: {
        iso: 800,
        aperture: 'f/2.8',
        shutter_speed: '1/200', 
        white_balance: 'daylight',
        scene: 'portrait',
        lighting: 'natural daylight'
      },
      reasoning: 'Based on OpenAI GPT-4V analysis, the image appears to be taken in good lighting conditions but could benefit from a slightly faster shutter speed to ensure sharpness and a wider aperture for better subject isolation.',
      alternative_approaches: [
        'Try shooting in aperture priority mode with f/1.8 for maximum background blur',
        'Consider using exposure compensation +0.3 to brighten the highlights',
        'Switch to spot metering for more precise exposure control'
      ],
      confidence: 0.87
    };
  }
  
  return {
    analysis,
    usage: {
      prompt_tokens: processedPrompt.length,
      completion_tokens: 180,
      total_tokens: processedPrompt.length + 180
    },
    cost: '$0.0189',
    confidence: analysis.confidence,
    processed_prompt: processedPrompt // Include processed prompt for debugging
  };
}

async function analyzeWithGemini(image, prompt, config, context = {}) {
  // Substitute variables in prompt
  const processedPrompt = substitutePromptVariables(prompt, context);
  
  // Mock Gemini analysis
  await new Promise(resolve => setTimeout(resolve, Math.random() * 800 + 400));
  
  // Check if this is a JSON format request
  const isJSONRequest = processedPrompt.toLowerCase().includes('json format') || 
                       processedPrompt.toLowerCase().includes('return your response in json');
  
  let analysis;
  
  if (isJSONRequest) {
    analysis = {
      recommended_settings: {
        iso: 400,
        aperture: 'f/4.0',
        shutter_speed: '1/125',
        white_balance: 'auto',
        scene: 'landscape',
        lighting: 'mixed lighting'
      },
      reasoning: 'Gemini Pro Vision analysis of the Test Camera image shows well-balanced exposure in normal lighting conditions. The current settings (ISO 400, f/4.0, 1/125, auto WB) are appropriate for the general scene. The model suggests maintaining these settings as they provide good balance between noise, depth of field, and motion blur while preserving natural color reproduction.',
      alternative_approaches: [
        'Manual white balance with custom Kelvin temperature around 5200K for warmer tones',
        'Focus stacking technique using multiple shots at f/8 for maximum sharpness across the entire frame',
        'HDR bracketing with 3-shot exposure sequence (-1, 0, +1 EV) for enhanced dynamic range'
      ],
      confidence: 0.82
    };
  } else {
    analysis = {
      recommended_settings: {
        iso: 400,
        aperture: 'f/4.0',
        shutter_speed: '1/125',
        white_balance: 'auto',
        scene: 'landscape',
        lighting: 'mixed lighting'
      },
      reasoning: 'Gemini Pro Vision analysis suggests the current exposure is well-balanced. Minor adjustments to ISO and aperture could improve overall image quality while maintaining natural color reproduction.',
      alternative_approaches: [
        'Use manual white balance with custom Kelvin temperature around 5200K',
        'Try focus stacking for maximum sharpness across the frame',
        'Consider HDR bracketing for better dynamic range'
      ],
      confidence: 0.82
    };
  }
  
  return {
    analysis,
    usage: {
      input_tokens: processedPrompt.length,
      output_tokens: 165,
      total_tokens: processedPrompt.length + 165
    },
    cost: '$0.0117',
    confidence: analysis.confidence,
    processed_prompt: processedPrompt
  };
}

async function analyzeWithClaude(image, prompt, config, context = {}) {
  // Substitute variables in prompt
  const processedPrompt = substitutePromptVariables(prompt, context);
  
  // Mock Claude analysis
  await new Promise(resolve => setTimeout(resolve, Math.random() * 1200 + 600));
  
  const isJSONRequest = processedPrompt.toLowerCase().includes('json format') || 
                       processedPrompt.toLowerCase().includes('return your response in json');
  
  let analysis;
  
  if (isJSONRequest) {
    analysis = {
      recommended_settings: {
        iso: 200,
        aperture: 'f/5.6',
        shutter_speed: '1/250',
        white_balance: 'cloudy',
        scene: 'outdoor',
        lighting: 'overcast'
      },
      reasoning: 'Claude 3 Sonnet analysis of the Test Camera image indicates good composition with optimization potential. Moving from the current settings (ISO 400, f/4.0, 1/125, auto WB) to lower ISO 200 will reduce noise significantly. The f/5.6 aperture provides optimal depth of field balance for general scenes, while 1/250 shutter speed ensures sharp results. Cloudy white balance is recommended for the normal lighting conditions to enhance color accuracy.',
      alternative_approaches: [
        'Graduated neutral density filter technique to balance bright sky with darker foreground elements',
        'Focus peaking with manual focus at f/8-f/11 to ensure critical sharpness across the scene',
        'Circular polarizing filter to reduce surface reflections and enhance color saturation, especially in outdoor scenes'
      ],
      confidence: 0.91
    };
  } else {
    analysis = {
      recommended_settings: {
        iso: 200,
        aperture: 'f/5.6',
        shutter_speed: '1/250',
        white_balance: 'cloudy',
        scene: 'outdoor',
        lighting: 'overcast'
      },
      reasoning: 'Claude 3 analysis indicates the image has good composition but the exposure could be optimized. Lower ISO will reduce noise while the suggested aperture provides good depth of field balance.',
      alternative_approaches: [
        'Use graduated neutral density filter to balance sky and foreground exposure',
        'Try focus peaking to ensure critical areas are sharp',
        'Consider polarizing filter to reduce reflections and enhance colors'
      ],
      confidence: 0.91
    };
  }
  
  return {
    analysis,
    usage: {
      input_tokens: processedPrompt.length,
      output_tokens: 195,
      total_tokens: processedPrompt.length + 195
    },
    cost: '$0.0338',
    confidence: analysis.confidence,
    processed_prompt: processedPrompt
  };
}

async function analyzeWithLocalAI(image, prompt, config, context = {}) {
  // Mock local AI analysis
  await new Promise(resolve => setTimeout(resolve, Math.random() * 200 + 100));
  
  return {
    analysis: {
      recommended_settings: {
        iso: 400,
        aperture: 'f/3.5',
        shutter_speed: '1/160',
        white_balance: 'auto'
      },
      reasoning: 'Local TensorFlow model analysis shows good overall exposure with potential for slight optimization. The suggested settings balance noise, depth of field, and motion blur considerations.',
      alternative_approaches: [
        'Increase contrast in post-processing for more dynamic look',
        'Use highlight recovery to preserve bright areas',
        'Apply local adjustments to enhance key areas'
      ],
      confidence: 0.76
    },
    usage: {
      model_inference_time: '45ms',
      preprocessing_time: '12ms',
      total_time: '57ms'
    },
    cost: '$0.00',
    confidence: 0.76
  };
}

async function analyzeWithOllama(image, prompt, config, context = {}) {
  // Mock Ollama analysis - replace with actual Ollama API call
  await new Promise(resolve => setTimeout(resolve, Math.random() * 300 + 200));
  
  return {
    analysis: {
      recommended_settings: {
        iso: 400,
        aperture: 'f/3.2',
        shutter_speed: '1/180',
        white_balance: 'auto'
      },
      reasoning: `Ollama ${config.model} analysis suggests adjusting settings for better local processing results. The recommended settings balance image quality with the capabilities of local vision models.`,
      alternative_approaches: [
        'Use manual focus for critical sharpness with local models',
        'Consider higher contrast settings for better AI recognition',
        'Try multiple exposures for local HDR processing'
      ],
      confidence: 0.84
    },
    usage: {
      processing_time: '180ms',
      local_inference: true
    },
    cost: '$0.00',
    confidence: 0.84
  };
}

async function analyzeWithChineseAI(image, prompt, config, context = {}) {
  // Mock Chinese AI analysis - replace with actual API calls to Chinese providers
  await new Promise(resolve => setTimeout(resolve, Math.random() * 600 + 300));
  
  const providerNames = {
    deepseek: 'DeepSeek 深度求索',
    zhipu: '智谱AI GLM',
    baidu: '百度 ERNIE',
    alibaba: '阿里巴巴 通义千问',
    tencent: '腾讯 混元',
    moonshot: '月之暗面 Kimi',
    minimax: 'MiniMax',
    sensetime: '商汤 日日新'
  };
  
  const providerName = providerNames[config.provider] || config.provider;
  
  return {
    analysis: {
      recommended_settings: {
        iso: 320,
        aperture: 'f/3.5',
        shutter_speed: '1/200',
        white_balance: 'auto'
      },
      reasoning: `${providerName} 分析建议：根据图像分析，推荐以上设置以获得最佳拍摄效果。该模型专为中文用户优化，提供符合国内摄影习惯的专业建议。Analysis from ${providerName}: Optimized settings for Chinese photography preferences and lighting conditions.`,
      alternative_approaches: [
        '考虑使用手动对焦以获得更精确的成像效果 Consider manual focus for precise results',
        '尝试不同的构图角度以增加视觉冲击力 Try different composition angles',
        '根据场景调整曝光补偿以优化细节表现 Adjust exposure compensation for scene details'
      ],
      confidence: 0.87
    },
    usage: {
      provider: providerName,
      model: config.model,
      endpoint: config.endpoint,
      region: 'China'
    },
    cost: '¥0.02',
    confidence: 0.87
  };
}

async function analyzeWithCustomEndpoint(image, prompt, config, context = {}) {
  // Mock custom endpoint analysis - replace with actual API call to config.endpoint
  await new Promise(resolve => setTimeout(resolve, Math.random() * 800 + 400));
  
  const endpoint = config.endpoint || 'custom-endpoint';
  const protocol = config.protocol || 'openai';
  
  const protocolSpecificRecommendations = {
    openai: {
      iso: 600,
      aperture: 'f/4.5',
      shutter_speed: '1/150',
      white_balance: 'cloudy',
      lighting_conditions: 'natural'
    },
    anthropic: {
      iso: 400,
      aperture: 'f/3.2',
      shutter_speed: '1/180',
      white_balance: 'daylight',
      lighting_conditions: 'bright'
    },
    vertex: {
      iso: 500,
      aperture: 'f/4.0',
      shutter_speed: '1/160',
      white_balance: 'auto',
      lighting_conditions: 'mixed'
    },
    custom: {
      iso: 450,
      aperture: 'f/3.8',
      shutter_speed: '1/140',
      white_balance: 'custom',
      lighting_conditions: 'ambient'
    }
  };
  
  return {
    analysis: {
      recommended_settings: protocolSpecificRecommendations[protocol] || protocolSpecificRecommendations.openai,
      reasoning: `Custom endpoint analysis from ${endpoint} using ${protocol.toUpperCase()} protocol. The settings are optimized based on your custom model's training and capabilities, providing tailored recommendations for your specific use case.`,
      alternative_approaches: [
        `Leverage ${protocol}-compatible model features for enhanced results`,
        'Try endpoint-optimized post-processing workflows',
        'Use model-specific metadata for better context understanding'
      ],
      confidence: 0.89
    },
    usage: {
      endpoint: endpoint,
      protocol: protocol,
      model: config.model,
      custom_processing: true
    },
    cost: 'varies',
    confidence: 0.89
  };
}

async function analyzeWithMockAI(image, prompt, config, context = {}) {
  // Substitute variables in prompt
  const processedPrompt = substitutePromptVariables(prompt, context);
  
  // Mock AI for testing
  await new Promise(resolve => setTimeout(resolve, Math.random() * 100 + 50));
  
  const isJSONRequest = processedPrompt.toLowerCase().includes('json format') || 
                       processedPrompt.toLowerCase().includes('return your response in json');
  
  const mockSettings = [
    { iso: 100, aperture: 'f/8.0', shutter_speed: '1/500', white_balance: 'daylight', scene: 'landscape', lighting: 'bright daylight' },
    { iso: 400, aperture: 'f/4.0', shutter_speed: '1/125', white_balance: 'auto', scene: 'portrait', lighting: 'indoor mixed' },
    { iso: 800, aperture: 'f/2.8', shutter_speed: '1/250', white_balance: 'cloudy', scene: 'street', lighting: 'overcast' }
  ];
  
  const randomSettings = mockSettings[Math.floor(Math.random() * mockSettings.length)];
  const confidence = Math.random() * 0.3 + 0.7; // Random confidence between 0.7-1.0
  
  let analysis;
  
  if (isJSONRequest) {
    analysis = {
      recommended_settings: randomSettings,
      reasoning: `Mock AI analysis of Test Camera image complete. Moving from current settings (ISO 400, f/4.0, 1/125, auto WB) to optimized settings for general scene in normal lighting conditions. The recommended ISO ${randomSettings.iso}, aperture ${randomSettings.aperture}, shutter speed ${randomSettings.shutter_speed}, and white balance ${randomSettings.white_balance} provide improved balance for the detected scene type and lighting conditions. This is simulated data with variable substitution working correctly.`,
      alternative_approaches: [
        'Portrait orientation with f/1.8 aperture for shallow depth of field and subject isolation',
        'Landscape composition using f/11 aperture for maximum sharpness from foreground to background', 
        'HDR bracketing with 3-shot sequence (-1, 0, +1 EV) for enhanced dynamic range in mixed lighting'
      ],
      confidence: confidence
    };
  } else {
    analysis = {
      recommended_settings: {
        iso: randomSettings.iso,
        aperture: randomSettings.aperture,
        shutter_speed: randomSettings.shutter_speed,
        white_balance: randomSettings.white_balance,
        scene: randomSettings.scene,
        lighting: randomSettings.lighting
      },
      reasoning: `Mock AI analysis complete. Settings optimized for general photography in normal conditions. This is simulated data for testing purposes with variable substitution.`,
      alternative_approaches: [
        'Try different composition angles for varied perspectives',
        'Experiment with different focal lengths',
        'Consider bracketing for exposure blending'
      ],
      confidence: confidence
    };
  }
  
  return {
    analysis,
    usage: {
      mock_tokens: processedPrompt.length,
      processing_time: '10ms'
    },
    cost: '$0.00',
    confidence: analysis.confidence,
    processed_prompt: processedPrompt // Include processed prompt for debugging
  };
}

module.exports = router;