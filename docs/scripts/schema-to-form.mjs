#!/usr/bin/env node

/**
 * Zod Schema → prompts Form Renderer
 * 
 * Dynamically generates CLI prompts from a Zod schema.
 * Usage: node schema-to-form.mjs <section> [--title "My Title"]
 * 
 * Arguments:
 *   section     Section name (guides, reference, etc.)
 *   --title    Pre-fill the title field
 *   --dry-run  Show frontmatter without creating file
 */

import prompts from 'prompts';
import { z } from 'astro/zod';
import { parseArgs } from 'node:util';

// ============================================
// CLI Arguments
// ============================================

const { values: args, positionals } = parseArgs({
  options: {
    title: { type: 'string', short: 't' },
    'dry-run': { type: 'boolean', default: false },
    help: { type: 'boolean', short: 'h', default: false },
  },
  allowPositionals: true,
});

const sectionArg = positionals[0];

if (args.help || !sectionArg) {
  console.log(`
📝 Doc Form Generator

Usage: node schema-to-form.mjs <section> [options]

Arguments:
  section    Section name (guides, reference, etc.)

Options:
  --title, -t <text>    Pre-fill the title field
  --dry-run             Show frontmatter without creating file
  --help, -h            Show this help message

Examples:
  node schema-to-form.mjs guides
  node schema-to-form.mjs reference --title "API Reference"
  node schema-to-form.mjs guides --dry-run
`);
  process.exit(0);
}

// ============================================
// Step 1: Define your schema (Starlight docs schema)
// ============================================

const DocSchema = z.object({
  // Part 1: Required fields
  title: z.string({ required_error: 'Title is required' }).min(1, 'Title cannot be empty'),
  description: z.string().optional(),
  
  // Part 2: Optional fields (categorized)
  sidebar: z.object({
    label: z.string().optional(),
    order: z.number().optional(),
    hidden: z.boolean().optional(),
  }).optional(),
  
  prev: z.union([
    z.boolean(),
    z.object({
      label: z.string(),
      link: z.string(),
    }),
  ]).optional(),
  
  next: z.union([
    z.boolean(),
    z.object({
      label: z.string(),
      link: z.string(),
    }),
  ]).optional(),
  
  template: z.enum(['doc', 'splash']).default('doc'),
  tableOfContents: z.boolean().default(true),
  pagefind: z.boolean().default(true),
  
  hero: z.object({
    title: z.string().optional(),
    tagline: z.string().optional(),
    image: z.object({
      file: z.string().optional(),
      alt: z.string().optional(),
    }).optional(),
    actions: z.array(z.object({
      text: z.string(),
      link: z.string(),
      icon: z.string().optional(),
      variant: z.enum(['primary', 'secondary', 'minimal', 'ghost']).optional(),
    })).optional(),
  }).optional(),
});

// ============================================
// Step 2: Schema helpers
// ============================================

function getZodType(schema) {
  if (schema instanceof z.ZodDefault) return 'default';
  if (schema instanceof z.ZodOptional) return 'optional';
  if (schema instanceof z.ZodString) return 'string';
  if (schema instanceof z.ZodNumber) return 'number';
  if (schema instanceof z.ZodBoolean) return 'boolean';
  if (schema instanceof z.ZodEnum) return 'enum';
  if (schema instanceof z.ZodObject) return 'object';
  if (schema instanceof z.ZodArray) return 'array';
  if (schema instanceof z.ZodUnion) return 'union';
  if (schema instanceof z.ZodEffects) return getZodType(schema._def.schema);
  return 'unknown';
}

function getPromptType(schema) {
  const type = getZodType(schema);
  switch (type) {
    case 'string': return 'text';
    case 'number': return 'number';
    case 'boolean': return 'confirm';
    case 'enum': return 'select';
    default: return 'text';
  }
}

function unwrapSchema(schema) {
  if (schema instanceof z.ZodOptional) {
    return { schema: schema._def.innerType, optional: true, defaultValue: undefined };
  }
  if (schema instanceof z.ZodDefault) {
    return { schema: schema._def.innerType, optional: false, defaultValue: schema._def.defaultValue };
  }
  return { schema, optional: false, defaultValue: undefined };
}

