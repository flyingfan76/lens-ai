/// AI provider configuration models
class AIProviderConfig {
  final String id;
  final String name;
  final String description;
  final AIProviderType type;
  final AIProtocol? protocol;
  final String? endpoint;
  final String? apiKey;
  final String? selectedModel;
  final List<String> availableModels;
  final Map<String, dynamic> advancedSettings;
  final bool isEnabled;
  final bool isCustom;

  const AIProviderConfig({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    this.protocol,
    this.endpoint,
    this.apiKey,
    this.selectedModel,
    this.availableModels = const [],
    this.advancedSettings = const {},
    this.isEnabled = true,
    this.isCustom = false,
  });

  AIProviderConfig copyWith({
    String? id,
    String? name,
    String? description,
    AIProviderType? type,
    AIProtocol? protocol,
    String? endpoint,
    String? apiKey,
    String? selectedModel,
    List<String>? availableModels,
    Map<String, dynamic>? advancedSettings,
    bool? isEnabled,
    bool? isCustom,
  }) {
    return AIProviderConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      type: type ?? this.type,
      protocol: protocol ?? this.protocol,
      endpoint: endpoint ?? this.endpoint,
      apiKey: apiKey ?? this.apiKey,
      selectedModel: selectedModel ?? this.selectedModel,
      availableModels: availableModels ?? this.availableModels,
      advancedSettings: advancedSettings ?? this.advancedSettings,
      isEnabled: isEnabled ?? this.isEnabled,
      isCustom: isCustom ?? this.isCustom,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'type': type.name,
      'protocol': protocol?.name,
      'endpoint': endpoint,
      'apiKey': apiKey,
      'selectedModel': selectedModel,
      'availableModels': availableModels,
      'advancedSettings': advancedSettings,
      'isEnabled': isEnabled,
      'isCustom': isCustom,
    };
  }

  factory AIProviderConfig.fromJson(Map<String, dynamic> json) {
    return AIProviderConfig(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      type: AIProviderType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => AIProviderType.custom,
      ),
      protocol: json['protocol'] != null 
          ? AIProtocol.values.firstWhere(
              (e) => e.name == json['protocol'],
              orElse: () => AIProtocol.openai,
            )
          : null,
      endpoint: json['endpoint'] as String?,
      apiKey: json['apiKey'] as String?,
      selectedModel: json['selectedModel'] as String?,
      availableModels: (json['availableModels'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ?? [],
      advancedSettings: json['advancedSettings'] as Map<String, dynamic>? ?? {},
      isEnabled: json['isEnabled'] as bool? ?? true,
      isCustom: json['isCustom'] as bool? ?? false,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AIProviderConfig && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

enum AIProviderType {
  openai,
  anthropic,
  google,
  azure,
  local,
  custom,
}

enum AIProtocol {
  openai,
  anthropic,
  google,
  custom,
}

extension AIProtocolExtension on AIProtocol {
  String get displayName {
    switch (this) {
      case AIProtocol.openai:
        return 'OpenAI Compatible';
      case AIProtocol.anthropic:
        return 'Anthropic Compatible';
      case AIProtocol.google:
        return 'Google Vertex Compatible';
      case AIProtocol.custom:
        return 'Custom Protocol';
    }
  }

  String get description {
    switch (this) {
      case AIProtocol.openai:
        return 'Compatible with OpenAI API format';
      case AIProtocol.anthropic:
        return 'Compatible with Anthropic API format';
      case AIProtocol.google:
        return 'Compatible with Google Vertex AI format';
      case AIProtocol.custom:
        return 'Custom API protocol implementation';
    }
  }
}

extension AIProviderTypeExtension on AIProviderType {
  String get displayName {
    switch (this) {
      case AIProviderType.openai:
        return 'OpenAI';
      case AIProviderType.anthropic:
        return 'Anthropic Claude';
      case AIProviderType.google:
        return 'Google Gemini';
      case AIProviderType.azure:
        return 'Azure OpenAI';
      case AIProviderType.local:
        return 'Local AI';
      case AIProviderType.custom:
        return 'Custom Endpoint';
    }
  }

  String get description {
    switch (this) {
      case AIProviderType.openai:
        return 'OpenAI GPT models for image analysis and suggestions';
      case AIProviderType.anthropic:
        return 'Anthropic Claude models for detailed photography advice';
      case AIProviderType.google:
        return 'Google Gemini for multimodal image understanding';
      case AIProviderType.azure:
        return 'Azure OpenAI with enterprise features';
      case AIProviderType.local:
        return 'Local AI processing without internet connection';
      case AIProviderType.custom:
        return 'Custom API endpoint with configurable parameters';
    }
  }

  List<String> get defaultModels {
    switch (this) {
      case AIProviderType.openai:
        return ['gpt-4-vision-preview', 'gpt-4o', 'gpt-4o-mini'];
      case AIProviderType.anthropic:
        return ['claude-3-5-sonnet-20241022', 'claude-3-opus-20240229', 'claude-3-haiku-20240307'];
      case AIProviderType.google:
        return ['gemini-1.5-pro', 'gemini-1.5-flash', 'gemini-pro-vision'];
      case AIProviderType.azure:
        return ['gpt-4', 'gpt-4-32k', 'gpt-4-vision'];
      case AIProviderType.local:
        return ['local-model'];
      case AIProviderType.custom:
        return [];
    }
  }

  String? get defaultEndpoint {
    switch (this) {
      case AIProviderType.openai:
        return 'https://api.openai.com/v1';
      case AIProviderType.anthropic:
        return 'https://api.anthropic.com';
      case AIProviderType.google:
        return 'https://generativelanguage.googleapis.com/v1';
      case AIProviderType.azure:
        return null; // User must provide their Azure endpoint
      case AIProviderType.local:
        return 'http://localhost:8080';
      case AIProviderType.custom:
        return null; // User configurable
    }
  }

  String get iconName {
    switch (this) {
      case AIProviderType.openai:
        return 'auto_awesome';
      case AIProviderType.anthropic:
        return 'psychology';
      case AIProviderType.google:
        return 'search';
      case AIProviderType.azure:
        return 'cloud';
      case AIProviderType.local:
        return 'computer';
      case AIProviderType.custom:
        return 'settings_ethernet';
    }
  }
}

/// AI configuration preferences
class AIConfiguration {
  final String selectedProviderId;
  final List<AIProviderConfig> providers;
  final bool enableAISuggestions;
  final bool enableAutoAnalysis;
  final String customPromptTemplate;
  final double suggestionConfidenceThreshold;
  final int maxSuggestions;

  const AIConfiguration({
    required this.selectedProviderId,
    required this.providers,
    this.enableAISuggestions = true,
    this.enableAutoAnalysis = false,
    this.customPromptTemplate = '',
    this.suggestionConfidenceThreshold = 0.7,
    this.maxSuggestions = 5,
  });

  AIConfiguration copyWith({
    String? selectedProviderId,
    List<AIProviderConfig>? providers,
    bool? enableAISuggestions,
    bool? enableAutoAnalysis,
    String? customPromptTemplate,
    double? suggestionConfidenceThreshold,
    int? maxSuggestions,
  }) {
    return AIConfiguration(
      selectedProviderId: selectedProviderId ?? this.selectedProviderId,
      providers: providers ?? this.providers,
      enableAISuggestions: enableAISuggestions ?? this.enableAISuggestions,
      enableAutoAnalysis: enableAutoAnalysis ?? this.enableAutoAnalysis,
      customPromptTemplate: customPromptTemplate ?? this.customPromptTemplate,
      suggestionConfidenceThreshold: suggestionConfidenceThreshold ?? this.suggestionConfidenceThreshold,
      maxSuggestions: maxSuggestions ?? this.maxSuggestions,
    );
  }

  AIProviderConfig? get selectedProvider {
    try {
      return providers.firstWhere((p) => p.id == selectedProviderId);
    } catch (e) {
      return null;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'selectedProviderId': selectedProviderId,
      'providers': providers.map((p) => p.toJson()).toList(),
      'enableAISuggestions': enableAISuggestions,
      'enableAutoAnalysis': enableAutoAnalysis,
      'customPromptTemplate': customPromptTemplate,
      'suggestionConfidenceThreshold': suggestionConfidenceThreshold,
      'maxSuggestions': maxSuggestions,
    };
  }

  factory AIConfiguration.fromJson(Map<String, dynamic> json) {
    return AIConfiguration(
      selectedProviderId: json['selectedProviderId'] as String,
      providers: (json['providers'] as List<dynamic>)
          .map((p) => AIProviderConfig.fromJson(p as Map<String, dynamic>))
          .toList(),
      enableAISuggestions: json['enableAISuggestions'] as bool? ?? true,
      enableAutoAnalysis: json['enableAutoAnalysis'] as bool? ?? false,
      customPromptTemplate: json['customPromptTemplate'] as String? ?? '',
      suggestionConfidenceThreshold: json['suggestionConfidenceThreshold'] as double? ?? 0.7,
      maxSuggestions: json['maxSuggestions'] as int? ?? 5,
    );
  }
}