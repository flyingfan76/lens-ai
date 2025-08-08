// AI Testing Dashboard JavaScript

let selectedImage = null;
let testResults = [];
let currentProvider = 'openai';

// Initialize the dashboard
document.addEventListener('DOMContentLoaded', function() {
    initializeImageUpload();
    updateProviderStatus();
    loadSavedConfiguration();
    
    // Add event listeners
    document.getElementById('aiProvider').addEventListener('change', handleProviderChange);
    document.getElementById('useCustomPrompt').addEventListener('change', toggleCustomPrompt);
    document.getElementById('cameraModel').addEventListener('change', updateCameraSettings);
    document.getElementById('showAdvancedSettings').addEventListener('change', toggleAdvancedSettings);
});

// Image upload handling
function initializeImageUpload() {
    const uploadArea = document.getElementById('imageUploadArea');
    const imageInput = document.getElementById('imageInput');
    const imagePreview = document.getElementById('imagePreview');
    const uploadText = document.getElementById('uploadText');

    // Drag and drop functionality
    uploadArea.addEventListener('dragover', (e) => {
        e.preventDefault();
        uploadArea.classList.add('dragover');
    });

    uploadArea.addEventListener('dragleave', () => {
        uploadArea.classList.remove('dragover');
    });

    uploadArea.addEventListener('drop', (e) => {
        e.preventDefault();
        uploadArea.classList.remove('dragover');
        const files = e.dataTransfer.files;
        if (files.length > 0) {
            handleImageFile(files[0]);
        }
    });

    // File input change
    imageInput.addEventListener('change', (e) => {
        if (e.target.files.length > 0) {
            handleImageFile(e.target.files[0]);
        }
    });
}

function handleImageFile(file) {
    if (!file.type.startsWith('image/')) {
        showMessage('Please select a valid image file', 'error');
        return;
    }

    const reader = new FileReader();
    reader.onload = (e) => {
        selectedImage = {
            file: file,
            dataUrl: e.target.result,
            name: file.name,
            size: file.size
        };

        // Show preview
        const imagePreview = document.getElementById('imagePreview');
        const uploadText = document.getElementById('uploadText');
        
        imagePreview.src = e.target.result;
        imagePreview.style.display = 'block';
        uploadText.style.display = 'none';

        // Enable analyze button
        document.getElementById('analyzeBtn').disabled = false;
        
        showMessage(`Image loaded: ${file.name} (${(file.size / 1024 / 1024).toFixed(2)} MB)`, 'success');
    };
    reader.readAsDataURL(file);
}

// Provider management
function handleProviderChange() {
    currentProvider = document.getElementById('aiProvider').value;
    updateModelOptions();
    updateEndpointConfiguration();
    updateProviderStatus();
    saveConfiguration();
}

