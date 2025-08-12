import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';

import '../models/ai_provider_config.dart';
import '../widgets/common/settings_row.dart';
import '../widgets/common/section_header.dart';
import '../widgets/common/configuration_card.dart';
import '../core/theme/app_colors.dart';

/// Consolidated AI settings screen that unifies all AI configuration
class ConsolidatedAISettingsScreen extends StatefulWidget {
  const ConsolidatedAISettingsScreen({super.key});

  @override
  State<ConsolidatedAISettingsScreen> createState() => _ConsolidatedAISettingsScreenState();
}

class _ConsolidatedAISettingsScreenState extends State<ConsolidatedAISettingsScreen> {
  static const _storage = FlutterSecureStorage();
  static const String _configKey = 'ai_configuration';
  
  AIConfiguration _configuration = AIConfiguration(
    selectedProviderId: 'custom',
    providers: _getDefaultProviders(),
  );
  
  bool _isLoading = true;
  bool _isSaving = false;
  final Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    _loadConfiguration();
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadConfiguration() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final configJson = prefs.getString(_configKey);
      
      if (configJson != null) {
        final configData = jsonDecode(configJson);
        _configuration = AIConfiguration.fromJson(configData);
      }
      
      // Load API keys from secure storage
      for (final provider in _configuration.providers) {
        if (provider.apiKey != null) {
          final secureKey = await _storage.read(key: 'ai_api_key_${provider.id}');
          if (secureKey != null) {
            final updatedProvider = provider.copyWith(apiKey: secureKey);
            final index = _configuration.providers.indexWhere((p) => p.id == provider.id);
            if (index != -1) {
              _configuration.providers[index] = updatedProvider;
            }
          }
        }
      }
      
