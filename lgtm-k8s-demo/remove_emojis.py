#!/usr/bin/env python3
import os
import re

# List of emojis to remove
emojis = [
    '🚀', '📋', '✅', '❌', 'ℹ️', '⏳', '📦', '📁', '🔧', '📌',
    '🪵', '🔍', '📈', '📊', '🐍', '🔨', '✓', '⚠️', '🧪', '🧹',
    '🎉', '🔗', '📝', '🎯', '🆘', '🎨', '📚', '⚙️', '🏗️', '📄',
    '🧠', '💡', '🌟', '🔥', '💻', '🚧', '📣', '👍', '👎', '🙏',
    '🤔', '😊', '😢', '😍', '😡', '🎊', '🎈', '🎁', '🏆', '✨'
]

def remove_emojis(text):
    """Remove all emojis from text"""
    for emoji in emojis:
        text = text.replace(emoji, '')
    # Remove any remaining emoji characters
    text = re.sub(r'[\U00010000-\U0010ffff]', '', text)
    return text

def process_file(filepath):
    """Remove emojis from a file"""
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
        
        new_content = remove_emojis(content)
        
        if content != new_content:
            with open(filepath, 'w', encoding='utf-8') as f:
                f.write(new_content)
            print(f"Cleaned: {filepath}")
            return True
        return False
    except Exception as e:
        print(f"Error processing {filepath}: {e}")
        return False

def main():
    # Get current directory
    base_dir = os.path.dirname(os.path.abspath(__file__))
    
    # Files to process
    files_to_process = [
        'deploy.sh',
        'cleanup.sh',
        'README.md',
        'QUICKSTART.md',
        'PROJECT-SUMMARY.md',
        'TESTING-GUIDE.md',
        'app.py'
    ]
    
    cleaned_count = 0
    for filename in files_to_process:
        filepath = os.path.join(base_dir, filename)
        if os.path.exists(filepath):
            if process_file(filepath):
                cleaned_count += 1
        else:
            print(f"File not found: {filename}")
    
    print(f"\nTotal files cleaned: {cleaned_count}")

if __name__ == "__main__":
    main()