function updateModelOptions() {
    const modelSelect = document.getElementById('aiModel');
    const modelOptions = {
        openai: [
            { value: 'gpt-4-vision-preview', text: 'GPT-4 Vision Preview' },
            { value: 'gpt-4o', text: 'GPT-4o' },
            { value: 'gpt-4o-mini', text: 'GPT-4o Mini' }
        ],
        'azure-openai': [
            { value: 'gpt-4-vision', text: 'GPT-4 Vision (Azure)' },
            { value: 'gpt-4o', text: 'GPT-4o (Azure)' },
            { value: 'gpt-35-turbo-16k', text: 'GPT-3.5 Turbo 16K' }
        ],
        gemini: [
            { value: 'gemini-pro-vision', text: 'Gemini Pro Vision' },
            { value: 'gemini-1.5-pro', text: 'Gemini 1.5 Pro' },
            { value: 'gemini-1.5-flash', text: 'Gemini 1.5 Flash' }
        ],
        claude: [
            { value: 'claude-3-opus-20240229', text: 'Claude 3 Opus' },
            { value: 'claude-3-sonnet-20240229', text: 'Claude 3 Sonnet' },
            { value: 'claude-3-haiku-20240307', text: 'Claude 3 Haiku' }
        ],
        // Chinese AI Providers
        deepseek: [
            { value: 'deepseek-vl-7b-chat', text: 'DeepSeek-VL-7B-Chat' },
            { value: 'deepseek-vl-1.3b-chat', text: 'DeepSeek-VL-1.3B-Chat' },
            { value: 'deepseek-chat', text: 'DeepSeek Chat' }
        ],
        zhipu: [
            { value: 'glm-4v', text: 'GLM-4V' },
            { value: 'glm-4', text: 'GLM-4' },
            { value: 'glm-3-turbo', text: 'GLM-3-Turbo' }
        ],
        baidu: [
            { value: 'ernie-bot-4', text: 'ERNIE Bot 4.0' },
            { value: 'ernie-bot-turbo', text: 'ERNIE Bot Turbo' },
            { value: 'ernie-vil-2.0', text: 'ERNIE-ViL 2.0' }
        ],
        alibaba: [
            { value: 'qwen-vl-plus', text: 'Qwen-VL-Plus' },
            { value: 'qwen-vl-max', text: 'Qwen-VL-Max' },
            { value: 'qwen-turbo', text: 'Qwen Turbo' }
        ],
        tencent: [
            { value: 'hunyuan-vision', text: 'Hunyuan Vision' },
            { value: 'hunyuan-lite', text: 'Hunyuan Lite' },
            { value: 'hunyuan-standard', text: 'Hunyuan Standard' }
        ],
        moonshot: [
            { value: 'moonshot-v1-8k', text: 'Moonshot v1 8K' },
            { value: 'moonshot-v1-32k', text: 'Moonshot v1 32K' },
            { value: 'moonshot-v1-128k', text: 'Moonshot v1 128K' }
        ],
        minimax: [
            { value: 'abab6.5s-chat', text: 'ABAB6.5s Chat' },
            { value: 'abab6.5-chat', text: 'ABAB6.5 Chat' },
            { value: 'abab5.5s-chat', text: 'ABAB5.5s Chat' }
        ],
        sensetime: [
            { value: 'sensenova-xl', text: 'SenseNova XL' },
            { value: 'sensenova-l', text: 'SenseNova L' },
            { value: 'sensenova-s', text: 'SenseNova S' }
        ],
        // Self-hosted
        local: [
            { value: 'tensorflow-mobilenet', text: 'TensorFlow MobileNet' },
            { value: 'pytorch-resnet', text: 'PyTorch ResNet' },
            { value: 'onnx-efficientnet', text: 'ONNX EfficientNet' }
        ],
        ollama: [
            { value: 'llava:latest', text: 'LLaVA Latest' },
            { value: 'llava:7b', text: 'LLaVA 7B' },
            { value: 'llava:13b', text: 'LLaVA 13B' },
            { value: 'bakllava:latest', text: 'BakLLaVA Latest' }
        ],
        custom: [
            { value: 'gpt-4-vision-preview', text: 'GPT-4 Vision (Compatible)' },
            { value: 'gpt-4o', text: 'GPT-4o (Compatible)' },
            { value: 'claude-3-opus', text: 'Claude 3 Opus (Compatible)' },
            { value: 'gemini-pro-vision', text: 'Gemini Pro Vision (Compatible)' },
            { value: 'llava', text: 'LLaVA' },
            { value: 'custom-model', text: 'Custom Model' }
        ],
        mock: [
            { value: 'mock-ai', text: 'Mock AI (Testing)' }
        ]
    };

    modelSelect.innerHTML = '';
    const options = modelOptions[currentProvider] || [];
    options.forEach(option => {
        const optionElement = document.createElement('option');
        optionElement.value = option.value;
        optionElement.textContent = option.text;
        modelSelect.appendChild(optionElement);
    });
}

