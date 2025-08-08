# AI Prompt Reset Functionality

## Overview
The AI settings now include reset functionality to help users recover from malformed prompts or return to default configurations.

## Features Implemented

### 1. Default Prompt Restoration
- **Location**: AI Settings → Prompts tab
- **Button**: Refresh icon (🔄) next to the help button
- **Function**: Resets custom prompt to the default "Basic Analysis" template

### 2. Status Indicator
- Shows "✓ Using default prompt" when current prompt matches default
- Green checkmark indicates safe/default configuration

### 3. Confirmation Dialog
- Asks user to confirm before overwriting custom prompt
- Clear warning about losing current customizations
- Cancel option to prevent accidental resets

### 4. Complete Settings Reset
- **Location**: AI Settings → Advanced tab → Reset Settings section
- **Function**: Resets ALL AI settings to factory defaults
- **Includes**:
  - Provider selection → Local Only
  - API keys → Cleared
  - Prompt template → Default
  - Advanced settings → Default values
  - Category filters → Default selection

## Usage Examples

### Scenario 1: Malformed Prompt Recovery
```
User accidentally creates invalid prompt syntax:
"Analyze {bad_variable} with wrong {format"

Solution:
1. Go to AI Settings → Prompts tab
2. Click refresh icon (🔄) next to "Custom Prompt"
3. Confirm reset in dialog
4. Prompt restored to working default template
```

### Scenario 2: Complete Configuration Reset
```
User has complex configuration causing issues:
- Custom API provider not working
- Modified confidence thresholds
- Custom categories causing problems

Solution:
1. Go to AI Settings → Advanced tab
2. Scroll to "Reset Settings" section
3. Click "Reset All" button
4. Confirm complete reset
5. All settings restored to safe defaults
```

## Safety Features

### Confirmation Dialogs
- **Prompt Reset**: Shows exactly what will be overwritten
- **Full Reset**: Lists all settings that will be changed
- **Cancel Options**: Easy to back out of reset operations

### Visual Feedback
- Success messages after reset operations
- Status indicators show current configuration state
- Clear labeling of reset buttons with tooltips

### Default Template
The default "Basic Analysis" template is safe and functional:

```
Analyze this photograph and provide camera settings recommendations.

Current Camera: {camera_model}
Current Settings: ISO {iso}, f/{aperture}, {shutter_speed}, {white_balance}
Scene: {scene_type}
Lighting: {lighting_conditions}
User Request: {user_request}

Provide practical suggestions for better photography.
```

This template includes all necessary variable substitutions and provides a balanced approach to AI analysis.

## Technical Implementation

### UnifiedAIService Methods
- `getDefaultPromptTemplate()`: Returns the safe default prompt
- `resetToDefaultPrompt()`: Updates configuration to default
- `isUsingDefaultPrompt()`: Checks if current prompt is default

### UI Components
- Reset buttons with appropriate icons and colors
- Confirmation dialogs with detailed explanations
- Status indicators for current configuration state

## Benefits

1. **Recovery Path**: Users can always return to working configuration
2. **Experimentation Safety**: Encourages trying custom prompts knowing reset is available
3. **Support Simplification**: Support can simply say "try resetting to defaults"
4. **User Confidence**: Reduces fear of "breaking" the AI settings

The reset functionality ensures users never get permanently stuck with malformed or problematic AI configurations.