      _initializeControllers();
      
    } catch (e) {
      debugPrint('Error loading AI configuration: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _initializeControllers() {
    for (final provider in _configuration.providers) {
      _controllers['${provider.id}_endpoint'] = TextEditingController(text: provider.endpoint ?? '');
      _controllers['${provider.id}_apikey'] = TextEditingController(text: provider.apiKey ?? '');
      _controllers['${provider.id}_model'] = TextEditingController(text: provider.selectedModel ?? '');
    }
    _controllers['custom_prompt'] = TextEditingController(text: _configuration.customPromptTemplate);
  }

  Future<void> _saveConfiguration() async {
    setState(() {
      _isSaving = true;
    });

    try {
      // Update configuration with current controller values
      final updatedProviders = <AIProviderConfig>[];
      
      for (final provider in _configuration.providers) {
        final endpointController = _controllers['${provider.id}_endpoint'];
        final apiKeyController = _controllers['${provider.id}_apikey'];
        final modelController = _controllers['${provider.id}_model'];
        
        final updatedProvider = provider.copyWith(
          endpoint: endpointController?.text.trim(),
          apiKey: apiKeyController?.text.trim(),
          selectedModel: modelController?.text.trim(),
        );
        
        updatedProviders.add(updatedProvider);
        
        // Save API key to secure storage
        if (updatedProvider.apiKey?.isNotEmpty == true) {
          await _storage.write(
            key: 'ai_api_key_${provider.id}',
            value: updatedProvider.apiKey!,
          );
        }
      }
      
      final updatedConfig = _configuration.copyWith(
        providers: updatedProviders,
        customPromptTemplate: _controllers['custom_prompt']?.text ?? '',
      );
      
      // Save configuration (without API keys for security)
      final configToSave = updatedConfig.copyWith(
        providers: updatedProviders.map((p) => p.copyWith(apiKey: null)).toList(),
      );
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_configKey, jsonEncode(configToSave.toJson()));
      
      setState(() {
        _configuration = updatedConfig;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('AI settings saved successfully'),
            backgroundColor: AppColors.accent,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error saving AI configuration: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save settings: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  Future<bool> _testConnection(AIProviderConfig provider) async {
    try {
      // Get current values from controllers
      final endpoint = _controllers['${provider.id}_endpoint']?.text.trim();
      final apiKey = _controllers['${provider.id}_apikey']?.text.trim();
      
      if (endpoint?.isEmpty != false) {
        throw Exception('Endpoint URL is required');
      }
      
      if (apiKey?.isEmpty != false) {
        throw Exception('API Key is required');
      }
      
      // Simulate connection test with basic validation
      await Future.delayed(const Duration(seconds: 1));
      
      // Basic URL validation
      final uri = Uri.tryParse(endpoint!);
      if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
        throw Exception('Invalid endpoint URL format');
      }
      
      // For now, just return true if basic validation passes
      // In a real implementation, you would make an actual API call here
      return true;
      
    } catch (e) {
      debugPrint('Connection test error: $e');
      rethrow;
    }
  }

  void _showAddCustomProviderDialog() {
    showDialog(
      context: context,
      builder: (context) => _AddCustomProviderDialog(
        onAdd: (provider) {
          setState(() {
            _configuration = _configuration.copyWith(
              providers: [..._configuration.providers, provider],
            );
          });
          _initializeControllers();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          title: const Text('AI & Intelligence'),
          backgroundColor: Colors.transparent,
        ),
        body: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.accent),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('AI & Intelligence'),
        backgroundColor: Colors.transparent,
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _saveConfiguration,
            child: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.accent),
                    ),
                  )
                : const Text(
                    'Save',
                    style: TextStyle(color: AppColors.accent),
                  ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // AI Service Status
            const SectionHeader(
              title: 'Service Status',
              subtitle: 'Current AI service configuration and connectivity',
            ),
            StatusCard(
              title: 'Active Provider',
              status: _configuration.selectedProvider?.name ?? 'None',
              statusType: _configuration.selectedProvider != null 
                  ? StatusType.success 
                  : StatusType.warning,
              description: _configuration.selectedProvider?.description,
            ),
            
            // General AI Settings
            const SectionHeader(
              title: 'General Settings',
              subtitle: 'Control AI behavior and features',
            ),
            ConfigurationCard(
              children: [
                SettingsSwitchRow(
                  title: 'Enable AI Suggestions',
                  subtitle: 'Get AI-powered photography recommendations',
                  value: _configuration.enableAISuggestions,
                  onChanged: (value) {
                    setState(() {
                      _configuration = _configuration.copyWith(enableAISuggestions: value);
                    });
                  },
                ),
                SettingsSwitchRow(
                  title: 'Auto Analysis',
                  subtitle: 'Automatically analyze photos after capture',
                  value: _configuration.enableAutoAnalysis,
                  onChanged: (value) {
                    setState(() {
                      _configuration = _configuration.copyWith(enableAutoAnalysis: value);
                    });
                  },
                ),
              ],
            ),
            
            // Provider Selection
            const SectionHeader(
              title: 'AI Provider',
              subtitle: 'Choose your preferred AI service',
            ),
            ConfigurationCard(
              children: [
                SettingsDropdownRow<String>(
                  title: 'Active Provider',
                  subtitle: 'Select which AI service to use',
                  value: _configuration.selectedProviderId,
                  items: _configuration.providers.map((provider) {
                    return DropdownMenuItem<String>(
                      value: provider.id,
                      child: Text(provider.name),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _configuration = _configuration.copyWith(selectedProviderId: value);
                      });
                    }
                  },
                  showDivider: false,
                ),
              ],
            ),
            
            // Provider Configurations
            const SectionHeader(
              title: 'Provider Configuration',
              subtitle: 'Configure individual AI providers',
            ),
            
            ..._configuration.providers.map((provider) => _buildProviderCard(provider)).toList(),
            
            // Add Custom Provider
            ConfigurationCard(
              children: [
                ListTile(
                  leading: const Icon(Icons.add, color: AppColors.accent),
                  title: const Text(
                    'Add Custom Provider',
                    style: TextStyle(color: Colors.white),
                  ),
                  subtitle: const Text(
                    'Configure a custom AI endpoint',
                    style: TextStyle(color: Colors.white70),
                  ),
                  onTap: _showAddCustomProviderDialog,
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
            
            // Advanced Settings
            const SectionHeader(
              title: 'Advanced Settings',
              subtitle: 'Customize AI behavior and prompts',
            ),
            ConfigurationCard(
              children: [
                SettingsTextFieldRow(
                  title: 'Custom Prompt Template',
                  subtitle: 'Customize the AI prompt for photography suggestions',
                  value: _configuration.customPromptTemplate,
                  hintText: 'Enter custom prompt template...',
                  maxLines: 3,
                  onChanged: (value) {
                    _controllers['custom_prompt']?.text = value;
                  },
                ),
                const SizedBox(height: 16),
                SettingsRow(
                  title: 'Confidence Threshold',
                  subtitle: 'Minimum confidence for AI suggestions (${(_configuration.suggestionConfidenceThreshold * 100).toInt()}%)',
                  trailing: Slider(
                    value: _configuration.suggestionConfidenceThreshold,
                    min: 0.1,
                    max: 1.0,
                    divisions: 9,
                    activeColor: AppColors.accent,
                    onChanged: (value) {
                      setState(() {
                        _configuration = _configuration.copyWith(suggestionConfidenceThreshold: value);
                      });
                    },
                  ),
                ),
                SettingsRow(
                  title: 'Max Suggestions',
                  subtitle: 'Maximum number of AI suggestions to show',
                  trailing: DropdownButton<int>(
                    value: _configuration.maxSuggestions,
                    items: [1, 3, 5, 10].map((count) {
                      return DropdownMenuItem<int>(
                        value: count,
                        child: Text(count.toString()),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _configuration = _configuration.copyWith(maxSuggestions: value);
                        });
                      }
                    },
                    underline: const SizedBox(),
                    dropdownColor: const Color(0xFF2A2A2A),
                    style: const TextStyle(color: Colors.white),
                  ),
                  showDivider: false,
                ),
              ],
            ),
            
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildProviderCard(AIProviderConfig provider) {
    return ConfigurationCard(
      title: provider.name,
      subtitle: provider.description,
      leading: Icon(
        _getProviderIcon(provider.type.iconName),
        color: provider.id == _configuration.selectedProviderId 
            ? AppColors.accent 
            : Colors.white70,
      ),
      children: [
        if (provider.type != AIProviderType.local) ...[
          if (provider.type == AIProviderType.custom) ...[
            SettingsDropdownRow<AIProtocol>(
              title: 'API Protocol',
              subtitle: 'Choose the API protocol format',
              value: provider.protocol ?? AIProtocol.openai,
              items: AIProtocol.values.map((protocol) => DropdownMenuItem(
                value: protocol,
                child: Text(protocol.displayName),
              )).toList(),
              onChanged: (protocol) {
                if (protocol != null) {
                  setState(() {
                    final index = _configuration.providers.indexWhere((p) => p.id == provider.id);
                    if (index != -1) {
                      _configuration.providers[index] = provider.copyWith(protocol: protocol);
                    }
                  });
                }
              },
            ),
          ],
          SettingsTextFieldRow(
            title: 'API Endpoint',
            subtitle: 'Service endpoint URL',
            value: _controllers['${provider.id}_endpoint']?.text,
            hintText: provider.type.defaultEndpoint ?? 'https://api.example.com/v1',
            onChanged: (value) {
              _controllers['${provider.id}_endpoint']?.text = value;
            },
          ),
          SettingsTextFieldRow(
            title: 'API Key',
            subtitle: 'Your API key for this service',
            value: _controllers['${provider.id}_apikey']?.text,
            hintText: 'Enter your API key...',
            obscureText: true,
            onChanged: (value) {
              _controllers['${provider.id}_apikey']?.text = value;
            },
          ),
        ],
        SettingsDropdownRow<String>(
          title: 'Model',
          subtitle: 'Select the AI model to use',
          value: provider.selectedModel ?? provider.availableModels.first,
          items: provider.availableModels.map((model) {
            return DropdownMenuItem<String>(
              value: model,
              child: Text(model),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              _controllers['${provider.id}_model']?.text = value;
            }
          },
        ),
        if (provider.type != AIProviderType.local) ...[
          const SizedBox(height: 16),
          ConnectionTestCard(
            title: 'Connection Test',
            endpoint: _controllers['${provider.id}_endpoint']?.text.isNotEmpty == true 
                ? _controllers['${provider.id}_endpoint']!.text 
                : 'Not configured',
            onTest: () => _testConnection(provider),
          ),
        ],
      ],
    );
  }

  IconData _getProviderIcon(String iconName) {
    switch (iconName) {
      case 'auto_awesome':
        return Icons.auto_awesome;
      case 'psychology':
        return Icons.psychology;
      case 'search':
        return Icons.search;
      case 'cloud':
        return Icons.cloud;
      case 'computer':
        return Icons.computer;
      case 'settings_ethernet':
        return Icons.settings_ethernet;
      default:
        return Icons.smart_toy;
    }
  }

  static List<AIProviderConfig> _getDefaultProviders() {
    return [
      AIProviderConfig(
        id: 'custom',
        name: 'Custom Endpoint',
        description: 'Custom API endpoint for flexible AI integration',
        type: AIProviderType.custom,
        protocol: AIProtocol.openai,
        endpoint: '',
        availableModels: [],
        selectedModel: '',
        isEnabled: true,
        isCustom: true,
      ),
      AIProviderConfig(
        id: 'openai',
        name: 'OpenAI',
        description: 'OpenAI GPT models for image analysis',
        type: AIProviderType.openai,
        endpoint: 'https://api.openai.com/v1',
        availableModels: AIProviderType.openai.defaultModels,
        selectedModel: 'gpt-4-vision-preview',
        isEnabled: false,
      ),
      AIProviderConfig(
        id: 'anthropic',
        name: 'Anthropic Claude',
        description: 'Anthropic Claude for detailed analysis',
        type: AIProviderType.anthropic,
        endpoint: 'https://api.anthropic.com',
        availableModels: AIProviderType.anthropic.defaultModels,
        selectedModel: 'claude-3-5-sonnet-20241022',
        isEnabled: false,
      ),
      AIProviderConfig(
        id: 'google',
        name: 'Google Gemini',
        description: 'Google Gemini for multimodal understanding',
        type: AIProviderType.google,
        endpoint: 'https://generativelanguage.googleapis.com/v1',
        availableModels: AIProviderType.google.defaultModels,
        selectedModel: 'gemini-1.5-pro',
        isEnabled: false,
      ),
    ];
  }
}

class _AddCustomProviderDialog extends StatefulWidget {
  final Function(AIProviderConfig) onAdd;

  const _AddCustomProviderDialog({required this.onAdd});

  @override
  State<_AddCustomProviderDialog> createState() => _AddCustomProviderDialogState();
}

class _AddCustomProviderDialogState extends State<_AddCustomProviderDialog> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _endpointController = TextEditingController();
  final _apiKeyController = TextEditingController();
  final _modelController = TextEditingController();
  
  AIProviderType _selectedType = AIProviderType.custom;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _endpointController.dispose();
    _apiKeyController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  void _addProvider() {
    if (_nameController.text.trim().isEmpty) return;

    final provider = AIProviderConfig(
      id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim(),
      type: _selectedType,
      endpoint: _endpointController.text.trim(),
      apiKey: _apiKeyController.text.trim(),
      selectedModel: _modelController.text.trim(),
      availableModels: [_modelController.text.trim()],
      isCustom: true,
    );

    widget.onAdd(provider);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1A1A1A),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Add Custom Provider',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _nameController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Provider Name',
                  labelStyle: TextStyle(color: Colors.white70),
                  filled: true,
                  fillColor: Colors.white12,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _descriptionController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Description',
                  labelStyle: TextStyle(color: Colors.white70),
                  filled: true,
                  fillColor: Colors.white12,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _endpointController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'API Endpoint',
                  labelStyle: TextStyle(color: Colors.white70),
                  filled: true,
                  fillColor: Colors.white12,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _apiKeyController,
                style: const TextStyle(color: Colors.white),
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'API Key',
                  labelStyle: TextStyle(color: Colors.white70),
                  filled: true,
                  fillColor: Colors.white12,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _modelController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Model Name',
                  labelStyle: TextStyle(color: Colors.white70),
                  filled: true,
                  fillColor: Colors.white12,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _addProvider,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                    ),
                    child: const Text('Add Provider'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}