function updateEndpointConfiguration() {
    const provider = document.getElementById('aiProvider').value;
    const endpointGroup = document.getElementById('endpointGroup');
    const protocolGroup = document.getElementById('protocolGroup');
    const apiEndpoint = document.getElementById('apiEndpoint');
    const apiKeyHint = document.getElementById('apiKeyHint');
    const advancedSettingsGroup = document.getElementById('advancedSettingsGroup');
    
    // Default endpoints for each provider
    const defaultEndpoints = {
        openai: 'https://api.openai.com/v1',
        'azure-openai': 'https://your-resource.openai.azure.com',
        gemini: 'https://generativelanguage.googleapis.com/v1',
        claude: 'https://api.anthropic.com',
        // Chinese AI Providers
        deepseek: 'https://api.deepseek.com',
        zhipu: 'https://open.bigmodel.cn/api/paas/v4',
        baidu: 'https://aip.baidubce.com/rpc/2.0/ai_custom/v1',
        alibaba: 'https://dashscope.aliyuncs.com/api/v1',
        tencent: 'https://hunyuan.tencentcloudapi.com',
        moonshot: 'https://api.moonshot.cn/v1',
        minimax: 'https://api.minimax.chat/v1',
        sensetime: 'https://api.sensenova.cn/v1',
        // Self-hosted
        local: 'http://localhost:8000',
        ollama: 'http://localhost:11434',
        custom: '',
        mock: 'http://localhost:3000/api/ai'
    };
    
    const keyHints = {
        openai: 'Enter your OpenAI API key (sk-...)',
        'azure-openai': 'Enter your Azure OpenAI key',
        gemini: 'Enter your Google AI Studio API key',
        claude: 'Enter your Anthropic API key',
        // Chinese AI Providers
        deepseek: 'Enter your DeepSeek API key',
        zhipu: 'Enter your 智谱AI API key',
        baidu: 'Enter your 百度 API key',
        alibaba: 'Enter your 阿里云 API key',
        tencent: 'Enter your 腾讯云 API key',
        moonshot: 'Enter your 月之暗面 API key',
        minimax: 'Enter your MiniMax API key',
        sensetime: 'Enter your 商汤 API key',
        // Self-hosted
        local: 'Not required for local deployments',
        ollama: 'Not required for Ollama',
        custom: 'Enter API key if required by your endpoint',
        mock: 'Not required for testing mode'
    };
    
    // Chinese providers that typically require endpoint configuration
    const chineseProviders = ['deepseek', 'zhipu', 'baidu', 'alibaba', 'tencent', 'moonshot', 'minimax', 'sensetime'];
    
    // Update endpoint placeholder and visibility
    const showEndpoint = provider === 'custom' || provider === 'azure-openai' || provider === 'ollama' || provider === 'local' || chineseProviders.includes(provider);
    const showAdvanced = provider === 'custom' || provider === 'azure-openai' || provider === 'ollama' || provider === 'local' || chineseProviders.includes(provider);
    const showProtocol = provider === 'custom';
    
    endpointGroup.style.display = showEndpoint ? 'block' : 'none';
    protocolGroup.style.display = showProtocol ? 'block' : 'none';
    advancedSettingsGroup.style.display = showAdvanced ? 'block' : 'none';
    
    // Set endpoint value and placeholder
    if (!apiEndpoint.value || apiEndpoint.value === apiEndpoint.placeholder) {
        apiEndpoint.value = defaultEndpoints[provider] || '';
    }
    apiEndpoint.placeholder = defaultEndpoints[provider] || 'Enter your API endpoint URL';
    apiKeyHint.textContent = keyHints[provider] || 'Enter your API key';
    
    // Update model dropdown placeholder for custom
    if (provider === 'custom') {
        const modelSelect = document.getElementById('aiModel');
        if (modelSelect.options.length > 0 && modelSelect.options[0].value === 'custom-model') {
            modelSelect.options[0].textContent = 'Enter model ID manually or select compatible';
        }
    }
}

function updateProviderStatus() {
    const statusContainer = document.getElementById('providerStatus');
    const providers = [
        'openai', 'azure-openai', 'gemini', 'claude',
        'deepseek', 'zhipu', 'baidu', 'alibaba', 'tencent', 'moonshot', 'minimax', 'sensetime',
        'local', 'ollama', 'custom', 'mock'
    ];
    
    statusContainer.innerHTML = '';
    providers.forEach(provider => {
        const statusDiv = document.createElement('div');
        statusDiv.className = 'provider-status untested';
        statusDiv.innerHTML = `
            <div class="status-dot gray"></div>
            <span>${getProviderDisplayName(provider)}</span>
            <span style="margin-left: auto; font-size: 0.75rem;">Untested</span>
        `;
        statusContainer.appendChild(statusDiv);
    });
}

function getProviderDisplayName(provider) {
    const names = {
        openai: 'OpenAI',
        'azure-openai': 'Azure OpenAI',
        gemini: 'Google Gemini',
        claude: 'Anthropic Claude',
        // Chinese AI Providers
        deepseek: 'DeepSeek 深度求索',
        zhipu: '智谱AI GLM',
        baidu: '百度 ERNIE',
        alibaba: '阿里巴巴 通义千问',
        tencent: '腾讯 混元',
        moonshot: '月之暗面 Kimi',
        minimax: 'MiniMax ABAB',
        sensetime: '商汤 日日新',
        // Self-hosted
        local: 'Local AI',
        ollama: 'Ollama',
        custom: 'Custom Endpoint',
        mock: 'Mock/Testing'
    };
    return names[provider] || provider;
}

// Test connection
async function testConnection() {
    const testBtn = document.getElementById('testBtnText');
    const originalText = testBtn.textContent;
    
    testBtn.innerHTML = '<div class="loading"></div> Testing...';
    
    try {
        const config = getCurrentConfiguration();
        const response = await fetch('http://localhost:3000/api/ai/test-connection', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(config)
        });

        const result = await response.json();
        
        if (result.success) {
            updateProviderStatusResult(currentProvider, true, result.details);
            showMessage(`✅ ${getProviderDisplayName(currentProvider)} connection successful`, 'success');
        } else {
            updateProviderStatusResult(currentProvider, false, result.error);
            showMessage(`❌ ${getProviderDisplayName(currentProvider)} connection failed: ${result.error}`, 'error');
        }
    } catch (error) {
        updateProviderStatusResult(currentProvider, false, error.message);
        showMessage(`❌ Connection test failed: ${error.message}`, 'error');
    } finally {
        testBtn.textContent = originalText;
    }
}

