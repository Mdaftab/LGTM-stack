#!/bin/bash

# Remove emojis from all project files

echo "Removing emojis from project files..."

# Files to clean
FILES=(
  "deploy.sh"
  "cleanup.sh"
  "README.md"
  "QUICKSTART.md"
  "PROJECT-SUMMARY.md"
  "TESTING-GUIDE.md"
)

# Process each file
for file in "${FILES[@]}"; do
  if [ -f "$file" ]; then
    echo "Cleaning $file..."
    # Create backup
    cp "$file" "$file.bak"
    
    # Remove common emojis (this is a simplified approach)
    LC_ALL=C sed -i '' 's/[^[:print:]	]//g' "$file"
    
    echo "  Done: $file"
  else
    echo "  Skipped: $file (not found)"
  fi
done

echo ""
echo "Emoji removal complete!"
echo "Backup files created with .bak extension"

