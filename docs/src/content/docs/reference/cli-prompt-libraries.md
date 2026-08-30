---
title: CLI Prompt Libraries for Forms
description: Comparison of JavaScript libraries for building interactive CLI forms
---

# CLI Prompt Libraries for Forms

## Overview

| Library | npm Downloads | Stars | Form Support | Best For |
|---------|---------------|-------|--------------|----------|
| **@inquirer/prompts** | ~2M/week | - | Manual chaining | Modern, modular prompts |
| **@clack/prompts** | ~800K/week | - | Manual chaining | Polished wizard-style CLIs |
| **enquirer** | ~4M/week | 8.2k | Built-in `Form` prompt | Multi-field forms |
| **prompts** | ~3M/week | 6.5k | Manual chaining | Simple, async API |

## 1. @inquirer/prompts

Modern, modular rewrite of Inquirer with tree-shaking support.

**Install:**
```bash
npm install @inquirer/prompts
```

**Example:**
```javascript
import { input, select, confirm } from '@inquirer/prompts';

const name = await input({ message: 'What is your name?' });
const color = await select({
  message: 'Choose a color:',
  choices: [
    { name: 'red', value: '#ff0000' },
    { name: 'green', value: '#00ff00' },
    { name: 'blue', value: '#0000ff' },
  ],
});
const isReady = await confirm({ message: 'Ready to proceed?' });
```

**Features:**
- `input()` — text input with validation
- `select()` — dropdown selection
- `confirm()` — yes/no prompt
- `password()` — hidden input
- `editor()` — launch external editor
- Validation support
- Default values
- Custom styling

**Limitations:**
- No built-in multi-field form
- Chain prompts manually

---

## 2. @clack/prompts

Polished CLI prompts with intro/outro framing, great for project generators.

**Install:**
```bash
npm install @clack/prompts
```

**Example:**
```javascript
import { intro, outro, text, select, confirm, isCancel } from '@clack/prompts';

intro('Create New Doc');

const name = await text({
  message: 'What is the doc title?',
  placeholder: 'My Guide',
  validate: (value) => value.length === 0 ? 'Title required' : true,
});

const section = await select({
  message: 'Choose section:',
  options: [
    { value: 'guides', label: 'Guides' },
    { value: 'reference', label: 'Reference' },
  ],
});

if (isCancel(section)) {
  cancel('Operation cancelled');
  process.exit(0);
}

outro('Doc created successfully!');
```

**Features:**
- `intro()` / `outro()` — session framing
- `text()` — input with validation
- `select()` — dropdown
- `confirm()` — yes/no
- `spinner()` — loading indicator
- `isCancel()` — handle Ctrl+C
- `cancel()` — styled cancellation
- ANSI color support

**Limitations:**
- No built-in multi-field form
- Slightly more verbose than others

---

## 3. enquirer

Feature-rich library with a built-in `Form` prompt for multi-field inputs.

**Install:**
```bash
npm install enquirer
```

**Example (Form):**
```javascript
const { Form } = require('enquirer');

const prompt = new Form({
  name: 'doc',
  message: 'Enter document details:',
  choices: [
    { name: 'title', message: 'Title', initial: 'Getting Started' },
    { name: 'description', message: 'Description' },
    { name: 'section', message: 'Section', initial: 'guides' },
  ],
});

const answers = await prompt.run();
// { title: 'Getting Started', description: '...', section: 'guides' }
```

**Example (Survey):**
```javascript
const { prompt } = require('enquirer');

const answers = await prompt([
  { type: 'input', name: 'title', message: 'Title:' },
  { type: 'select', name: 'section', message: 'Section:', choices: ['guides', 'reference'] },
  { type: 'confirm', name: 'draft', message: 'Is this a draft?' },
]);
```