function updateProviderStatusResult(provider, success, details) {
    const statusContainer = document.getElementById('providerStatus');
    const statusElements = statusContainer.querySelectorAll('.provider-status');
    
    statusElements.forEach(element => {
        const providerName = element.textContent.toLowerCase();
        if (providerName.includes(getProviderDisplayName(provider).toLowerCase())) {
            element.className = `provider-status ${success ? 'available' : 'unavailable'}`;
            const dot = element.querySelector('.status-dot');
            dot.className = `status-dot ${success ? 'green' : 'red'}`;
            const statusText = element.querySelector('span:last-child');
            statusText.textContent = success ? 'Available' : 'Unavailable';
        }
    });
}

// Camera settings
function updateCameraSettings() {
    const cameraModel = document.getElementById('cameraModel').value;
    const cameraSettings = {
        'nikon-d90': { iso: 400, aperture: 'f/4.0', shutter: '1/125', wb: 'Auto' },
        'canon-5d': { iso: 100, aperture: 'f/5.6', shutter: '1/200', wb: 'Daylight' },
        'sony-a7': { iso: 200, aperture: 'f/2.8', shutter: '1/160', wb: 'Auto' },
        'mobile-camera': { iso: 800, aperture: 'f/1.8', shutter: '1/60', wb: 'Auto' },
        'generic': { iso: 400, aperture: 'f/4.0', shutter: '1/125', wb: 'Auto' }
    };

    const settings = cameraSettings[cameraModel] || cameraSettings.generic;
    document.getElementById('currentISO').textContent = settings.iso;
    document.getElementById('currentAperture').textContent = settings.aperture;
    document.getElementById('currentShutter').textContent = settings.shutter;
    document.getElementById('currentWB').textContent = settings.wb;
}

// Prompt management
function toggleCustomPrompt() {
    const useCustom = document.getElementById('useCustomPrompt').checked;
    const customPromptArea = document.getElementById('customPrompt');
    customPromptArea.disabled = !useCustom;
    if (!useCustom) {
        loadDefaultPrompt();
    }
}

function loadPromptExample(type) {
    const prompts = {
        portrait: `You are a professional portrait photography assistant. Analyze this portrait image taken with a {camera_model}.

Current settings: ISO {iso}, {aperture}, {shutter_speed}, WB: {white_balance}
Lighting: {lighting_conditions}

Focus on:
- Skin tone and color accuracy
- Depth of field and subject separation
- Lighting quality and shadows
- Overall professional appearance

User wants: {user_request}

Provide JSON response with recommended settings and portrait-specific advice.`,

        landscape: `You are a landscape photography expert. Analyze this landscape image taken with a {camera_model}.

Current settings: ISO {iso}, {aperture}, {shutter_speed}, WB: {white_balance}
Scene: {scene_type}, Lighting: {lighting_conditions}

Evaluate:
- Depth of field from foreground to background
- Color saturation and dynamic range
- Sharpness across the frame
- Composition and leading lines

User request: {user_request}

Return JSON with settings optimized for landscape photography.`,

        technical: `You are a technical photography analyzer. Provide detailed technical analysis of this image from a {camera_model}.

Current settings: ISO {iso}, {aperture}, {shutter_speed}, WB: {white_balance}

Analyze:
- Exposure accuracy (histogram analysis)
- Noise levels and ISO performance
- Lens sharpness and aberrations
- Color accuracy and white balance
- Dynamic range utilization

User needs: {user_request}

Provide technical JSON response with precise measurements and recommendations.`,

        creative: `You are a creative photography mentor. Help enhance the artistic vision of this image from a {camera_model}.

Current settings: ISO {iso}, {aperture}, {shutter_speed}, WB: {white_balance}
Scene context: {scene_type} in {lighting_conditions}

Consider:
- Creative composition techniques
- Mood and atmosphere enhancement
- Alternative shooting angles
- Post-processing suggestions
- Artistic style recommendations

User's creative goal: {user_request}

Provide JSON with creative suggestions and technical settings to achieve the vision.`
    };

    document.getElementById('customPrompt').value = prompts[type] || prompts.portrait;
    document.getElementById('useCustomPrompt').checked = true;
    toggleCustomPrompt();
}

