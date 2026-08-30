#!/usr/bin/env node

/**
 * Zod Schema → prompts Form Renderer
 * 
 * Dynamically generates CLI prompts from a Zod schema.
 * Supports: string, number, boolean, enum, optional fields.
 */

import prompts from 'prompts';
import { z } from 'zod';

// ============================================
// Step 1: Define your schema
// ============================================

const DocSchema = z.object({
  title: z.string({
    required_error: 'Title is required',
  }).min(1, 'Title cannot be empty'),
  
  description: z.string().optional(),
  
  section: z.enum(['guides', 'reference'], {
    errorMap: () => ({ message: 'Section must be "guides" or "reference"' }),
  }),
  
  slug: z.string()
    .regex(/^[a-z0-9-]+$/, 'Slug must be lowercase with hyphens')
    .optional(),
  
  draft: z.boolean().default(false),
  
  order: z.number().min(0).optional(),
});

// DocForm type (for reference): z.infer<typeof DocSchema>

// Export for testing
export { schemaToPrompts, getZodType, unwrapSchema, formatMessage };

// ============================================
// Step 2: Schema → prompts converter
// ============================================

/**
 * Get the type name of a Zod schema.
 */
function getZodType(schema) {
  if (schema instanceof z.ZodDefault) return 'default';
  if (schema instanceof z.ZodOptional) return 'optional';
  if (schema instanceof z.ZodString) return 'string';
  if (schema instanceof z.ZodNumber) return 'number';
  if (schema instanceof z.ZodBoolean) return 'boolean';
  if (schema instanceof z.ZodEnum) return 'enum';
  if (schema instanceof z.ZodEffects) return getZodType(schema._def.schema);
  return 'unknown';
}

/**
 * Get the prompts type for a Zod type.
 */
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

/**
 * Extract the inner schema from optional/default wrappers.
 */
function unwrapSchema(schema) {
  if (schema instanceof z.ZodOptional) {
    return { schema: schema._def.innerType, optional: true, defaultValue: undefined };
  }
  if (schema instanceof z.ZodDefault) {
    return { schema: schema._def.innerType, optional: false, defaultValue: schema._def.defaultValue };
  }
  return { schema, optional: false, defaultValue: undefined };
}

/**
 * Get enum values from a schema.
 */
function getEnumValues(schema) {
  if (schema instanceof z.ZodEnum) {
    // Zod 4: values in options or enum property
    return schema.options || Object.values(schema.enum || {});
  }
  return null;
}

/**
 * Get default value from a schema.
 */
function getDefaultValue(schema) {
  if (schema instanceof z.ZodDefault) {
    return schema._def.defaultValue;
  }
  if (schema instanceof z.ZodOptional) {
    return undefined;
  }
  return undefined;
}

/**
 * Format field name into human-readable message.
 */
function formatMessage(name) {
  return name
    .replace(/([A-Z])/g, ' $1')
    .replace(/[_-]/g, ' ')
    .replace(/^./, str => str.toUpperCase())
    + ':';
}

/**
 * Format enum value into title-case label.
 */
function formatLabel(value) {
  return String(value)
    .replace(/[-_]/g, ' ')
    .replace(/\b\w/g, c => c.toUpperCase());
}

/**
 * Converts a Zod schema into an array of prompts questions.
 */
function schemaToPrompts(schema) {
  const questions = [];
  
  for (const [name, field] of Object.entries(schema.shape)) {
    const question = {
      name,
      type: null,
      message: formatMessage(name),
    };
    
    const unwrapped = unwrapSchema(field);
    const innerSchema = unwrapped.schema;
    const innerType = getZodType(innerSchema);
    
    // Get default value
    const defaultVal = getDefaultValue(field);
    if (defaultVal !== undefined) {
      question.initial = defaultVal;
    }
    
    // Determine prompt type
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
// Step 3: Run the form
// ============================================

async function runForm() {
  console.log('\n📝 Create New Documentation Page\n');
  
  // Convert schema to prompts
  const questions = schemaToPrompts(DocSchema);
  
  // Add custom validation for slug based on title
  const slugIndex = questions.findIndex(q => q.name === 'slug');
  if (slugIndex !== -1) {
    questions[slugIndex].validate = (value) => {
      if (!value) return true; // Optional
      if (!/^[a-z0-9-]+$/.test(value)) {
        return 'Slug must be lowercase with hyphens only';
      }
      return true;
    };
  }
  
  // Show prompts
  const answers = await prompts(questions, {
    onCancel: () => {
      console.log('\n❌ Cancelled\n');
      process.exit(0);
    },
  });
  
  // Auto-generate slug from title if not provided
  if (answers.slug === '' && answers.title) {
    answers.slug = answers.title
      .toLowerCase()
      .replace(/[^a-z0-9\s-]/g, '')
      .replace(/\s+/g, '-')
      .replace(/-+/g, '-');
  }
  
  // Validate with Zod
  const result = DocSchema.safeParse(answers);
  
  if (!result.success) {
    console.error('\n❌ Validation failed:');
    for (const issue of result.error.issues) {
      console.error(`  - ${issue.message} (${issue.path.join('.')})`);
    }
    process.exit(1);
  }
  
  return result.data;
}

// ============================================
// Step 4: Output result
// ============================================

async function main() {
  try {
    const data = await runForm();
    
    console.log('\n✅ Form submitted successfully!\n');
    console.log('Data:', JSON.stringify(data, null, 2));
    
    // Generate frontmatter
    const frontmatter = `---\ntitle: ${data.title}\n` +
      (data.description ? `description: ${data.description}\n` : '') +
      `section: ${data.section}\n` +
      (data.slug ? `slug: ${data.slug}\n` : '') +
      (data.draft !== undefined ? `draft: ${data.draft}\n` : '') +
      `---\n`;
    
    console.log('\n📄 Generated frontmatter:\n');
    console.log(frontmatter);
    
    const filename = `${data.slug || data.title.toLowerCase().replace(/\s+/g, '-')}.md`;
    console.log(`💾 Save to: src/content/docs/${data.section}/${filename}`);
    
  } catch (error) {
    console.error('Error:', error.message);
    process.exit(1);
  }
}

main();
