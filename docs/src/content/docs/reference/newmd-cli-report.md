---
title: newmd CLI Report
description: Analysis of the newmd npm package for creating markdown files with frontmatter
---

# newmd CLI Analysis

A CLI tool for creating Markdown files with Zod-validated frontmatter, particularly suited for Astro Content Collections.

## Overview

**Repository:** [maxchang3/newmd](https://github.com/maxchang3/newmd)  
**Package:** `newmd` on npm  
**Runtime:** Node.js with TypeScript  
**CLI Framework:** [clipanion](https://mael.dev/clipanion/)

## Architecture

```
src/
├── cli.ts              # Entry point, registers commands
├── commands/
│   ├── create.ts       # Main create command
│   └── index.ts        # Command exports
├── consts.ts          # Constants (version, defaults)
├── types.ts           # TypeScript interfaces (Config, schema types)
├── log.ts             # Styled logging utilities
└── utils/
    ├── config.ts      # Config file loading (unconfig)
    ├── frontmatter.ts # Zod schema → YAML/TOML conversion
    └── fs.ts          # File system operations
```

## Commands

### `create` (default/only command)

```bash
newmd <schemaName> <title>
```

Creates a markdown file with frontmatter generated from a Zod schema.

**Arguments:**
| Argument | Type | Required | Description |
|----------|------|----------|-------------|
| `schemaName` | string | Yes | Name of the schema from `newmd.config.ts` |
| `title` | string | Yes | Title for the file (mapped to schema field) |

**Options:**

| Flag | Type | Default | Description |
|------|------|---------|-------------|
| `--content` | string | - | Custom content body after frontmatter |
| `--path` | string | config path | Output directory |
| `--slug` | string | auto-generated | Filename slug (defaults to slugified title) |
| `--toml` | boolean | false | Use TOML frontmatter instead of YAML |
| `--overwrite` | boolean | false | Overwrite existing files |
| `--cwd` | string | - | Working directory for config lookup |

## Config File (`newmd.config.ts`)

Located in project root, loaded via `unconfig`.

```typescript
import { defineConfig, z } from 'newmd';

export default defineConfig({
  // Frontmatter format: 'yaml' | 'toml'
  format: 'yaml',

  // Output path for markdown files
  // String: same path for all schemas
  // Object: schema-specific paths
  path: './src/content/docs',
  // path: { guide: './guides', reference: './reference' }

  // Zod schemas for each content type
  schemas: {
    guide: z.object({
      title: z.string(),
      description: z.string().optional(),
    }),
    reference: z.object({
      title: z.string(),
      description: z.string().optional(),
    }),
  },

  // Map title argument to different schema field
  // String: same field for all schemas
  // Object: per-schema field mapping
  titleMapping: 'title',
  // titleMapping: { guide: 'title', reference: 'name' }
});
```

## Workflow

1. **Load config** from `newmd.config.[ts|js|mjs]` in cwd
2. **Validate schema** exists in config
3. **Generate defaults** from Zod schema using `zod-empty`
4. **Map title** to configured field
5. **Write file** with frontmatter + optional content

## Key Dependencies

| Package | Purpose |
|---------|---------|
| `clipanion` | CLI framework with type-safe options/args |
| `zod` | Schema validation |
| `zod-empty` | Generate empty values from Zod schemas |
| `js-yaml` | YAML serialization |
| `smol-toml` | TOML serialization |
| `github-slugger` | URL-friendly slug generation |
| `unconfig` | Config file loading (ts, mjs, js) |
| `deepmerge-ts` | Deep object merging |

## Frontmatter Generation

Uses `zod-empty` to create empty default values from Zod schemas:

```typescript
// Input Zod schema
z.object({
  title: z.string(),
  description: z.string().optional(),
})

// Output frontmatter
---
title: User Provided Title
description: ''
---
```

### Limitations

- `zod-empty` doesn't support all Zod features (e.g., `z.coerce.date()`)
- Complex nested objects generate many empty fields
- No `--field` option for one-off custom fields

## Example Usage

```bash
# Create with default path
newmd guide "Getting Started"

# Override output path
newmd guide "FAQ" --path ./guides/faq

# Custom slug for filename
newmd guide "API Reference" --slug api

# TOML frontmatter
newmd guide "Config" --toml

# Overwrite existing
newmd guide "Getting Started" --overwrite

# Custom content body
newmd guide "Intro" --content "# Welcome\n\nThis is the content."
```

## Integration with Astro

newmd pairs well with Astro Content Collections:

```typescript
// newmd.config.ts mirrors content.config.ts
import { docsSchema } from '@astrojs/starlight/schema';

// Content config
const docs = defineCollection({
  loader: glob({ pattern: '**/*.md', base: './src/content/docs' }),
  schema: docsSchema(),
});

// newmd config (simplified)
export default defineConfig({
  path: './src/content/docs',
  schemas: {
    docs: z.object({
      title: z.string(),
      description: z.string().optional(),
    }),
  },
});
```

## Comparison: newmd vs Custom Dart CLI

| Aspect | newmd | Custom Dart CLI |
|--------|-------|-----------------|
| Language | TypeScript/Node | Dart |
| Schema validation | Built-in Zod | Manual/external |
| Config format | TS config file | Dart code |
| Field customization | Edit config | Edit source |
| Dependencies | npm ecosystem | Dart ecosystem |
| Extensibility | Plugin-based | Full control |

## Recommendations for Custom Implementation

If building a Dart equivalent:

1. **Use args_library** for CLI argument parsing (Dart stdlib)
2. **Store config** as Dart classes, not external file
3. **Generate frontmatter** with yaml package
4. **Slug generation** via `Inflection` or custom function
5. **File writing** via dart:io

A custom Dart CLI would integrate better with the existing Mamba project and avoid npm dependency conflicts.