function loadDefaultPrompt() {
    const defaultPrompt = `You are an expert photography AI assistant. Analyze this image taken with a {camera_model} camera.

Current settings:
- ISO: {iso}
- Aperture: {aperture}
- Shutter Speed: {shutter_speed}
- White Balance: {white_balance}
- Scene: {scene_type}
- Lighting: {lighting_conditions}

User request: {user_request}

Please provide specific camera setting recommendations to improve this photo. Return your response in JSON format with:
- recommended_settings: {iso, aperture, shutter_speed, white_balance}
- reasoning: explanation of why these settings would improve the image
- alternative_approaches: 2-3 alternative techniques
- confidence: score from 0-1`;

    document.getElementById('customPrompt').value = defaultPrompt;
}

// AI Analysis
async function runAIAnalysis() {
    if (!selectedImage) {
        showMessage('Please upload an image first', 'error');
        return;
    }

    const analyzeBtn = document.getElementById('analyzeBtnText');
    const originalText = analyzeBtn.textContent;
    analyzeBtn.innerHTML = '<div class="loading"></div> Analyzing...';
    
    const startTime = performance.now();

    try {
        const config = getCurrentConfiguration();
        const rawPrompt = document.getElementById('customPrompt').value; // Send raw prompt template
        
        // Build context data from current settings
        const context = {
            camera_model: config.cameraModel,
            iso: document.getElementById('currentISO').textContent,
            aperture: document.getElementById('currentAperture').textContent,
            shutter_speed: document.getElementById('currentShutter').textContent,
            white_balance: document.getElementById('currentWB').textContent,
            scene_type: config.sceneType,
            lighting_conditions: config.lightingConditions,
            user_request: config.userRequest
        };
        
        // Add context to config for backend processing
        config.context = context;
        
        // Create FormData for image upload
        const formData = new FormData();
        formData.append('image', selectedImage.file);
        formData.append('config', JSON.stringify(config));
        formData.append('prompt', rawPrompt); // Send raw prompt, not pre-processed

        const response = await fetch('http://localhost:3000/api/ai/analyze-image', {
            method: 'POST',
            body: formData
        });

        const result = await response.json();
        const endTime = performance.now();
        const responseTime = Math.round(endTime - startTime);

        if (result.success) {
            displayResults(result, responseTime);
            showMessage('✅ AI analysis completed successfully', 'success');
        } else {
            showMessage(`❌ Analysis failed: ${result.error}`, 'error');
            displayError(result.error);
        }
    } catch (error) {
        showMessage(`❌ Analysis failed: ${error.message}`, 'error');
        displayError(error.message);
    } finally {
        analyzeBtn.textContent = originalText;
    }
}

function getCurrentConfiguration() {
    const config = {
        provider: document.getElementById('aiProvider').value,
        apiKey: document.getElementById('apiKey').value,
        model: document.getElementById('aiModel').value,
        endpoint: document.getElementById('apiEndpoint').value,
        protocol: document.getElementById('apiProtocol').value,
        cameraModel: document.getElementById('cameraModel').value,
        sceneType: document.getElementById('sceneType').value,
        lightingConditions: document.getElementById('lightingConditions').value,
        userRequest: document.getElementById('userRequest').value,
        useCustomPrompt: document.getElementById('useCustomPrompt').checked
    };
    
    // Add advanced settings if enabled
    if (document.getElementById('showAdvancedSettings').checked) {
        config.advancedSettings = {
            temperature: parseFloat(document.getElementById('temperature').value) || 0.7,
            maxTokens: parseInt(document.getElementById('maxTokens').value) || 1000,
            apiVersion: document.getElementById('apiVersion').value,
            customHeaders: document.getElementById('customHeaders').value
        };
    }
    
    return config;
}

function toggleAdvancedSettings() {
    const showAdvanced = document.getElementById('showAdvancedSettings').checked;
    const advancedSettings = document.getElementById('advancedSettings');
    advancedSettings.style.display = showAdvanced ? 'block' : 'none';
    saveConfiguration();
}

function buildPrompt() {
    const config = getCurrentConfiguration();
    const currentSettings = {
        iso: document.getElementById('currentISO').textContent,
        aperture: document.getElementById('currentAperture').textContent,
        shutter_speed: document.getElementById('currentShutter').textContent,
        white_balance: document.getElementById('currentWB').textContent
    };

    let prompt = document.getElementById('customPrompt').value;
    
    // Replace placeholders
    prompt = prompt.replace(/{camera_model}/g, config.cameraModel);
    prompt = prompt.replace(/{iso}/g, currentSettings.iso);
    prompt = prompt.replace(/{aperture}/g, currentSettings.aperture);
    prompt = prompt.replace(/{shutter_speed}/g, currentSettings.shutter_speed);
    prompt = prompt.replace(/{white_balance}/g, currentSettings.white_balance);
    prompt = prompt.replace(/{scene_type}/g, config.sceneType);
    prompt = prompt.replace(/{lighting_conditions}/g, config.lightingConditions);
    prompt = prompt.replace(/{user_request}/g, config.userRequest);

    return prompt;
}

