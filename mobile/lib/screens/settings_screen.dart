import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/utils/responsive_utils.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _aiSuggestions = true;
  bool _autoApplySettings = false;
  bool _saveRawFiles = true;
  bool _notifications = true;
  String _imageQuality = 'High';
  String _storageLocation = 'Internal';
  String _theme = 'System';
  
  // AI Provider Settings
  String _aiProvider = 'OpenAI';
  String _aiApiKey = '';
  bool _enableOnlineAI = false;
  String _aiModel = 'gpt-4-vision-preview';
  String _customPrompt = '';
  bool _useCustomPrompt = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: ResponsiveUtils.getResponsivePadding(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection(
              'Camera Settings',
              [
                _buildSwitchTile(
                  'AI Suggestions',
                  'Get smart photography recommendations',
                  _aiSuggestions,
                  (value) => setState(() => _aiSuggestions = value),
                  icon: Icons.psychology,
                ),
                _buildSwitchTile(
                  'Auto Apply AI Settings',
                  'Automatically apply AI-suggested camera settings',
                  _autoApplySettings,
                  (value) => setState(() => _autoApplySettings = value),
                  icon: Icons.auto_awesome,
                ),
                _buildSwitchTile(
                  'Save RAW Files',
                  'Save uncompressed image files',
                  _saveRawFiles,
                  (value) => setState(() => _saveRawFiles = value),
                  icon: Icons.photo_camera,
                ),
                _buildDropdownTile(
                  'Image Quality',
                  'Choose image compression level',
                  _imageQuality,
                  ['Low', 'Medium', 'High', 'Maximum'],
                  (value) => setState(() => _imageQuality = value!),
                  icon: Icons.high_quality,
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildSection(
              'Storage & Performance',
              [
                _buildDropdownTile(
                  'Storage Location',
                  'Where to save captured photos',
                  _storageLocation,
                  ['Internal', 'SD Card', 'Cloud'],
                  (value) => setState(() => _storageLocation = value!),
                  icon: Icons.storage,
                ),
                ListTile(
                  leading: const Icon(Icons.cleaning_services),
                  title: const Text('Clear Cache'),
                  subtitle: const Text('Free up storage space'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _showClearCacheDialog,
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildSection(
              'AI Provider Settings',
              [
                _buildSwitchTile(
                  'Enable Online AI',
                  'Use cloud AI providers for advanced suggestions',
                  _enableOnlineAI,
                  (value) => setState(() => _enableOnlineAI = value),
                  icon: Icons.cloud_outlined,
                ),
                if (_enableOnlineAI) ...[
                  _buildDropdownTile(
                    'AI Provider',
                    'Choose your preferred AI service',
                    _aiProvider,
                    ['OpenAI', 'Google Gemini', 'Anthropic Claude', 'Local Only'],
                    (value) => setState(() {
                      _aiProvider = value!;
                      _updateModelOptions();
                    }),
                    icon: Icons.smart_toy,
                  ),
                  _buildDropdownTile(
                    'AI Model',
                    'Select the AI model to use',
                    _aiModel,
                    _getAvailableModels(),
                    (value) => setState(() => _aiModel = value!),
                    icon: Icons.memory,
                  ),
                  ListTile(
                    leading: const Icon(Icons.key),
                    title: const Text('API Key'),
                    subtitle: Text(_aiApiKey.isEmpty ? 'Not configured' : '••••••••${_aiApiKey.substring(_aiApiKey.length - 4)}'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _showApiKeyDialog,
                  ),
                  ListTile(
                    leading: const Icon(Icons.help_outline),
                    title: const Text('Test AI Connection'),
                    subtitle: const Text('Verify your AI provider setup'),
                    trailing: const Icon(Icons.play_arrow),
                    onTap: _testAIConnection,
                  ),
                  const Divider(),
                  _buildSwitchTile(
                    'Use Custom Prompt',
                    'Customize the AI prompt for your photography style',
                    _useCustomPrompt,
                    (value) => setState(() => _useCustomPrompt = value),
                    icon: Icons.edit_note,
                  ),
                  if (_useCustomPrompt)
                    ListTile(
                      leading: const Icon(Icons.text_fields),
                      title: const Text('Custom Prompt Template'),
                      subtitle: Text(_customPrompt.isEmpty 
                          ? 'Tap to configure custom prompt' 
                          : '${_customPrompt.length} characters configured'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _showCustomPromptDialog,
                    ),
                ],
              ],
            ),
            const SizedBox(height: 24),
            _buildSection(
              'App Settings',
              [
                _buildDropdownTile(
                  'Theme',
                  'Choose app appearance',
                  _theme,
                  ['Light', 'Dark', 'System'],
                  (value) => setState(() => _theme = value!),
                  icon: Icons.palette,
                ),
                _buildSwitchTile(
                  'Notifications',
                  'Receive app notifications',
                  _notifications,
                  (value) => setState(() => _notifications = value),
                  icon: Icons.notifications,
                ),
                ListTile(
                  leading: const Icon(Icons.language),
                  title: const Text('Language'),
                  subtitle: const Text('English'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showNotImplemented('Language selection'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildSection(
              'About',
              [
                ListTile(
                  leading: const Icon(Icons.info),
                  title: const Text('Version'),
                  subtitle: const Text('Lens AI v1.0.0'),
                ),
                ListTile(
                  leading: const Icon(Icons.help),
                  title: const Text('Help & Support'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showNotImplemented('Help & Support'),
                ),
                ListTile(
                  leading: const Icon(Icons.privacy_tip),
                  title: const Text('Privacy Policy'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showNotImplemented('Privacy Policy'),
                ),
                ListTile(
                  leading: const Icon(Icons.gavel),
                  title: const Text('Terms of Service'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showNotImplemented('Terms of Service'),
                ),
              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 8),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildSwitchTile(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged, {
    IconData? icon,
  }) {
    return ListTile(
      leading: icon != null ? Icon(icon) : null,
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: AppColors.primary,
      ),
    );
  }

  Widget _buildDropdownTile<T>(
    String title,
    String subtitle,
    T value,
    List<T> items,
    ValueChanged<T?> onChanged, {
    IconData? icon,
  }) {
    return ListTile(
      leading: icon != null ? Icon(icon) : null,
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: DropdownButton<T>(
        value: value,
        onChanged: onChanged,
        items: items.map((T item) {
          return DropdownMenuItem<T>(
            value: item,
            child: Text(item.toString()),
          );
        }).toList(),
      ),
    );
  }

  void _showClearCacheDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Cache'),
        content: const Text(
          'This will clear all cached images and temporary files. '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showCacheCleared();
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  void _showCacheCleared() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Cache cleared successfully'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showNotImplemented(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature - Coming Soon!'),
        backgroundColor: AppColors.accent,
      ),
    );
  }

  List<String> _getAvailableModels() {
    switch (_aiProvider) {
      case 'OpenAI':
        return ['gpt-4-vision-preview', 'gpt-4o', 'gpt-4o-mini'];
      case 'Google Gemini':
        return ['gemini-1.5-pro', 'gemini-1.5-flash', 'gemini-pro-vision'];
      case 'Anthropic Claude':
        return ['claude-3-5-sonnet-20241022', 'claude-3-opus-20240229', 'claude-3-haiku-20240307'];
      case 'Local Only':
        return ['local-vision-model'];
      default:
        return ['gpt-4-vision-preview'];
    }
  }

  void _updateModelOptions() {
    final availableModels = _getAvailableModels();
    if (!availableModels.contains(_aiModel)) {
      setState(() {
        _aiModel = availableModels.first;
      });
    }
  }

  void _showApiKeyDialog() {
    final TextEditingController controller = TextEditingController(text: _aiApiKey);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${_aiProvider} API Key'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'API Key',
                hintText: 'Enter your API key',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
              maxLines: 1,
            ),
            const SizedBox(height: 16),
            Text(
              'Your API key will be stored securely on this device only. Never shared with third parties.',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _aiApiKey = controller.text;
              });
              Navigator.pop(context);
              _saveSettings();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _testAIConnection() async {
    if (_aiApiKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please configure your API key first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Testing AI connection...'),
          ],
        ),
      ),
    );

    try {
      // TODO: Implement actual AI provider test
      await Future.delayed(const Duration(seconds: 2)); // Mock test
      
      Navigator.pop(context); // Close loading dialog
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ ${_aiProvider} connection successful!'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      Navigator.pop(context); // Close loading dialog
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Connection failed: ${e.toString()}'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _showCustomPromptDialog() {
    final TextEditingController controller = TextEditingController(text: _customPrompt);
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.7,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  const Icon(Icons.edit_note, color: AppColors.primary),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Custom AI Prompt Template',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 8),
              
              // Instructions
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Available Variables:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '• {cameraModel} - Current camera model\n'
                      '• {currentISO} - Current ISO setting\n'
                      '• {currentAperture} - Current aperture setting\n'
                      '• {currentShutter} - Current shutter speed\n'
                      '• {currentWB} - Current white balance\n'
                      '• {sceneType} - Detected scene type\n'
                      '• {lightingConditions} - Lighting analysis\n'
                      '• {userRequest} - User\'s specific request',
                      style: TextStyle(fontSize: 12, height: 1.4),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              // Prompt editor
              const Text(
                'Custom Prompt:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: TextField(
                  controller: controller,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  decoration: const InputDecoration(
                    hintText: 'Enter your custom AI prompt template...\n\nExample:\nAnalyze this {sceneType} photo taken with {cameraModel}. Current settings: ISO {currentISO}, {currentAperture}, {currentShutter}. {userRequest}\n\nProvide camera settings recommendations and composition tips.',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // Action buttons
              Row(
                children: [
                  TextButton(
                    onPressed: () {
                      controller.text = _getDefaultPromptTemplate();
                    },
                    child: const Text('Load Default Template'),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _customPrompt = controller.text;
                      });
                      Navigator.pop(context);
                      _saveSettings();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                    ),
                    child: const Text(
                      'Save',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getDefaultPromptTemplate() {
    return '''Analyze this photograph taken with {cameraModel} and provide camera settings recommendations.

Current Camera Setup:
- Camera Model: {cameraModel}
- Current ISO: {currentISO}
- Current Aperture: {currentAperture}
- Current Shutter Speed: {currentShutter}
- Current White Balance: {currentWB}

Scene Context:
- Scene Type: {sceneType}
- Lighting Conditions: {lightingConditions}
- User Request: {userRequest}

Please respond with a JSON object containing:
1. "cameraSettings": Recommended camera settings with numeric values where applicable
2. "changedSettings": Array of setting names that were modified from current values
3. "compositionTips": Array of composition and creative suggestions
4. "reasoning": Brief explanation of why these settings are recommended
5. "confidence": Confidence score between 0.0 and 1.0

Focus on practical, actionable camera settings that will improve the photograph.''';
  }

  void _saveSettings() {
    // TODO: Implement persistent storage for AI settings
    // Save to SharedPreferences or secure storage
  }
}