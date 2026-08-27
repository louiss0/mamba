// @ts-check
import { defineConfig } from 'astro/config';
import starlight from '@astrojs/starlight';

const siteUrl = process.env.PUBLIC_SITE_URL;

// https://astro.build/config
export default defineConfig({
	site: siteUrl,
	integrations: [
		starlight({
			title: 'Mamba',
			description: 'A list-defined Dart framework for command-line applications.',
			logo: {
				src: './src/assets/Mamba-Small-Logo.png',
				alt: 'Mamba',
				replacesTitle: true,
			},
			favicon: '/mamba-small-logo.png',
			customCss: ['./src/styles/mamba.css'],
			social: [{ icon: 'github', label: 'GitHub', href: 'https://github.com/louiss0/mamba' }],
			sidebar: [
				{
					label: 'Guides',
					items: [
						{ label: 'Example Guide', slug: 'guides/example' },
					],
				},
				{
					label: 'Reference',
					items: [{ autogenerate: { directory: 'reference' } }],
				},
			],
		}),
	],
});