function displayResults(result, responseTime) {
    const resultsContainer = document.getElementById('aiResults');
    const timingContainer = document.getElementById('responseTiming');
    
    // Update timing information
    document.getElementById('responseTime').textContent = `${responseTime}ms`;
    document.getElementById('tokenCount').textContent = result.usage?.total_tokens || '--';
    document.getElementById('confidenceScore').textContent = result.confidence ? `${Math.round(result.confidence * 100)}%` : '--';
    document.getElementById('costEstimate').textContent = result.cost || '--';
    timingContainer.style.display = 'flex';

    // Format and display results
    let formattedResult = '';
    
    if (result.analysis) {
        formattedResult += '=== AI ANALYSIS RESULTS ===\n\n';
        
        if (result.analysis.recommended_settings) {
            formattedResult += '📸 RECOMMENDED SETTINGS:\n';
            Object.entries(result.analysis.recommended_settings).forEach(([key, value]) => {
                formattedResult += `  ${key.toUpperCase()}: ${value}\n`;
            });
            formattedResult += '\n';
        }

        if (result.analysis.reasoning) {
            formattedResult += '🤔 REASONING:\n';
            formattedResult += `${result.analysis.reasoning}\n\n`;
        }

        if (result.analysis.alternative_approaches) {
            formattedResult += '💡 ALTERNATIVE APPROACHES:\n';
            result.analysis.alternative_approaches.forEach((approach, index) => {
                formattedResult += `${index + 1}. ${approach}\n`;
            });
            formattedResult += '\n';
        }

        if (result.analysis.confidence) {
            formattedResult += `🎯 CONFIDENCE: ${Math.round(result.analysis.confidence * 100)}%\n\n`;
        }
    }

    formattedResult += '=== RAW RESPONSE ===\n';
    formattedResult += JSON.stringify(result, null, 2);

    resultsContainer.textContent = formattedResult;
    
    // Switch to results tab
    switchTab('results-tab');
    
    // Store result for comparison
    testResults.push({
        timestamp: new Date().toISOString(),
        provider: currentProvider,
        model: document.getElementById('aiModel').value,
        responseTime,
        result
    });
}

function displayError(error) {
    const resultsContainer = document.getElementById('aiResults');
    resultsContainer.textContent = `❌ ERROR:\n${error}\n\nPlease check:\n- API key is correct\n- Provider is available\n- Image is valid\n- Network connection`;
}

// Provider comparison
async function runProviderComparison() {
    const compareBtn = document.getElementById('compareBtnText');
    const originalText = compareBtn.textContent;
    compareBtn.innerHTML = '<div class="loading"></div> Comparing...';
    
    const selectedProviders = [];
    if (document.getElementById('compareOpenAI').checked) selectedProviders.push('openai');
    if (document.getElementById('compareGemini').checked) selectedProviders.push('gemini');
    if (document.getElementById('compareClaude').checked) selectedProviders.push('claude');
    if (document.getElementById('compareLocal').checked) selectedProviders.push('local');

    if (selectedProviders.length === 0) {
        showMessage('Please select at least one provider to compare', 'warning');
        compareBtn.textContent = originalText;
        return;
    }

    if (!selectedImage) {
        showMessage('Please upload an image first', 'error');
        compareBtn.textContent = originalText;
        return;
    }

    try {
        const results = {};
        const baseConfig = getCurrentConfiguration();
        const prompt = buildPrompt();

        // Run analysis for each provider
        for (const provider of selectedProviders) {
            const startTime = performance.now();
            
            try {
                const config = { ...baseConfig, provider };
                const formData = new FormData();
                formData.append('image', selectedImage.file);
                formData.append('config', JSON.stringify(config));
                formData.append('prompt', prompt);

                const response = await fetch('http://localhost:3000/api/ai/analyze-image', {
                    method: 'POST',
                    body: formData
                });

                const result = await response.json();
                const endTime = performance.now();

                results[provider] = {
                    success: result.success,
                    data: result,
                    responseTime: Math.round(endTime - startTime),
                    error: result.success ? null : result.error
                };
            } catch (error) {
                results[provider] = {
                    success: false,
                    data: null,
                    responseTime: null,
                    error: error.message
                };
            }
        }

        displayComparisonResults(results);
        
    } catch (error) {
        showMessage(`❌ Comparison failed: ${error.message}`, 'error');
    } finally {
        compareBtn.textContent = originalText;
    }
}

