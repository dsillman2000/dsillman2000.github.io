---
name: dsillman-rebase-swimmer
description: Compares the current project to the swimmer reference theme, preserving small variations and consulting for judgement calls
---

# dsillman-rebase-swimmer

## Overview

Compares the current project (dsillman2000.github.io) to the swimmer reference theme (dsillman2000/swimmer) to identify differences while preserving intentional variations. This skill helps maintain consistency with the swimmer theme while allowing for project-specific customizations.

## Comparison Workflow

### 1. Initial Structure Comparison

First, compare the core Jekyll configuration:

- **Current project**: Has 52-line _config.yml with custom plugins and settings
- **Swimmer theme**: Has 43-line _config.yml with standard plugins only

Key differences to investigate:
- Custom plugins in current project (jekyll-last-modified-at)
- Additional exclude patterns in current project
- Custom author settings

### 2. Asset Analysis

Check for swimmer theme assets that may have been removed:

```bash
git diff HEAD~1 HEAD -- assets/
```

Common patterns to preserve:
- Custom logo/favicon files
- Theme-specific SVG assets
- Custom CSS overrides

### 3. Git-Based Comparison

When ambiguity exists, use git history to understand changes:

```bash
# Compare current branch to swimmer theme
# Look for intentional deviations from swimmer
```

### 4. Styles Comparison

Compare CSS implementations:

- **Swimmer theme**: Includes standard Tailwind colors (gray-500, red, pink, grape, etc.)
- **Current project**: Has custom color schemes and overrides

Preserve intentional design variations while maintaining theme structure.

## Decision Process

### When to Consult User

Ask the user for decisions on:

1. **Plugin conflicts**: Whether custom Jekyll plugins should be kept or replaced
2. **Design variations**: Which CSS customizations are intentional vs. accidental
3. **Asset management**: Whether removed swimmer assets should be restored
4. **Configuration differences**: Which _config.yml settings are project-specific

### Small Variations to Preserve

Always preserve these intentional variations:

- Custom site title and tagline
- Project-specific author information
- Repository-specific settings
- Custom build scripts (build_resume.py)
- Project-specific CSS overrides

## Commands for Comparison

```bash
# Compare current project structure to swimmer
find . -type f -name "*.md" -o -name "*.yml" -o -name "*.css" | sort

# Check git history for swimmer-related changes
git log --oneline --grep="swimmer"

# Compare _config.yml differences
cat _config.yml | diff -u ../swimmer/_config.yml

# Check for missing swimmer assets
ls -la assets/ | grep -E "(logo|icon|favicon)"
```

## Next Steps

1. Run initial comparison commands
2. Identify differences and variations
3. Consult user on judgement calls
4. Decide which swimmer elements to retain
5. Update project to maintain consistency while preserving variations

The goal is to create a balanced comparison that maintains swimmer theme structure while preserving the unique aspects of the current project.