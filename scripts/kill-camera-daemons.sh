#!/bin/bash
# Kill macOS camera daemons that interfere with external camera access

echo "Killing camera-related daemons..."

# Kill PTP camera daemon (the main culprit)
pkill -f ptpcamerad
echo "- Killed ptpcamerad"

# Kill MSC camera daemon
pkill -f mscamerad  
echo "- Killed mscamerad"

# Kill any other camera processes
pkill -f "Photo Booth"
pkill -f Camera
echo "- Killed other camera processes"

echo "✅ Camera daemons terminated. You can now use external cameras."