function displayComparisonResults(results) {
    const comparisonContainer = document.getElementById('comparisonResults');
    
    let comparisonText = '=== PROVIDER COMPARISON RESULTS ===\n\n';
    
    Object.entries(results).forEach(([provider, result]) => {
        comparisonText += `🤖 ${getProviderDisplayName(provider).toUpperCase()}\n`;
        comparisonText += `${'='.repeat(40)}\n`;
        
        if (result.success) {
            comparisonText += `✅ Status: Success\n`;
            comparisonText += `⏱️ Response Time: ${result.responseTime}ms\n`;
            
            if (result.data.analysis?.recommended_settings) {
                comparisonText += `📸 Recommended Settings:\n`;
                Object.entries(result.data.analysis.recommended_settings).forEach(([key, value]) => {
                    comparisonText += `  ${key}: ${value}\n`;
                });
            }
            
            if (result.data.analysis?.confidence) {
                comparisonText += `🎯 Confidence: ${Math.round(result.data.analysis.confidence * 100)}%\n`;
            }
            
            if (result.data.analysis?.reasoning) {
                comparisonText += `💭 Reasoning: ${result.data.analysis.reasoning.substring(0, 200)}...\n`;
            }
        } else {
            comparisonText += `❌ Status: Failed\n`;
            comparisonText += `💥 Error: ${result.error}\n`;
        }
        
        comparisonText += '\n';
    });
    
    // Add summary comparison
    const successfulResults = Object.entries(results).filter(([_, result]) => result.success);
    if (successfulResults.length > 1) {
        comparisonText += '=== PERFORMANCE COMPARISON ===\n\n';
        
        // Sort by response time
        successfulResults.sort((a, b) => a[1].responseTime - b[1].responseTime);
        
        comparisonText += '🏃 Speed Ranking:\n';
        successfulResults.forEach(([provider, result], index) => {
            comparisonText += `${index + 1}. ${getProviderDisplayName(provider)}: ${result.responseTime}ms\n`;
        });
        
        comparisonText += '\n';
        
        // Sort by confidence
        const confidenceResults = successfulResults.filter(([_, result]) => result.data.analysis?.confidence);
        if (confidenceResults.length > 1) {
            confidenceResults.sort((a, b) => b[1].data.analysis.confidence - a[1].data.analysis.confidence);
            
            comparisonText += '🎯 Confidence Ranking:\n';
            confidenceResults.forEach(([provider, result], index) => {
                const confidence = Math.round(result.data.analysis.confidence * 100);
                comparisonText += `${index + 1}. ${getProviderDisplayName(provider)}: ${confidence}%\n`;
            });
        }
    }
    
    comparisonContainer.textContent = comparisonText;
    
    // Switch to comparison tab
    switchTab('comparison-tab');
}

// Tab management
function switchTab(tabId) {
    // Hide all tab contents
    document.querySelectorAll('.tab-content').forEach(content => {
        content.classList.remove('active');
    });
    
    // Remove active class from all tabs
    document.querySelectorAll('.tab').forEach(tab => {
        tab.classList.remove('active');
    });
    
    // Show selected tab content
    document.getElementById(tabId).classList.add('active');
    
    // Add active class to corresponding tab
    const tabIndex = {
        'prompt-tab': 0,
        'results-tab': 1,
        'comparison-tab': 2
    };
    document.querySelectorAll('.tab')[tabIndex[tabId]].classList.add('active');
}

// Configuration management
function saveConfiguration() {
    const config = getCurrentConfiguration();
    localStorage.setItem('lensai-test-config', JSON.stringify(config));
}

function loadSavedConfiguration() {
    const saved = localStorage.getItem('lensai-test-config');
    if (saved) {
        try {
            const config = JSON.parse(saved);
            
            // Restore form values
            if (config.provider) document.getElementById('aiProvider').value = config.provider;
            if (config.apiKey) document.getElementById('apiKey').value = config.apiKey;
            if (config.endpoint) document.getElementById('apiEndpoint').value = config.endpoint;
            if (config.cameraModel) document.getElementById('cameraModel').value = config.cameraModel;
            if (config.sceneType) document.getElementById('sceneType').value = config.sceneType;
            if (config.lightingConditions) document.getElementById('lightingConditions').value = config.lightingConditions;
            if (config.userRequest) document.getElementById('userRequest').value = config.userRequest;
            if (config.useCustomPrompt) document.getElementById('useCustomPrompt').checked = config.useCustomPrompt;
            
            // Restore advanced settings
            if (config.advancedSettings) {
                document.getElementById('showAdvancedSettings').checked = true;
                if (config.advancedSettings.temperature) document.getElementById('temperature').value = config.advancedSettings.temperature;
                if (config.advancedSettings.maxTokens) document.getElementById('maxTokens').value = config.advancedSettings.maxTokens;
                if (config.advancedSettings.apiVersion) document.getElementById('apiVersion').value = config.advancedSettings.apiVersion;
                if (config.advancedSettings.customHeaders) document.getElementById('customHeaders').value = config.advancedSettings.customHeaders;
            }
            
            // Update dependent elements
            handleProviderChange();
            updateCameraSettings();
            toggleCustomPrompt();
            toggleAdvancedSettings();
            
        } catch (error) {
            console.warn('Failed to load saved configuration:', error);
        }
    }
}

