import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import '../models/ai_provider_config.dart';
import '../widgets/common/settings_row.dart';
import '../widgets/common/elegant_slider.dart';
import '../widgets/common/elegant_card.dart';
import '../widgets/common/elegant_section_header.dart';
import '../core/theme/app_colors.dart';

/// Consolidated AI settings screen that unifies all AI configuration
class ConsolidatedAISettingsScreen extends StatefulWidget {
  const ConsolidatedAISettingsScreen({super.key});

  @override
  State<ConsolidatedAISettingsScreen> createState() => _ConsolidatedAISettingsScreenState();
}

class _ConsolidatedAISettingsScreenState extends State<ConsolidatedAISettingsScreen> {
  static const String _configKey = 'ai_configuration';
  
  AIConfiguration _configuration = AIConfiguration(
    selectedProviderId: 'local',
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
      debugPrint('AI Settings: Loading configuration...');
      
      // Load main configuration from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final configJson = prefs.getString(_configKey);
      
      if (configJson != null) {
        try {
          final configData = jsonDecode(configJson);
          final loadedConfig = AIConfiguration.fromJson(configData);
          
          // Check if loaded config has valid providers, if not reset to defaults
          final hasLocalAiDuplicate = loadedConfig.providers.where((p) => p.name == 'Local AI').length > 1;
          final hasValidCustomProvider = loadedConfig.providers.any((p) => p.id == 'custom' && p.selectedModel?.isNotEmpty == true);
          
          if (hasLocalAiDuplicate || !hasValidCustomProvider) {
            debugPrint('AI Settings: Configuration has duplicates or missing model, resetting to defaults');
            _configuration = AIConfiguration(
              selectedProviderId: 'local',
              providers: _getDefaultProviders(),
            );
          } else {
            // Merge loaded configuration with defaults to ensure all fields are present
            final defaultProviders = _getDefaultProviders();
            final mergedProviders = <AIProviderConfig>[];
            
            for (final defaultProvider in defaultProviders) {
              // Find matching saved provider
              final savedProvider = loadedConfig.providers.firstWhere(
                (p) => p.id == defaultProvider.id,
                orElse: () => defaultProvider,
              );
              
              // Merge: use saved values where available, defaults for missing fields
              final mergedProvider = defaultProvider.copyWith(
                endpoint: savedProvider.endpoint ?? defaultProvider.endpoint,
                apiKey: savedProvider.apiKey ?? defaultProvider.apiKey,
                selectedModel: savedProvider.selectedModel ?? defaultProvider.selectedModel,
                isEnabled: savedProvider.isEnabled,
              );
              
              mergedProviders.add(mergedProvider);
              debugPrint('AI Settings: Merged provider ${mergedProvider.id} - model: ${mergedProvider.selectedModel}');
            }
            
            _configuration = loadedConfig.copyWith(providers: mergedProviders);
          }
          debugPrint('AI Settings: Configuration loaded and merged with defaults');
        } catch (e) {
          debugPrint('AI Settings: Failed to parse configuration JSON: $e');
          // Use default configuration if parsing fails
          _configuration = AIConfiguration(
            selectedProviderId: 'local',
            providers: _getDefaultProviders(),
          );
        }
      } else {
        debugPrint('AI Settings: No existing configuration found, using defaults');
        _configuration = AIConfiguration(
          selectedProviderId: 'local',
          providers: _getDefaultProviders(),
        );
      }
      
      // Load API keys from SharedPreferences (temporary workaround for keychain issues)
      final updatedProviders = <AIProviderConfig>[];
      for (final provider in _configuration.providers) {
        try {
          final savedKey = prefs.getString('ai_api_key_${provider.id}');
          if (savedKey != null && savedKey.isNotEmpty) {
            final updatedProvider = provider.copyWith(apiKey: savedKey);
            updatedProviders.add(updatedProvider);
            debugPrint('AI Settings: Loaded API key for ${provider.id} from SharedPreferences');
          } else {
            updatedProviders.add(provider);
          }
        } catch (e) {
          debugPrint('AI Settings: Failed to load API key for ${provider.id}: $e');
          updatedProviders.add(provider);
        }
      }
      
      // Update configuration with loaded API keys
      _configuration = _configuration.copyWith(providers: updatedProviders);
      
      _initializeControllers();
      debugPrint('AI Settings: Configuration loading completed successfully');
      
    } catch (e) {
      debugPrint('AI Settings: Critical error loading configuration: $e');
      // Fallback to default configuration
      _configuration = AIConfiguration(
        selectedProviderId: 'local',
        providers: _getDefaultProviders(),
      );
      _initializeControllers();
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
    _controllers['custom_prompt'] = TextEditingController(text: _configuration.customPromptTemplate ?? AIConfiguration.getBuiltInPrompt());
  }

