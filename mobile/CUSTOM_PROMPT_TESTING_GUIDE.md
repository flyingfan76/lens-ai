# Custom Prompt Testing Guide

## How to Test Custom Prompts

The mobile app now fully supports custom prompt functionality. Here's how to test it:

### 🧪 **Testing Steps:**

1. **Open AI Settings**
   - Launch the camera screen
   - Tap the AI suggestion button (floating button)
   - Tap the settings icon (tune icon) in the AI panel header
   - Navigate to the "Prompts" tab

2. **Test Built-in Templates**
   - Try each template: Basic Analysis, Detailed Technical, Creative Focus, Beginner Friendly
   - Each template generates different types of suggestions

3. **Create Custom Prompts**
   - Select "Custom Prompt" in the prompt editor
   - Try these test prompts:

### 📝 **Test Prompts to Try:**

**For Technical Analysis:**
```
Give me detailed technical camera settings for {cameraModel}. 
Current settings: ISO {currentISO}, f/{currentAperture}
Scene: {sceneType}, Lighting: {lightingConditions}
Focus on professional technical recommendations including exposure compensation, HDR, and stabilization.
```

**For Creative Photography:**
```
Help me take creative and artistic photos with {cameraModel}.
Scene type: {sceneType} 
I want unique and artistic suggestions including bokeh effects, creative white balance, and composition ideas.
```

**For Specific Settings:**
```
Analyze this {sceneType} scene and recommend:
- ISO and exposure settings
- Focus mode and focus point
- Flash and lighting recommendations  
- HDR settings if needed
- Image stabilization
- Zoom and composition tips
```

**For Advanced Features:**
```
Professional analysis needed for {cameraModel}:
- Technical exposure settings (ISO, aperture, shutter)
- Advanced focus controls and stabilization
- HDR and dynamic range optimization
- Professional composition and zoom recommendations
Current: ISO {currentISO}, f/{currentAperture}, {lightingConditions} lighting
```

### 🔍 **What to Look For:**

**Keyword Detection:**
- **"technical/detailed/professional"** → Generates technical suggestions with exposure compensation, precise calculations
- **"creative/artistic/unique"** → Generates bokeh, creative white balance, artistic suggestions  
- **"beginner/simple/easy"** → Generates auto mode, simple flash recommendations
- **"iso/exposure"** → Generates specific ISO and exposure compensation suggestions
- **"focus/sharp"** → Generates focus mode, focus point suggestions
- **"flash/light"** → Generates flash and white balance lighting suggestions  
- **"hdr/dynamic range"** → Generates HDR mode and exposure bracketing suggestions
- **"stabilization/shake/blur"** → Generates image stabilization suggestions
- **"zoom/composition"** → Generates zoom and composition suggestions

### ✅ **Expected Results:**

**Before (Default):**
- Basic 3-4 suggestions (ISO, aperture, white balance, composition)
- Generic recommendations

**After Custom Prompt:**
- **5-15+ suggestions** based on prompt keywords
- **Specific technical analysis** (exposure compensation, HDR, stabilization)
- **Custom prompt indicator** showing which template was used
- **Advanced camera settings** not normally suggested
- **Explanations match** the prompt style (technical vs creative vs beginner)

### 🎯 **Verification:**

1. **Save Custom Prompt** → Close settings → Open AI panel → Tap refresh
2. **Check Suggestions Count** → Should be significantly more than default
3. **Look for Custom Prompt Note** → Should show "Generated using your custom prompt template"
4. **Verify Settings Variety** → Should include advanced settings like:
   - Exposure compensation
   - HDR mode
   - Focus modes
   - Stabilization
   - Flash recommendations
   - Zoom suggestions

### 🐛 **Troubleshooting:**

**If custom prompts aren't working:**
1. Make sure to **save settings** after editing prompt
2. **Refresh suggestions** by tapping the refresh button
3. Check that keywords are in the prompt (technical, creative, focus, etc.)
4. Look for the "Custom Prompt Analysis" suggestion at the bottom

**Keywords are case-insensitive**, so "Technical", "TECHNICAL", and "technical" all work.

---

## 🚀 **Advanced Testing:**

**Template Variables:**
Test variable substitution by including these in your prompts:
- `{cameraModel}` → "Mobile Camera"
- `{currentISO}` → Current ISO setting
- `{currentAperture}` → Current aperture value
- `{sceneType}` → Detected scene type
- `{lightingConditions}` → Lighting analysis

**Complex Prompts:**
Try combining multiple keywords:
```
Professional technical analysis for creative photography.
Focus on HDR, stabilization, and artistic composition.
Current camera: {cameraModel} at ISO {currentISO}
```

This should trigger technical, creative, HDR, stabilization, and composition suggestion generators simultaneously!