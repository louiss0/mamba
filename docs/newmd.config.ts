import { defineConfig, z } from 'newmd';

export default defineConfig({
	// Output path relative to this config file
	path: './src/content/docs',

	// Frontmatter format
	format: 'yaml',

	// Schema definitions matching Starlight's docsSchema()
	// https://starlight.astro.build/reference/frontmatter/
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
});
