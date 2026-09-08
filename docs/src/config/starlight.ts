import { docsSchema } from '@astrojs/starlight/schema';

export const starlightDocsSchema = docsSchema();

export const starlightSidebar = [
	{
		label: 'Guides',
		items: [{ autogenerate: { directory: 'guides' } }],
	},
	{
		label: 'Reference',
		items: [{ autogenerate: { directory: 'reference' } }],
	},
];
