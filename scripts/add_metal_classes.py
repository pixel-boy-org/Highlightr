#!/usr/bin/env python3
"""
Script to add Metal shader-specific CSS classes to all highlight.js themes.

Adds the following classes to each theme:
- .hljs-type (with italic style)
- .hljs-type-vector (for float2, float3, float4, etc.)
- .hljs-type-matrix (for float4x4, etc.)
- .hljs-type-texture (for texture2d, etc.)
- .hljs-title.function (for function names)

Colors are intelligently selected based on each theme's existing palette.
"""

import os
import re
import sys
from pathlib import Path


def extract_colors(css_content):
    """Extract color mappings from CSS content."""
    colors = {}

    # Pattern to match .hljs-something{...color:#xxx...}
    # Handle both simple and compound selectors
    patterns = [
        (r'\.hljs-type\{[^}]*color:\s*(#[0-9a-fA-F]{3,6})', 'type'),
        (r'\.hljs-keyword\{[^}]*color:\s*(#[0-9a-fA-F]{3,6})', 'keyword'),
        (r'\.hljs-keyword,[^{]*\{[^}]*color:\s*(#[0-9a-fA-F]{3,6})', 'keyword'),
        (r'\.hljs-number[,\{][^}]*color:\s*(#[0-9a-fA-F]{3,6})', 'number'),
        (r'\.hljs-literal[,\{][^}]*color:\s*(#[0-9a-fA-F]{3,6})', 'literal'),
        (r'\.hljs-string[,\{][^}]*color:\s*(#[0-9a-fA-F]{3,6})', 'string'),
        (r'\.hljs-built_in[,\{][^}]*color:\s*(#[0-9a-fA-F]{3,6})', 'built_in'),
        (r'\.hljs-title\.function_[,\{][^}]*color:\s*(#[0-9a-fA-F]{3,6})', 'function'),
        (r'\.hljs-function\s+\.hljs-title[,\{][^}]*color:\s*(#[0-9a-fA-F]{3,6})', 'function'),
        (r'\.hljs-attribute[,\{][^}]*color:\s*(#[0-9a-fA-F]{3,6})', 'attribute'),
        (r'\.hljs-name[,\{][^}]*color:\s*(#[0-9a-fA-F]{3,6})', 'name'),
        (r'\.hljs-variable[,\{][^}]*color:\s*(#[0-9a-fA-F]{3,6})', 'variable'),
        (r'\.hljs-symbol[,\{][^}]*color:\s*(#[0-9a-fA-F]{3,6})', 'symbol'),
        (r'\.hljs-meta[,\{][^}]*color:\s*(#[0-9a-fA-F]{3,6})', 'meta'),
        (r'\.hljs\{[^}]*color:\s*(#[0-9a-fA-F]{3,6})', 'base'),
        (r'\.hljs\{[^}]*background:\s*(#[0-9a-fA-F]{3,6})', 'background'),
    ]

    for pattern, name in patterns:
        match = re.search(pattern, css_content)
        if match and name not in colors:
            colors[name] = match.group(1)

    return colors


def is_dark_theme(colors):
    """Determine if a theme is dark based on background color."""
    bg = colors.get('background', '#ffffff')
    # Convert to RGB and check luminance
    bg = bg.lstrip('#')
    if len(bg) == 3:
        bg = ''.join([c*2 for c in bg])
    try:
        r, g, b = int(bg[0:2], 16), int(bg[2:4], 16), int(bg[4:6], 16)
        luminance = (0.299 * r + 0.587 * g + 0.114 * b) / 255
        return luminance < 0.5
    except:
        return True  # Default to dark