**Built-in Prompts:**
- `Input` / `Text` — text input
- `Password` — hidden input
- `Select` — dropdown
- `MultiSelect` — multiple selection
- `Confirm` — yes/no
- `Survey` — multiple questions
- `Form` — multi-field form
- `Autocomplete` — searchable dropdown
- `Number` / `Numeral` — numeric input
- `Scale` — rating scale
- `Snippet` — template filling
- `Sort` — reorderable list

**Features:**
- Async/await API
- Validation
- Default values
- Custom styling/symbols
- History/autocomplete
- Keypress events
- Plugin system

**Limitations:**
- Larger bundle (one dependency)
- Form prompt lacks field validation (as of docs)

---

## 4. prompts

Minimal, async-friendly library with simple API.

**Install:**
```bash
npm install prompts
```

**Example:**
```javascript
import prompts from 'prompts';

const response = await prompts([
  {
    type: 'text',
    name: 'title',
    message: 'Title:',
  },
  {
    type: 'select',
    name: 'section',
    message: 'Section:',
    choices: ['guides', 'reference'],
  },
  {
    type: 'confirm',
    name: 'continue',
    message: 'Continue?',
  },
]);
```

**Features:**
- `text` — text input
- `password` — hidden input
- `number` — numeric input
- `confirm` — yes/no
- `select` — single selection
- `multiselect` — multiple selection
- `toggle` — on/off
- `date` — date picker
- Conditional prompts
- Dynamic choices
- Validation

**Limitations:**
- No built-in multi-field form
- Less customizable styling

---

## Comparison: Form Support

| Feature | enquirer | @inquirer | @clack | prompts |
|---------|----------|-----------|--------|---------|
| Built-in Form | ✅ `Form` | ❌ | ❌ | ❌ |
| Multi-field | ✅ `Survey` | Manual | Manual | Manual |
| Field validation | Limited | ✅ | ✅ | ✅ |
| Default values | ✅ | ✅ | ❌ | ✅ |
| Conditional fields | ✅ | Manual | Manual | ✅ |

---

## Recommendations

### For Multi-Field Forms → **enquirer**
```javascript
const { Form } = require('enquirer');
// Best native form support
```

### For Modern/Modular → **@inquirer/prompts**
```javascript
import { input, select, confirm } from '@inquirer/prompts';
// Tree-shakeable, TypeScript-friendly
```

### For Polished Wizards → **@clack/prompts**
```javascript
import { intro, outro, text, select } from '@clack/prompts';
// Best for project generators
```

### For Simplicity → **prompts**
```javascript
import prompts from 'prompts';
// Minimal, async-friendly
```

---

## Using with Dart

If the CLI is called from Dart via `Process.run`:

```dart
// Dart side
final result = await Process.run('node', ['cli.js', '--interactive']);
```

```javascript
// cli.js - use prompts and output structured JSON
const { Form } = require('enquirer');
const answers = await promptForm();
console.log(JSON.stringify(answers));
```

Or pass arguments directly:

```dart
// Dart side
final result = await Process.run('node', ['cli.js', '--title', 'My Doc', '--section', 'guides']);
```

---

## Integration with newmd

Combine prompt library with newmd for interactive doc creation:

```javascript
// scripts/create-doc.js
import { Form } from 'enquirer';
import { writeFile } from 'fs/promises';
import { join } from 'path';
import { execSync } from 'child_process';

async function createDoc() {
  const answers = await new Form({
    name: 'doc',
    message: 'Document details:',
    choices: [
      { name: 'title', message: 'Title', initial: '' },
      { name: 'description', message: 'Description' },
      { name: 'section', message: 'Section', initial: 'guides' },
    ],
  }).run();

  // Generate frontmatter
  const frontmatter = `---
title: ${answers.title}
description: ${answers.description}
---\n`;

  // Write file
  const slug = answers.title.toLowerCase().replace(/\s+/g, '-');
  const path = join('src/content/docs', answers.section, `${slug}.md`);
  await writeFile(path, frontmatter);

  console.log(`Created: ${path}`);
}

createDoc();
```

Run with:
```bash
node scripts/create-doc.js
```