  Future<void> _saveConfiguration() async {
    setState(() {
      _isSaving = true;
    });

    try {
      debugPrint('AI Settings: Starting save process...');
      
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
        
        // Save API key to SharedPreferences (temporary workaround for keychain issues)
        if (updatedProvider.apiKey?.isNotEmpty == true) {
          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('ai_api_key_${provider.id}', updatedProvider.apiKey!);
            debugPrint('AI Settings: Saved API key for ${provider.id} to SharedPreferences');
          } catch (e) {
            debugPrint('AI Settings: Failed to save API key for ${provider.id}: $e');
            throw Exception('Failed to save API key for ${provider.name}: $e');
          }
        }
      }
      
      final updatedConfig = _configuration.copyWith(
        providers: updatedProviders,
        customPromptTemplate: _controllers['custom_prompt']?.text ?? '',
      );
      
      // Save configuration (without API keys for security)
      final providersWithoutKeys = <AIProviderConfig>[];
      for (final provider in updatedProviders) {
        try {
          providersWithoutKeys.add(provider.copyWith(apiKey: null));
        } catch (e) {
          debugPrint('AI Settings: Failed to create provider copy for ${provider.id}: $e');
          throw Exception('Failed to process provider ${provider.name}: $e');
        }
      }
      
      final configToSave = updatedConfig.copyWith(
        providers: providersWithoutKeys,
      );
      
      // Convert to JSON and validate
      Map<String, dynamic> configJson;
      try {
        configJson = configToSave.toJson();
        debugPrint('AI Settings: Configuration serialized to JSON successfully');
      } catch (e) {
        debugPrint('AI Settings: JSON serialization failed: $e');
        throw Exception('Failed to serialize configuration: $e');
      }
      