// Utility functions
function showMessage(message, type) {
    const container = document.getElementById('messagesArea');
    const messageDiv = document.createElement('div');
    messageDiv.className = `message ${type}`;
    messageDiv.textContent = message;
    
    container.appendChild(messageDiv);
    
    // Auto-remove after 5 seconds
    setTimeout(() => {
        if (messageDiv.parentNode) {
            messageDiv.parentNode.removeChild(messageDiv);
        }
    }, 5000);
    
    // Scroll to show message
    messageDiv.scrollIntoView({ behavior: 'smooth' });
}

// Preset configurations
function showPresetConfigurations() {
    const presetDiv = document.getElementById('presetConfigurations');
    presetDiv.style.display = presetDiv.style.display === 'none' ? 'block' : 'none';
}

function loadPresetConfig(presetType) {
    const presets = {
        'azure-openai': {
            provider: 'azure-openai',
            endpoint: 'https://your-resource.openai.azure.com',
            model: 'gpt-4-vision',
            apiVersion: '2024-02-15-preview',
            customHeaders: '{"api-version": "2024-02-15-preview"}',
            temperature: 0.7,
            maxTokens: 1000
        },
        'ollama-local': {
            provider: 'ollama',
            endpoint: 'http://localhost:11434',
            model: 'llava:latest',
            apiKey: '',
            temperature: 0.8,
            maxTokens: 2000
        },
        'openai-compatible': {
            provider: 'custom',
            endpoint: 'https://api.your-service.com/v1',
            model: 'gpt-4-vision-preview',
            customHeaders: '{"Content-Type": "application/json"}',
            temperature: 0.7,
            maxTokens: 1000
        },
        'custom-api': {
            provider: 'custom',
            endpoint: 'https://your-api.example.com/ai/vision',
            model: 'custom-vision-model',
            protocol: 'openai',
            customHeaders: '{"X-API-Version": "v1", "Authorization": "Bearer YOUR_TOKEN"}',
            temperature: 0.6,
            maxTokens: 1500
        },
        'deepseek-setup': {
            provider: 'deepseek',
            endpoint: 'https://api.deepseek.com',
            model: 'deepseek-vl-7b-chat',
            temperature: 0.7,
            maxTokens: 2000
        },
        'zhipu-glm4v': {
            provider: 'zhipu',
            endpoint: 'https://open.bigmodel.cn/api/paas/v4',
            model: 'glm-4v',
            temperature: 0.8,
            maxTokens: 1500
        },
        'vertex-compatible': {
            provider: 'custom',
            endpoint: 'https://your-project.googleapis.com/v1',
            model: 'gemini-pro-vision',
            protocol: 'vertex',
            customHeaders: '{"Authorization": "Bearer YOUR_TOKEN"}',
            temperature: 0.7,
            maxTokens: 1000
        }
    };

    const config = presets[presetType];
    if (config) {
        // Apply configuration
        document.getElementById('aiProvider').value = config.provider;
        document.getElementById('apiEndpoint').value = config.endpoint;
        document.getElementById('aiModel').value = config.model;
        if (config.apiKey !== undefined) document.getElementById('apiKey').value = config.apiKey;
        
        // Show advanced settings if needed
        if (config.temperature || config.maxTokens || config.apiVersion || config.customHeaders) {
            document.getElementById('showAdvancedSettings').checked = true;
            if (config.temperature) document.getElementById('temperature').value = config.temperature;
            if (config.maxTokens) document.getElementById('maxTokens').value = config.maxTokens;
            if (config.apiVersion) document.getElementById('apiVersion').value = config.apiVersion;
            if (config.customHeaders) document.getElementById('customHeaders').value = config.customHeaders;
        }
        
        // Update UI
        handleProviderChange();
        toggleAdvancedSettings();
        
        // Hide presets
        document.getElementById('presetConfigurations').style.display = 'none';
        
        showMessage(`✅ Loaded ${presetType.replace('-', ' ')} configuration`, 'success');
    }
}

// Auto-save configuration on form changes
document.addEventListener('change', (e) => {
    if (e.target.matches('select, input[type="text"], input[type="password"], input[type="url"], input[type="number"], textarea, input[type="checkbox"]')) {
        saveConfiguration();
    }
});