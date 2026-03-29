# Folder Level CLAUDE.md Guide

## Purpose
Document the purpose and contents of individual folders within the project.

## Contents for Each Folder

### Folder Purpose
- 2-3 sentence description of what the folder contains
- Why it exists in the codebase

### Key Files
- Brief list of main files and their purpose (1 line each)
- Only include files that are important to understand the folder

### Responsibilities
- What this folder is responsible for
- Key patterns or conventions used here

## Template

```markdown
# [Folder Name]

[2-3 sentence purpose description]

## Files
- `FileName.swift` — Brief description of responsibility

## Key Responsibilities
- [Responsibility 1]
- [Responsibility 2]
```

## Special Cases

### Asset Folders (Assets.xcassets)
- List main asset groups (icons, colors, images)
- Note any required sizes or formats

### Preview Content
- Note that this is for SwiftUI previews only
- List main preview files

### Build Artifacts/Generated
- Skip these folders entirely (build/, .build/, dist/, etc.)

## Length Guidelines
- 30-50 lines per folder
- Keep descriptions concise and specific
- Use active language: "manages", "provides", "handles" not "is a folder containing"