def select_metal_colors(colors, is_dark):
    """Select appropriate colors for Metal-specific classes."""
    # Priority order for each Metal type
    # type-vector: prefer type, number, or literal colors (numeric types)
    # type-matrix: prefer keyword or name colors (structural)
    # type-texture: prefer attribute, built_in, or meta colors (special)
    # function: prefer existing function color, or string/built_in

    type_color = colors.get('type') or colors.get('keyword') or colors.get('literal', '#6c71c4')

    vector_color = (
        colors.get('number') or
        colors.get('literal') or
        colors.get('symbol') or
        colors.get('type') or
        ('#ae81ff' if is_dark else '#6c71c4')
    )

    matrix_color = (
        colors.get('keyword') or
        colors.get('name') or
        colors.get('type') or
        ('#f92672' if is_dark else '#a71d5d')
    )

    texture_color = (
        colors.get('attribute') or
        colors.get('built_in') or
        colors.get('meta') or
        colors.get('variable') or
        ('#fd971f' if is_dark else '#cb4b16')
    )

    function_color = (
        colors.get('function') or
        colors.get('string') or
        colors.get('built_in') or
        ('#a6e22e' if is_dark else '#859900')
    )

    return {
        'type': type_color,
        'vector': vector_color,
        'matrix': matrix_color,
        'texture': texture_color,
        'function': function_color,
    }


def has_metal_classes(css_content):
    """Check if CSS already has Metal-specific classes."""
    return '.hljs-type-vector' in css_content


def generate_metal_css(metal_colors):
    """Generate the Metal-specific CSS rules."""
    rules = []

    # .hljs-type with italic
    rules.append(f".hljs-type{{color:{metal_colors['type']};font-style:italic}}")

    # .hljs-type-vector
    rules.append(f".hljs-type-vector{{color:{metal_colors['vector']};font-weight:700}}")

    # .hljs-type-matrix
    rules.append(f".hljs-type-matrix{{color:{metal_colors['matrix']};font-weight:700}}")

    # .hljs-type-texture
    rules.append(f".hljs-type-texture{{color:{metal_colors['texture']};font-weight:700}}")

    # .hljs-title.function
    rules.append(f".hljs-title.function{{color:{metal_colors['function']};font-weight:400}}")

    return ''.join(rules)


def update_css_file(filepath):
    """Update a single CSS file with Metal classes."""
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # Skip if already has Metal classes
    if has_metal_classes(content):
        return False, "Already has Metal classes"

    # Extract colors
    colors = extract_colors(content)
    if not colors:
        return False, "Could not extract colors"

    # Determine theme type and select colors
    is_dark = is_dark_theme(colors)
    metal_colors = select_metal_colors(colors, is_dark)

    # Generate new CSS rules
    metal_css = generate_metal_css(metal_colors)

    # Append to content (remove trailing newline if present, then add rules)
    content = content.rstrip()
    if not content.endswith('}'):
        return False, "CSS doesn't end with closing brace"

    new_content = content + metal_css

    # Write back
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(new_content)

    return True, metal_colors


def main():
    # Find the styles directory
    script_dir = Path(__file__).parent
    styles_dir = script_dir.parent / 'src' / 'assets' / 'styles'

    if not styles_dir.exists():
        print(f"Error: Styles directory not found at {styles_dir}")
        sys.exit(1)

    # Get all CSS files
    css_files = sorted(styles_dir.glob('*.min.css'))

    if not css_files:
        print(f"Error: No CSS files found in {styles_dir}")
        sys.exit(1)

    print(f"Found {len(css_files)} CSS files")
    print("-" * 60)

    updated = 0
    skipped = 0
    errors = 0

    for css_file in css_files:
        name = css_file.name
        success, result = update_css_file(css_file)

        if success:
            print(f"✓ {name}")
            print(f"  vector: {result['vector']}, matrix: {result['matrix']}, "
                  f"texture: {result['texture']}, function: {result['function']}")
            updated += 1
        else:
            if "Already has" in result:
                print(f"○ {name} - {result}")
                skipped += 1
            else:
                print(f"✗ {name} - {result}")
                errors += 1

    print("-" * 60)
    print(f"Updated: {updated}, Skipped: {skipped}, Errors: {errors}")


if __name__ == '__main__':
    main()