      // Save to SharedPreferences
      try {
        final prefs = await SharedPreferences.getInstance();
        final jsonString = jsonEncode(configJson);
        await prefs.setString(_configKey, jsonString);
        debugPrint('AI Settings: Configuration saved to SharedPreferences successfully');
      } catch (e) {
        debugPrint('AI Settings: SharedPreferences save failed: $e');
        throw Exception('Failed to save configuration to storage: $e');
      }
      
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
      debugPrint('AI Settings: Save operation failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save settings: ${e.toString()}'),
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


  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFF000000),
        appBar: AppBar(
          title: const Text('AI & Intelligence'),
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.accent),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF000000), // Pure black background
      appBar: AppBar(
        title: const Text('AI & Intelligence'),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
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
            const ElegantSectionHeader(
              title: 'Service Status',
              subtitle: 'Current AI service configuration and connectivity',
            ),
            ElegantStatusCard(
              title: 'Active Provider',
              status: _configuration.selectedProvider?.name ?? 'None',
              statusType: _configuration.selectedProvider != null 
                  ? StatusType.success 
                  : StatusType.warning,
              description: _configuration.selectedProvider?.description ?? 'No AI provider selected',
            ),
            
            // AI Features
            const ElegantSectionHeader(
              title: 'AI Features',
              subtitle: 'Enable or disable AI-powered features',
            ),
            ElegantCard(
              children: [
                SettingsSwitchRow(
                  title: 'AI Suggestions',
                  subtitle: 'Get real-time photography recommendations',
                  value: _configuration.enableAISuggestions,
                  onChanged: (value) {
                    setState(() {
                      _configuration = _configuration.copyWith(enableAISuggestions: value);
                    });
                  },
                ),
              ],
            ),
            
            
            // AI Provider Selection
            const ElegantSectionHeader(
              title: 'AI Provider',
              subtitle: 'Choose your AI service',
            ),
            ElegantCard(
              children: [
                ..._configuration.providers.map((provider) => 
                  ListTile(
                    leading: Icon(
                      _getProviderIcon(provider.type.iconName),
                      color: provider.id == _configuration.selectedProviderId 
                          ? AppColors.accent 
                          : Colors.white70,
                    ),
                    title: Text(
                      provider.name,
                      style: TextStyle(
                        color: provider.id == _configuration.selectedProviderId 
                            ? AppColors.accent 
                            : Colors.white,
                        fontWeight: provider.id == _configuration.selectedProviderId 
                            ? FontWeight.w600 
                            : FontWeight.normal,
                      ),
                    ),
                    subtitle: Text(
                      provider.description,
                      style: const TextStyle(color: Colors.white70),
                    ),
                    trailing: provider.id == _configuration.selectedProviderId 
                        ? const Icon(Icons.check_circle, color: AppColors.accent, size: 20)
                        : const Icon(Icons.radio_button_unchecked, color: Colors.white30, size: 20),
                    onTap: () {
                      setState(() {
                        _configuration = _configuration.copyWith(selectedProviderId: provider.id);
                      });
                    },
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const Divider(color: Colors.white24, height: 1),
              ],
            ),
            
            // Selected Provider Configuration
            if (_configuration.selectedProvider != null) ...[
              ElegantSectionHeader(
                title: 'Configuration',
                subtitle: 'Configure ${_configuration.selectedProvider!.name}',
              ),
              _buildProviderCard(_configuration.selectedProvider!),
            ],
            
            // Advanced Settings
            ExpansionTile(
              title: const Text(
                'Advanced Settings',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
              subtitle: const Text(
                'Customize AI behavior and prompts',
                style: TextStyle(color: Colors.white70),
              ),
              iconColor: AppColors.accent,
              collapsedIconColor: Colors.white70,
              children: [
                ElegantCard(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  children: [
                    SettingsSliderRow(
                      title: 'Confidence Threshold',
                      subtitle: 'Minimum confidence for AI suggestions',
                      value: _configuration.suggestionConfidenceThreshold,
                      min: 0.1,
                      max: 1.0,
                      divisions: 9,
                      onChanged: (value) {
                        setState(() {
                          _configuration = _configuration.copyWith(suggestionConfidenceThreshold: value);
                        });
                      },
                    ),
                    SettingsDropdownRow<int>(
                      title: 'Max Suggestions',
                  subtitle: 'Maximum number of AI suggestions to show',
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
                  showDivider: false,
                ),
              ],
            ),
            
            // Custom Prompt Template
            const ElegantSectionHeader(
              title: 'Custom Prompt',
              subtitle: 'Customize AI instructions for better results',
            ),
            ElegantCard(
              children: [
                SettingsTextFieldRow(
                  title: 'Prompt Template',
                  subtitle: 'Custom instructions for the AI to follow',
                  value: _configuration.customPromptTemplate ?? AIConfiguration.getBuiltInPrompt(),
                  hintText: 'Enter custom prompt template...',
                  maxLines: 4,
                  onChanged: (value) {
                    _controllers['custom_prompt']?.text = value;
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () {
                        final defaultPrompt = AIConfiguration.getBuiltInPrompt();
                        setState(() {
                          _configuration = _configuration.copyWith(customPromptTemplate: defaultPrompt);
                          _controllers['custom_prompt']?.text = defaultPrompt;
                        });
                      },
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Reset to Default'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.accent,
                        textStyle: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            ],
            ),
            
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildProviderCard(AIProviderConfig provider) {
    return ElegantCard(
      children: [
        // Provider info header
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _getProviderIcon(provider.type.iconName),
                color: AppColors.accent,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    provider.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    provider.description,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        
        // Provider-specific configuration
        if (provider.type == AIProviderType.local) ...
          _buildLocalAIConfiguration(provider)
        else if (provider.type == AIProviderType.custom) ...
          _buildCustomProviderConfiguration(provider)
        else ...
          _buildCloudProviderConfiguration(provider),
      ],
    );
  }
  
  List<Widget> _buildLocalAIConfiguration(AIProviderConfig provider) {
    return [
      ElegantStatusCard(
        title: 'Status',
        status: 'Ready',
        statusType: StatusType.success,
        description: 'Local AI processing is available offline',
      ),
      const SizedBox(height: 16),
      if (provider.availableModels.isNotEmpty) ...[
        SettingsDropdownRow<String>(
          title: 'Model',
          subtitle: 'Local AI model for offline processing',
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
          showDivider: false,
        ),
      ],
    ];
  }
  
  List<Widget> _buildCustomProviderConfiguration(AIProviderConfig provider) {
    return [
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
      SettingsTextFieldRow(
        title: 'API Endpoint',
        subtitle: 'Your custom API endpoint URL',
        value: _controllers['${provider.id}_endpoint']?.text,
        hintText: 'https://api.example.com/v1',
        onChanged: (value) {
          _controllers['${provider.id}_endpoint']?.text = value;
        },
      ),
      SettingsTextFieldRow(
        title: 'API Key', 
        subtitle: 'API key for your custom endpoint',
        value: _controllers['${provider.id}_apikey']?.text,
        hintText: 'Enter your API key...',
        obscureText: true,
        onChanged: (value) {
          _controllers['${provider.id}_apikey']?.text = value;
        },
      ),
      if (provider.availableModels.isNotEmpty) ...[
        SettingsDropdownRow<String>(
          title: 'Model',
          subtitle: 'Available model from your endpoint',
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
      ],
      const SizedBox(height: 16),
      ElegantConnectionTestCard(
        title: 'Connection Test',
        endpoint: _controllers['${provider.id}_endpoint']?.text.isNotEmpty == true 
            ? _controllers['${provider.id}_endpoint']!.text 
            : 'Not configured',
        onTest: () => _testConnection(provider),
      ),
    ];
  }
  
  List<Widget> _buildCloudProviderConfiguration(AIProviderConfig provider) {
    return [
      SettingsTextFieldRow(
        title: 'API Endpoint',
        subtitle: _getEndpointSubtitle(provider.type),
        value: _controllers['${provider.id}_endpoint']?.text,
        hintText: provider.type.defaultEndpoint ?? 'https://api.example.com/v1',
        onChanged: (value) {
          _controllers['${provider.id}_endpoint']?.text = value;
        },
      ),
      SettingsTextFieldRow(
        title: 'API Key',
        subtitle: _getApiKeySubtitle(provider.type),
        value: _controllers['${provider.id}_apikey']?.text,
        hintText: 'Enter your API key...',
        obscureText: true,
        onChanged: (value) {
          _controllers['${provider.id}_apikey']?.text = value;
        },
      ),
      if (provider.availableModels.isNotEmpty) ...[
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
      ],
      const SizedBox(height: 16),
      ElegantConnectionTestCard(
        title: 'Connection Test',
        endpoint: _controllers['${provider.id}_endpoint']?.text.isNotEmpty == true 
            ? _controllers['${provider.id}_endpoint']!.text 
            : provider.type.defaultEndpoint ?? 'Not configured',
        onTest: () => _testConnection(provider),
      ),
    ];
  }
  
  String _getEndpointSubtitle(AIProviderType type) {
    switch (type) {
      case AIProviderType.openai:
        return 'OpenAI API endpoint (leave default unless using proxy)';
      case AIProviderType.anthropic:
        return 'Anthropic API endpoint (leave default unless using proxy)';
      case AIProviderType.google:
        return 'Google Gemini API endpoint';
      case AIProviderType.azure:
        return 'Your specific Azure OpenAI endpoint URL';
      case AIProviderType.local:
        return 'Local server endpoint';
      case AIProviderType.custom:
        return 'Your custom API endpoint URL';
    }
  }
  
  String _getApiKeySubtitle(AIProviderType type) {
    switch (type) {
      case AIProviderType.openai:
        return 'Get from platform.openai.com → API Keys';
      case AIProviderType.anthropic:
        return 'Get from console.anthropic.com → API Keys';
      case AIProviderType.google:
        return 'Get from ai.google.dev → API Keys';
      case AIProviderType.azure:
        return 'Your Azure OpenAI resource API key';
      case AIProviderType.local:
        return 'Local authentication key (if required)';
      case AIProviderType.custom:
        return 'API key for your custom endpoint';
    }
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
        id: 'local',
        name: 'Local AI',
        description: 'Local AI processing without internet connection',
        type: AIProviderType.local,
        endpoint: 'http://localhost:8080',
        availableModels: AIProviderType.local.defaultModels,
        selectedModel: 'local-model',
        isEnabled: true,
      ),
      AIProviderConfig(
        id: 'custom',
        name: 'Custom Endpoint',
        description: 'Custom API endpoint for flexible AI integration',
        type: AIProviderType.custom,
        protocol: AIProtocol.openai,
        endpoint: 'https://openaiproxy.cfapps.sap.hana.ondemand.com/anthropic',
        availableModels: ['claude-3-sonnet-20240229'],
        selectedModel: 'claude-3-sonnet-20240229',
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
        isEnabled: true,
      ),
      AIProviderConfig(
        id: 'anthropic',
        name: 'Anthropic Claude',
        description: 'Anthropic Claude for detailed analysis',
        type: AIProviderType.anthropic,
        endpoint: 'https://api.anthropic.com',
        availableModels: AIProviderType.anthropic.defaultModels,
        selectedModel: 'claude-3-5-sonnet-20241022',
        isEnabled: true,
      ),
      AIProviderConfig(
        id: 'google',
        name: 'Google Gemini',
        description: 'Google Gemini for multimodal understanding',
        type: AIProviderType.google,
        endpoint: 'https://generativelanguage.googleapis.com/v1',
        availableModels: AIProviderType.google.defaultModels,
        selectedModel: 'gemini-1.5-pro',
        isEnabled: true,
      ),
    ];
  }
}