function getEnumValues(schema) {
  if (schema instanceof z.ZodEnum) {
    return schema.options || Object.values(schema.enum || {});
  }
  return null;
}

function getDefaultValue(schema) {
  if (schema instanceof z.ZodDefault) return schema._def.defaultValue;
  if (schema instanceof z.ZodOptional) return undefined;
  return undefined;
}

function formatMessage(name) {
  return name
    .replace(/([A-Z])/g, ' $1')
    .replace(/[_-]/g, ' ')
    .replace(/^./, str => str.toUpperCase());
}

function formatLabel(value) {
  return String(value)
    .replace(/[-_]/g, ' ')
    .replace(/\b\w/g, c => c.toUpperCase());
}

function schemaHasField(schema, fieldName) {
  return fieldName in schema.shape;
}

/**
 * Splits schema fields into required and optional groups.
 */
function splitRequiredOptional(schema) {
  const required = [];
  const optional = [];
  
  for (const [name, field] of Object.entries(schema.shape)) {
    const unwrapped = unwrapSchema(field);
    if (unwrapped.optional) {
      optional.push({ name, field, unwrapped });
    } else {
      // Check if it's a required field (no default)
      const defaultVal = getDefaultValue(field);
      if (defaultVal === undefined) {
        required.push({ name, field, unwrapped });
      } else {
        // Has default, treat as optional for UX
        optional.push({ name, field, unwrapped });
      }
    }
  }
  
  return { required, optional };
}

/**
 * Creates prompts for a single field.
 */
function fieldToPrompt(name, field) {
  const question = {
    name,
    type: null,
    message: formatMessage(name) + ':',
  };
  
  const unwrapped = unwrapSchema(field);
  const innerSchema = unwrapped.schema;
  const innerType = getZodType(innerSchema);
  
  if (innerType === 'object' || innerType === 'union' || innerType === 'array') {
    return null;
  }
  
  const defaultVal = getDefaultValue(field);
  if (defaultVal !== undefined) {
    question.initial = defaultVal;
  }
  
  if (innerType === 'enum') {
    question.type = 'select';
    const values = getEnumValues(innerSchema);
    question.choices = values.map(v => ({
      title: formatLabel(v),
      value: v,
    }));
  } else {
    question.type = getPromptType(innerSchema);
  }
  
  return question;
}

/**
 * Creates prompts for nested object fields.
 */
function nestedObjectToPrompts(schema, prefix = '') {
  const questions = [];
  
  // Unwrap if this is an optional or default wrapper
  let currentSchema = schema;
  while (currentSchema instanceof z.ZodOptional || currentSchema instanceof z.ZodDefault) {
    currentSchema = currentSchema._def.innerType;
  }
  
  for (const [name, field] of Object.entries(currentSchema.shape)) {
    const fullName = prefix ? `${prefix}.${name}` : name;
    
    const unwrapped = unwrapSchema(field);
    const innerSchema = unwrapped.schema;
    const innerType = getZodType(innerSchema);
    
    // Recurse into nested objects
    if (innerType === 'object') {
      questions.push(...nestedObjectToPrompts(innerSchema, fullName));
      continue;
    }
    
    // Skip arrays for now
    if (innerType === 'array') continue;
    
    const question = {
      name: fullName,
      type: null,
      message: formatMessage(fullName) + ':',
    };
    
    const defaultVal = unwrapped.defaultValue;
    if (defaultVal !== undefined) {
      question.initial = defaultVal;
    }
    
    if (innerType === 'enum') {
      question.type = 'select';
      const values = getEnumValues(innerSchema);
      question.choices = values.map(v => ({
        title: formatLabel(v),
        value: v,
      }));
    } else {
      question.type = getPromptType(innerSchema);
    }
    
    questions.push(question);
  }
  
  return questions;
}

// ============================================
// Part 2: Optional fields configuration
// ============================================

