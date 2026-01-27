#!/usr/bin/env python3
"""
Script to replace standard Flutter buttons with Expressive versions throughout the app.
"""

import os
import re
from pathlib import Path

# Mapping of standard widgets to expressive versions
WIDGET_MAPPING = {
    'IconButton': 'ExpressiveIconButton',
    'TextButton': 'ExpressiveTextButton',
    'ElevatedButton': 'ExpressiveElevatedButton',
    'OutlinedButton': 'ExpressiveOutlinedButton',
    'FloatingActionButton': 'ExpressiveFloatingActionButton',
    'InkWell': 'ExpressiveInkWell',
    'GestureDetector': 'ExpressiveGestureDetector',
}

# Import statement to add
COMMON_IMPORT = "import '../widgets/common/common.dart';"

def should_process_file(file_path):
    """Check if file should be processed"""
    path_str = str(file_path)
    
    # Skip submodules
    if 'submodules' in path_str:
        return False
    
    # Skip the expressive_button.dart file itself
    if 'expressive_button.dart' in path_str or 'common.dart' in path_str:
        return False
    
    # Skip this script
    if 'replace_buttons.py' in path_str:
        return False
    
    return True

def has_buttons(content):
    """Check if file contains any of the button widgets"""
    for widget in WIDGET_MAPPING.keys():
        if f'{widget}(' in content:
            return True
    return False

def get_import_section_end(lines):
    """Find the last import line index"""
    last_import_idx = -1
    for i, line in enumerate(lines):
        if line.strip().startswith('import '):
            last_import_idx = i
    return last_import_idx

def add_common_import(lines, file_path):
    """Add common.dart import if not present"""
    content = '\n'.join(lines)
    
    # Check if already imported
    if 'widgets/common/common.dart' in content or 'widgets/common/expressive_button.dart' in content:
        return lines, False
    
    # Find last import
    last_import_idx = get_import_section_end(lines)
    
    if last_import_idx == -1:
        # No imports, add at top after any comments
        for i, line in enumerate(lines):
            if not line.strip().startswith('//') and line.strip():
                lines.insert(i, COMMON_IMPORT)
                return lines, True
        lines.insert(0, COMMON_IMPORT)
        return lines, True
    
    # Determine relative path
    # Count directory depth to calculate relative import path
    file_path_obj = Path(file_path)
    lib_index = list(file_path_obj.parts).index('lib')
    depth_from_lib = len(file_path_obj.parts) - lib_index - 2  # -2 for 'lib' and filename
    
    # Create appropriate relative import
    if depth_from_lib == 0:
        # In lib/ directly
        relative_import = "import 'widgets/common/common.dart';"
    else:
        # In subdirectory
        relative_import = f"import '{'../' * depth_from_lib}widgets/common/common.dart';"
    
    # Insert after last import
    lines.insert(last_import_idx + 1, relative_import)
    return lines, True

def replace_widgets(content):
    """Replace widget names with expressive versions"""
    modified = content
    replacements_made = []
    
    for old_widget, new_widget in WIDGET_MAPPING.items():
        # Match widget name followed by opening parenthesis or period (for named constructors)
        pattern = r'\b' + old_widget + r'(?=[\(\.])'
        if re.search(pattern, modified):
            modified = re.sub(pattern, new_widget, modified)
            replacements_made.append(old_widget)
    
    return modified, replacements_made

def process_file(file_path):
    """Process a single Dart file"""
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()
        
        if not has_buttons(content):
            return False, []
        
        lines = content.split('\n')
        
        # Add import
        lines, import_added = add_common_import(lines, file_path)
        
        # Replace widgets
        modified_content = '\n'.join(lines)
        modified_content, replacements = replace_widgets(modified_content)
        
        if import_added or replacements:
            with open(file_path, 'w', encoding='utf-8') as f:
                f.write(modified_content)
            return True, replacements
        
        return False, []
    
    except Exception as e:
        print(f"Error processing {file_path}: {e}")
        return False, []

def main():
    """Main function to process all Dart files"""
    lib_path = Path('lib')
    
    if not lib_path.exists():
        print("Error: lib directory not found. Run this script from the project root.")
        return
    
    dart_files = list(lib_path.rglob('*.dart'))
    processed_count = 0
    total_replacements = {}
    
    print(f"Found {len(dart_files)} Dart files")
    print("Processing files...")
    
    for dart_file in dart_files:
        if not should_process_file(dart_file):
            continue
        
        modified, replacements = process_file(dart_file)
        
        if modified:
            processed_count += 1
            print(f"✓ {dart_file}")
            for widget in replacements:
                total_replacements[widget] = total_replacements.get(widget, 0) + 1
    
    print(f"\n{'='*50}")
    print(f"Processing complete!")
    print(f"Files modified: {processed_count}")
    print(f"\nReplacements made:")
    for widget, count in sorted(total_replacements.items()):
        print(f"  {widget} → Expressive{widget}: {count} files")
    print(f"{'='*50}")

if __name__ == '__main__':
    main()
