import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { mkdtemp, readFile, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { PassThrough } from 'node:stream';
import { describe, it } from 'node:test';
import { fileURLToPath } from 'node:url';
import { promptForDirectory } from './new-doc';

const docsDirectory = new URL('../', import.meta.url);
const starlightDocsDirectory = fileURLToPath(
	new URL('../src/content/docs/', import.meta.url),
);

function runNewDoc(arguments_: string[]) {
	return spawnSync(
		process.execPath,
		['--import', 'tsx', 'scripts/new-doc.ts', ...arguments_],
		{
			cwd: docsDirectory,
			encoding: 'utf8',
		},
	);
}

describe('new-doc', () => {
	it('shows command help without loading the Astro project', () => {
		const result = runNewDoc(['--help']);

		assert.equal(result.status, 0);
		assert.match(result.stdout, /Create a Starlight Markdown page/);
		assert.match(result.stdout, /new-doc <title> <description> \[frontmatter-json\]/);
		assert.match(result.stdout, /--directory/);
		assert.match(result.stdout, /--dry-run/);
		assert.equal(result.stderr, '');
	});

	it('rejects malformed frontmatter JSON without prompting', () => {
		const result = runNewDoc(['Invalid JSON', 'A description', '{']);

		assert.equal(result.status, 64);
		assert.match(result.stderr, /invalid frontmatter JSON/i);
		assert.equal(result.stdout, '');
	});

	it('rejects JSON values that are not objects', () => {
		const result = runNewDoc(['Invalid JSON Shape', 'A description', '[]']);

		assert.equal(result.status, 64);
		assert.match(result.stderr, /frontmatter JSON must be an object/i);
		assert.equal(result.stdout, '');
	});

	it('requires a non-empty title', () => {
		const result = runNewDoc(['   ', 'A description', '{}', '--directory', 'guides']);

		assert.equal(result.status, 64);
		assert.match(result.stderr, /title must be non-empty/i);
		assert.equal(result.stdout, '');
	});

	it('rejects a title that cannot produce a filename', () => {
		const result = runNewDoc(['🚀✨', 'A description', '{}', '--directory', 'guides']);

		assert.equal(result.status, 64);
		assert.match(result.stderr, /title must contain a letter or number/i);
		assert.equal(result.stdout, '');
	});

	it('requires a non-empty description', () => {
		const result = runNewDoc(['A Title', '   ', '{}', '--directory', 'guides']);

		assert.equal(result.status, 64);
		assert.match(result.stderr, /description must be non-empty/i);
		assert.equal(result.stdout, '');
	});

	it('rejects more than three positional arguments', () => {
		const result = runNewDoc(['A Title', 'A description', '{}', 'unexpected']);

		assert.equal(result.status, 64);
		assert.match(result.stderr, /unexpected positional argument/i);
		assert.equal(result.stdout, '');
	});

	it('rejects frontmatter that does not satisfy the Starlight schema', () => {
		const result = runNewDoc([
			'Invalid Frontmatter',
			'A description',
			JSON.stringify({ template: 'wide' }),
		]);

		assert.equal(result.status, 64);
		assert.match(result.stderr, /invalid frontmatter/i);
		assert.match(result.stderr, /template/i);
		assert.equal(result.stdout, '');
	});

	it('rejects title and description overrides in frontmatter JSON', () => {
		const result = runNewDoc([
			'Original Title',
			'Original description',
			JSON.stringify({ title: 'Override' }),
			'--directory',
			'guides',
			'--dry-run',
		]);

		assert.equal(result.status, 64);
		assert.match(result.stderr, /must not include title or description/i);
		assert.equal(result.stdout, '');
	});

	it('rejects unknown fields at any frontmatter depth', () => {
		const result = runNewDoc([
			'Unknown Frontmatter',
			'A description',
			JSON.stringify({ sidebar: { unsupported: true } }),
			'--directory',
			'guides',
			'--dry-run',
		]);

		assert.equal(result.status, 64);
		assert.match(result.stderr, /unknown frontmatter field/i);
		assert.match(result.stderr, /sidebar\.unsupported/i);
		assert.equal(result.stdout, '');
	});

	it('accepts an ISO-8601 string for lastUpdated', () => {
		const result = runNewDoc([
			'Dated Page',
			'A description',
			JSON.stringify({ lastUpdated: '2026-09-03' }),
			'--directory',
			'guides',
			'--dry-run',
		]);

		assert.equal(result.status, 0, result.stderr);
		assert.match(result.stdout, /lastUpdated: 2026-09-03T00:00:00\.000Z/);
	});

	it('rejects an impossible ISO-8601 calendar date', () => {
		const result = runNewDoc([
			'Invalid Date',
			'A description',
			JSON.stringify({ lastUpdated: '2026-02-30' }),
		]);

		assert.equal(result.status, 64);
		assert.match(result.stderr, /lastUpdated must be a valid ISO-8601 date/i);
		assert.equal(result.stdout, '');
	});

	it('refuses to overwrite an existing generated path', () => {
		const result = runNewDoc([
			'Getting Started',
			'A replacement description',
			'{}',
			'--directory',
			'guides',
		]);

		assert.equal(result.status, 1);
		assert.match(result.stderr, /already exists/i);
		assert.match(result.stderr, /getting-started\.md/i);
		assert.equal(result.stdout, '');
	});

	it('rejects a directory that escapes the Starlight docs collection', () => {
		const result = runNewDoc([
			'Escaping Page',
			'A description',
			'{}',
			'--directory',
			'../outside',
		]);

		assert.equal(result.status, 64);
		assert.match(result.stderr, /directory must be relative/i);
		assert.equal(result.stdout, '');
	});

	it('rejects a top-level directory not covered by the Starlight sidebar', () => {
		const result = runNewDoc([
			'Uncovered Page',
			'A description',
			'{}',
			'--directory',
			'tutorials',
		]);

		assert.equal(result.status, 64);
		assert.match(result.stderr, /nested beneath a sidebar directory/i);
		assert.match(result.stderr, /guides, reference/i);
		assert.equal(result.stdout, '');
	});

	it('prompts for a covered directory and prefers guides', async () => {
		const input = new PassThrough();
		const output = new PassThrough();
		let renderedPrompt = '';
		output.on('data', (chunk) => {
			renderedPrompt += chunk.toString();
		});

		const selectedDirectory = promptForDirectory(starlightDocsDirectory, {
			input,
			output,
		});
		setTimeout(() => input.write('\r'), 25);

		assert.equal(await selectedDirectory, 'guides');
		assert.match(renderedPrompt, /guides/i);
		input.destroy();
		output.destroy();
	});

	it('accepts a new nested directory from the prompt', async () => {
		const emptyDocsDirectory = await mkdtemp(join(tmpdir(), 'new-doc-prompt-'));
		const input = new PassThrough();
		const output = new PassThrough();

		try {
			const selectedDirectory = promptForDirectory(emptyDocsDirectory, {
				input,
				output,
			});
			setTimeout(() => input.write('\u001b[B\r'), 25);
			setTimeout(() => input.write('guides/advanced\r'), 75);

			assert.equal(await selectedDirectory, 'guides/advanced');
		} finally {
			input.destroy();
			output.destroy();
			await rm(emptyDocsDirectory, { recursive: true, force: true });
		}
	});

	it('creates a new nested directory when JSON is omitted', async () => {
		const targetDirectory = fileURLToPath(
			new URL('../src/content/docs/guides/generated-test-section/', import.meta.url),
		);
		const targetPath = join(targetDirectory, 'nested-page.md');

		try {
			const result = runNewDoc([
				'Nested Page',
				'A page in a new nested directory.',
				'--directory',
				'guides/generated-test-section',
			]);

			assert.equal(result.status, 0, result.stderr);
			assert.equal(
				await readFile(targetPath, 'utf8'),
				`---
title: Nested Page
description: A page in a new nested directory.
---

`,
			);
		} finally {
			await rm(targetDirectory, { recursive: true, force: true });
		}
	});

	it('creates a Markdown page with canonical Starlight frontmatter', async () => {
		const title = 'Generated Déjà 日本語 Page';
		const targetPath = fileURLToPath(
			new URL(
				'../src/content/docs/guides/generated-deja-日本語-page.md',
				import.meta.url,
			),
		);
		const metadata = {
			draft: true,
			sidebar: { order: 7 },
			hero: {
				actions: [{ link: '/start', text: 'Start' }],
				title: 'Hero title',
			},
			template: 'splash',
		};

		const expectedMarkdown = `---
title: Generated Déjà 日本語 Page
description: A generated Starlight page.
template: splash
hero:
  title: Hero title
  actions:
    - text: Start
      link: /start
sidebar:
  order: 7
draft: true
---

`;

		try {
			const result = runNewDoc([
				title,
				'A generated Starlight page.',
				JSON.stringify(metadata),
				'--directory',
				'guides',
			]);

			assert.equal(result.status, 0, result.stderr);
			assert.match(result.stdout, /Created:.*generated-deja-日本語-page\.md/i);
			assert.equal(await readFile(targetPath, 'utf8'), expectedMarkdown);
		} finally {
			await rm(targetPath, { force: true });
		}
	});

	it('prints exact Markdown without writing during a dry run', async () => {
		const targetPath = fileURLToPath(
			new URL('../src/content/docs/guides/dry-run-page.md', import.meta.url),
		);

		const expectedMarkdown = `---
title: Dry Run Page
description: Preview this page.
sidebar:
  order: 3
---

`;

		try {
			const result = runNewDoc([
				'Dry Run Page',
				'Preview this page.',
				JSON.stringify({ sidebar: { order: 3 } }),
				'--directory',
				'guides',
				'--dry-run',
			]);

			assert.equal(result.status, 0, result.stderr);
			assert.equal(result.stdout, expectedMarkdown);
			assert.match(result.stderr, /Would create:.*dry-run-page\.md/i);
			await assert.rejects(readFile(targetPath, 'utf8'), { code: 'ENOENT' });
		} finally {
			await rm(targetPath, { force: true });
		}
	});
});