const OPTIONAL_FIELDS = [
  {
    key: 'sidebar',
    label: 'Sidebar',
    description: 'Configure sidebar label, order, and visibility',
  },
  {
    key: 'prev',
    label: 'Previous Link',
    description: 'Add a link to the previous page',
  },
  {
    key: 'next',
    label: 'Next Link',
    description: 'Add a link to the next page',
  },
  {
    key: 'template',
    label: 'Template',
    description: 'Choose page template (doc or splash)',
  },
  {
    key: 'tableOfContents',
    label: 'Table of Contents',
    description: 'Show/hide table of contents',
  },
  {
    key: 'pagefind',
    label: 'Pagefind',
    description: 'Enable/disable search indexing',
  },
  {
    key: 'hero',
    label: 'Hero Section',
    description: 'Add a hero banner with title and actions',
  },
];

// ============================================
// Step 3: Run the form
// ============================================

async function runForm() {
  console.log('\n📝 Create New Documentation Page\n');
  console.log(`Section: ${sectionArg}\n`);
  
  const { required, optional } = splitRequiredOptional(DocSchema);
  const answers = {};
  
  // ========== PART 1: Required Fields ==========
  console.log('─'.repeat(40));
  console.log('📋 Required Fields');
  console.log('─'.repeat(40) + '\n');
  
  const requiredPrompts = required
    .map(({ name, field }) => fieldToPrompt(name, field))
    .filter(Boolean);
  
  if (args.title) {
    const titleIdx = requiredPrompts.findIndex(q => q.name === 'title');
    if (titleIdx !== -1) {
      requiredPrompts[titleIdx].initial = args.title;
    }
  }
  
  const requiredAnswers = await prompts(requiredPrompts, {
    onCancel: () => {
      console.log('\n❌ Cancelled\n');
      process.exit(0);
    },
  });
  
  Object.assign(answers, requiredAnswers);
  
  // ========== PART 2: Optional Fields ==========
  console.log('\n' + '─'.repeat(40));
  console.log('⚙️  Optional Fields');
  console.log('─'.repeat(40) + '\n');
  
  // Ask which optional fields to configure
  const fieldChoices = OPTIONAL_FIELDS.map(f => ({
    title: f.label,
    description: f.description,
    value: f.key,
  }));
  
  const selectedFieldsResponse = await prompts({
    type: 'multiselect',
    name: 'selected',
    message: 'Which optional fields do you want to configure?',
    hint: '(Space to select, Enter to confirm)',
    optionsPerPage: 10,
    choices: fieldChoices,
  }, {
    onCancel: () => {
      console.log('\n❌ Cancelled\n');
      process.exit(0);
    },
  });
  
  const selectedFields = selectedFieldsResponse.selected || [];
  
  // Ask about each selected field
  for (const fieldKey of selectedFields) {
    console.log('\n' + '─'.repeat(40));
    const fieldDef = OPTIONAL_FIELDS.find(f => f.key === fieldKey);
    console.log(`⚙️  Configuring: ${fieldDef.label}`);
    console.log('─'.repeat(40) + '\n');
    
    if (fieldKey === 'sidebar') {
      const sidebarQuestions = nestedObjectToPrompts(DocSchema.shape.sidebar, 'sidebar');
      const sidebarAnswers = await prompts(sidebarQuestions, {
        onCancel: () => {
          console.log('\n❌ Cancelled\n');
          process.exit(0);
        },
      });
      answers.sidebar = sidebarAnswers;
      
    } else if (fieldKey === 'prev' || fieldKey === 'next') {
      const navAnswers = await prompts([
        {
          type: 'confirm',
          name: 'enabled',
          message: 'Enable previous link?',
          initial: true,
        },
        {
          type: 'text',
          name: 'label',
          message: 'Label:',
        },
        {
          type: 'text',
          name: 'link',
          message: 'Link:',
        },
      ], {
        onCancel: () => {
          console.log('\n❌ Cancelled\n');
          process.exit(0);
        },
      });
      
      if (navAnswers.enabled) {
        answers[fieldKey] = { label: navAnswers.label, link: navAnswers.link };
      } else {
        answers[fieldKey] = false;
      }
      
    } else if (fieldKey === 'hero') {
      const heroQuestions = nestedObjectToPrompts(DocSchema.shape.hero, 'hero');
      const heroAnswers = await prompts(heroQuestions, {
        onCancel: () => {
          console.log('\n❌ Cancelled\n');
          process.exit(0);
        },
      });
      answers.hero = heroAnswers;
      
    } else if (fieldKey === 'template') {
      const templateAnswer = await prompts({
        type: 'select',
        name: 'template',
        message: 'Template:',
        choices: [
          { title: 'Doc', description: 'Standard documentation page', value: 'doc' },
          { title: 'Splash', description: 'Landing page with hero', value: 'splash' },
        ],
      }, {
        onCancel: () => {
          console.log('\n❌ Cancelled\n');
          process.exit(0);
        },
      });
      answers.template = templateAnswer.template;
      
    } else {
      // Simple boolean fields (tableOfContents, pagefind)
      const field = DocSchema.shape[fieldKey];
      const prompt = fieldToPrompt(fieldKey, field);
      if (prompt) {
        const simpleAnswer = await prompts(prompt, {
          onCancel: () => {
            console.log('\n❌ Cancelled\n');
            process.exit(0);
          },
        });
        answers[fieldKey] = simpleAnswer[fieldKey];
      }
    }
  }
  
  return cleanObject(answers);
}

