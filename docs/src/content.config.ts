import { defineCollection } from 'astro:content';
import { docsLoader } from '@astrojs/starlight/loaders';
import { starlightDocsSchema } from './config/starlight';

export const collections = {
	docs: defineCollection({ loader: docsLoader(), schema: starlightDocsSchema }),
};