function cleanObject(obj) {
  return Object.fromEntries(
    Object.entries(obj)
      .filter(([_, v]) => v !== undefined && v !== '' && v !== null)
      .map(([k, v]) => [k, typeof v === 'object' && v !== null && !Array.isArray(v) ? cleanObject(v) : v])
  );
}

// ============================================
// Step 4: Output result
// ============================================

async function main() {
  try {
    const data = await runForm();
    
    // Generate filename
    const slug = data.title
      .toLowerCase()
      .replace(/[^a-z0-9\s-]/g, '')
      .replace(/\s+/g, '-')
      .replace(/-+/g, '-');
    
    // Generate frontmatter
    const frontmatter = generateFrontmatter(data);
    
    console.log('\n✅ Form submitted successfully!\n');
    console.log('📄 Generated frontmatter:\n');
    console.log(frontmatter);
    
    if (args['dry-run']) {
      console.log('💾 Dry run - no file created');
    } else {
      // TODO: Write file
      console.log(`💾 Save to: src/content/docs/${sectionArg}/${slug}.md`);
    }
    
  } catch (error) {
    console.error('Error:', error.message);
    process.exit(1);
  }
}

function generateFrontmatter(data) {
  let output = '---\n';
  output += `title: ${data.title}\n`;
  
  if (data.description) output += `description: ${data.description}\n`;
  
  if (data.template && data.template !== 'doc') output += `template: ${data.template}\n`;
  
  if (data.tableOfContents === false) output += `tableOfContents: false\n`;
  
  if (data.pagefind === false) output += `pagefind: false\n`;
  
  if (data.sidebar && Object.keys(data.sidebar).length > 0) {
    output += 'sidebar:\n';
    if (data.sidebar.label) output += `  label: ${data.sidebar.label}\n`;
    if (data.sidebar.order !== undefined) output += `  order: ${data.sidebar.order}\n`;
    if (data.sidebar.hidden) output += `  hidden: true\n`;
  }
  
  if (data.prev !== undefined) {
    if (typeof data.prev === 'boolean') {
      output += `prev: ${data.prev}\n`;
    } else {
      output += `prev:\n  label: ${data.prev.label}\n  link: ${data.prev.link}\n`;
    }
  }
  
  if (data.next !== undefined) {
    if (typeof data.next === 'boolean') {
      output += `next: ${data.next}\n`;
    } else {
      output += `next:\n  label: ${data.next.label}\n  link: ${data.next.link}\n`;
    }
  }
  
  if (data.hero && Object.keys(data.hero).length > 0) {
    output += 'hero:\n';
    if (data.hero.title) output += `  title: ${data.hero.title}\n`;
    if (data.hero.tagline) output += `  tagline: ${data.hero.tagline}\n`;
    if (data.hero.image && data.hero.image.file) {
      output += `  image:\n`;
      output += `    file: ${data.hero.image.file}\n`;
      if (data.hero.image.alt) output += `    alt: ${data.hero.image.alt}\n`;
    }
  }
  
  output += '---\n';
  return output;
}

main();
