#!/usr/bin/env node

import { access, mkdir, readdir, realpath, writeFile } from 'node:fs/promises';
import { dirname, isAbsolute, join, parse, relative, resolve } from 'node:path';
import type { Readable, Writable } from 'node:stream';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { parseArgs } from 'node:util';
import { cancel, isCancel, select, text } from '@clack/prompts';
import type { SchemaContext } from 'astro:content';
import { z } from 'astro/zod';
import { dump as dumpYaml } from 'js-yaml';
import { starlightDocsSchema, starlightSidebar } from '../src/config/starlight';

const usageExitCode = 64;
const astroConfigNames = [
	'astro.config.mjs',
	'astro.config.js',
	'astro.config.ts',
	'astro.config.mts',
];
const help = `Create a Starlight Markdown page.

Usage
  pnpm new-doc <title> <description> [frontmatter-json] [options]

Options
  --directory <path>  Skip the directory prompt with a docs-relative path.
  --dry-run           Print the Markdown without writing a file.
  --help, -h          Show this help message.

Examples
  pnpm new-doc "Getting Started" "Learn how to get started."
  pnpm new-doc "Commands" "Command reference." '{"sidebar":{"order":2}}' --directory reference
`;

function reportError(message: string, exitCode: number) {
	process.stderr.write(`Error: ${message}\n`);
	process.exitCode = exitCode;
}

function reportUsageError(message: string) {
	reportError(message, usageExitCode);
}

function parseFrontmatter(value: string | undefined) {
	if (value === undefined) return {};

	try {
		const frontmatter: unknown = JSON.parse(value);
		if (frontmatter === null || typeof frontmatter !== 'object' || Array.isArray(frontmatter)) {
			reportUsageError('frontmatter JSON must be an object');
			return undefined;
		}
		return frontmatter as Record<string, unknown>;
	} catch {
		reportUsageError('invalid frontmatter JSON; provide a JSON object as the third argument');
		return undefined;
	}
}

function getUnknownFieldPaths(
	value: unknown,
	validatedValue: unknown,
	path: Array<string | number> = [],
): string[] {
	if (Array.isArray(value) && Array.isArray(validatedValue)) {
		return value.flatMap((item, index) =>
			getUnknownFieldPaths(item, validatedValue[index], [...path, index]),
		);
	}
	if (
		value === null ||
		typeof value !== 'object' ||
		value instanceof Date ||
		validatedValue === null ||
		typeof validatedValue !== 'object' ||
		Array.isArray(validatedValue)
	) {
		return [];
	}

	const validatedValuesByName = validatedValue as Record<string, unknown>;
	return Object.entries(value).flatMap(([name, childValue]) => {
		const childPath = [...path, name];
		if (!(name in validatedValuesByName)) return [childPath.join('.')];
		return getUnknownFieldPaths(childValue, validatedValuesByName[name], childPath);
	});
}

async function getValidatedFrontmatter(frontmatter: unknown) {
	const image = (() => z.string()) as unknown as SchemaContext['image'];
	const schema = starlightDocsSchema({ image });
	const result = await schema.safeParseAsync(frontmatter);
	if (result.success) {
		const unknownFieldPaths = getUnknownFieldPaths(frontmatter, result.data);
		if (unknownFieldPaths.length === 0) return result.data;

		reportUsageError(`unknown frontmatter field: ${unknownFieldPaths.join(', ')}`);
		return undefined;
	}

	const issues = result.error.issues
		.map((issue) => `${issue.path.join('.') || 'frontmatter'}: ${issue.message}`)
		.join('; ');
	reportUsageError(`invalid frontmatter: ${issues}`);
	return undefined;
}

function getCanonicalValue(value: unknown, validatedValue: unknown): unknown {
	if (Array.isArray(value) && Array.isArray(validatedValue)) {
		return value.map((item, index) => getCanonicalValue(item, validatedValue[index]));
	}
	if (
		value === null ||
		typeof value !== 'object' ||
		value instanceof Date ||
		validatedValue === null ||
		typeof validatedValue !== 'object' ||
		Array.isArray(validatedValue)
	) {
		return value;
	}

	const valuesByName = value as Record<string, unknown>;
	const validatedValuesByName = validatedValue as Record<string, unknown>;
	const canonicalNames = Object.keys(validatedValuesByName).filter((name) => name in valuesByName);
	const additionalNames = Object.keys(valuesByName).filter(
		(name) => !(name in validatedValuesByName),
	);
	return Object.fromEntries(
		[...canonicalNames, ...additionalNames].map((name) => [
			name,
			getCanonicalValue(valuesByName[name], validatedValuesByName[name]),
		]),
	);
}

function getMarkdown(frontmatter: unknown) {
	const serializedFrontmatter = dumpYaml(frontmatter, {
		lineWidth: -1,
		noRefs: true,
	});
	return `---\n${serializedFrontmatter}---\n\n`;
}

function getFrontmatterWithDates(frontmatter: Record<string, unknown>) {
	if (typeof frontmatter.lastUpdated !== 'string') return frontmatter;

	const isoDatePattern =
		/^\d{4}-\d{2}-\d{2}(?:T\d{2}:\d{2}(?::\d{2}(?:\.\d{1,3})?)?(?:Z|[+-]\d{2}:\d{2}))?$/;
	const lastUpdated = new Date(frontmatter.lastUpdated);
	const [year, month, day] = frontmatter.lastUpdated
		.slice(0, 10)
		.split('-')
		.map(Number);
	const daysInMonth = new Date(Date.UTC(year, month, 0)).getUTCDate();
	const hasValidCalendarDate = month >= 1 && month <= 12 && day >= 1 && day <= daysInMonth;
	if (
		!isoDatePattern.test(frontmatter.lastUpdated) ||
		!hasValidCalendarDate ||
		Number.isNaN(lastUpdated.valueOf())
	) {
		reportUsageError('lastUpdated must be a valid ISO-8601 date string');
		return undefined;
	}

	return { ...frontmatter, lastUpdated };
}

function getSlug(title: string) {
	return title
		.normalize('NFKD')
		.replace(/\p{Mark}/gu, '')
		.toLocaleLowerCase('en-US')
		.replace(/[^\p{Letter}\p{Number}]+/gu, '-')
		.replace(/^-+|-+$/g, '');
}

async function pathExists(path: string) {
	try {
		await access(path);
		return true;
	} catch {
		return false;
	}
}

async function getAstroConfigPath(startDirectory: string) {
	let directory = resolve(startDirectory);
	const root = parse(directory).root;

	while (true) {
		for (const name of astroConfigNames) {
			const candidate = join(directory, name);
			if (await pathExists(candidate)) return candidate;
		}

		if (directory === root) return undefined;
		directory = dirname(directory);
	}
}

function getAutogeneratedDirectories(value: unknown): string[] {
	if (Array.isArray(value)) return value.flatMap(getAutogeneratedDirectories);
	if (value === null || typeof value !== 'object') return [];

	const item = value as {
		autogenerate?: { directory?: unknown };
		items?: unknown;
	};
	const directory = item.autogenerate?.directory;
	return [
		...(typeof directory === 'string' ? [directory] : []),
		...getAutogeneratedDirectories(item.items),
	];
}

async function getDocsDirectory(startDirectory: string) {
	const configPath = await getAstroConfigPath(startDirectory);
	if (!configPath) {
		reportError('could not find an Astro config in this directory or its parents', 1);
		return undefined;
	}

	const projectDirectory = dirname(configPath);
	// Astro does not expose resolved `srcDir` through its public API, so use the
	// same config loader as Astro's commands instead of duplicating config parsing.
	const astroPackageUrl = new URL(import.meta.resolve('astro/package.json'));
	const configLoaderUrl = new URL('./dist/core/config/config.js', astroPackageUrl);
	const { resolveConfig } = (await import(configLoaderUrl.href)) as {
		resolveConfig: (
			config: { root: string },
			command: string,
		) => Promise<{
			userConfig: { integrations?: Array<{ name?: string }> };
			astroConfig: { srcDir: URL };
		}>;
	};
	const { userConfig, astroConfig } = await resolveConfig(
		{ root: projectDirectory },
		'build',
	);
	const hasStarlight = userConfig.integrations?.some(
		(integration) => integration.name === '@astrojs/starlight',
	);
	if (!hasStarlight) {
		reportError(`Astro project at ${projectDirectory} does not configure Starlight`, 1);
		return undefined;
	}

	return join(fileURLToPath(astroConfig.srcDir), 'content', 'docs');
}

async function getExistingDirectories(
	docsDirectory: string,
	allowedDirectories: string[],
) {
	async function getNestedDirectories(
		directory: string,
		relativeDirectory: string,
	): Promise<string[]> {
		if (!(await pathExists(directory))) return [];

		const entries = await readdir(directory, { withFileTypes: true });
		const directories = entries.filter((entry) => entry.isDirectory());
		const nestedDirectories = await Promise.all(
			directories.map((entry) =>
				getNestedDirectories(
					join(directory, entry.name),
					join(relativeDirectory, entry.name),
				),
			),
		);
		return [relativeDirectory, ...nestedDirectories.flat()];
	}

	const directories = await Promise.all(
		allowedDirectories.map((directory) =>
			getNestedDirectories(join(docsDirectory, directory), directory),
		),
	);
	return directories.flat().sort((left, right) => left.localeCompare(right));
}

export async function promptForDirectory(
	docsDirectory: string,
	streams: { input?: Readable; output?: Writable } = {},
) {
	const allowedDirectories = getAutogeneratedDirectories(starlightSidebar);
	const existingDirectories = await getExistingDirectories(
		docsDirectory,
		allowedDirectories,
	);
	const createDirectoryValue = '__create_new_directory__';
	const selectedDirectory = await select({
		...streams,
		message: 'Select a directory relative to the Starlight docs collection',
		options: [
			{ value: '.', label: 'Docs root' },
			...existingDirectories.map((directory) => ({ value: directory, label: directory })),
			{ value: createDirectoryValue, label: 'Create a new directory' },
		],
		initialValue: existingDirectories.includes('guides') ? 'guides' : existingDirectories[0] ?? '.',
	});
	if (isCancel(selectedDirectory)) {
		cancel('Page creation cancelled.');
		process.exitCode = 130;
		return undefined;
	}
	if (selectedDirectory !== createDirectoryValue) return selectedDirectory;

	const newDirectory = await text({
		...streams,
		message: 'Enter a directory beneath a sidebar section',
		placeholder: `${allowedDirectories[0] ?? 'guides'}/advanced`,
		validate: (value) => (value?.trim() ? undefined : 'Enter a relative directory.'),
	});
	if (isCancel(newDirectory)) {
		cancel('Page creation cancelled.');
		process.exitCode = 130;
		return undefined;
	}
	return newDirectory.trim();
}

async function getSafeDirectory(docsDirectory: string, value: string) {
	if (isAbsolute(value)) {
		reportUsageError('directory must be relative to the Starlight docs collection');
		return undefined;
	}

	const targetDirectory = resolve(docsDirectory, value);
	const relativeDirectory = relative(docsDirectory, targetDirectory);
	if (relativeDirectory.startsWith('..') || isAbsolute(relativeDirectory)) {
		reportUsageError('directory must be relative to the Starlight docs collection');
		return undefined;
	}

	const normalizedDirectory = relativeDirectory.replaceAll('\\', '/');
	const allowedDirectories = getAutogeneratedDirectories(starlightSidebar).map((directory) =>
		directory.replaceAll('\\', '/').replace(/^\.\//, '').replace(/\/$/, ''),
	);
	const isCovered =
		normalizedDirectory === '' ||
		allowedDirectories.some(
			(directory) =>
				normalizedDirectory === directory || normalizedDirectory.startsWith(`${directory}/`),
		);
	if (!isCovered) {
		const allowedNames = allowedDirectories.join(', ');
		reportUsageError(
			`directory must be the docs root or nested beneath a sidebar directory: ${allowedNames}`,
		);
		return undefined;
	}

	const realDocsDirectory = await realpath(docsDirectory);
	let existingAncestor = targetDirectory;
	while (!(await pathExists(existingAncestor))) {
		existingAncestor = dirname(existingAncestor);
	}
	const realExistingAncestor = await realpath(existingAncestor);
	const realRelativeDirectory = relative(realDocsDirectory, realExistingAncestor);
	if (realRelativeDirectory.startsWith('..') || isAbsolute(realRelativeDirectory)) {
		reportUsageError('directory must not escape the Starlight docs collection through a symlink');
		return undefined;
	}

	return targetDirectory;
}

async function main() {
	let parsedArguments;
	try {
		parsedArguments = parseArgs({
			args: process.argv.slice(2),
			allowPositionals: true,
			options: {
				directory: { type: 'string' },
				'dry-run': { type: 'boolean', default: false },
				help: { type: 'boolean', short: 'h', default: false },
			},
			strict: true,
		});
	} catch (error) {
		reportUsageError(error instanceof Error ? error.message : 'invalid arguments');
		return;
	}

	if (parsedArguments.values.help) {
		process.stdout.write(help);
		return;
	}
	if (parsedArguments.positionals.length > 3) {
		reportUsageError(
			`unexpected positional argument: ${parsedArguments.positionals[3]}`,
		);
		return;
	}

	const [titleValue, description, frontmatterValue] = parsedArguments.positionals;
	if (!titleValue?.trim()) {
		reportUsageError('title must be non-empty');
		return;
	}
	const title = titleValue.trim();
	const slug = getSlug(title);
	if (!slug) {
		reportUsageError('title must contain a letter or number to create a filename');
		return;
	}
	if (!description?.trim()) {
		reportUsageError('description must be non-empty');
		return;
	}
	const normalizedDescription = description.trim();

	const frontmatter = parseFrontmatter(frontmatterValue);
	if (frontmatter === undefined) return;
	if ('title' in frontmatter || 'description' in frontmatter) {
		reportUsageError('frontmatter JSON must not include title or description');
		return;
	}

	const frontmatterWithDates = getFrontmatterWithDates(frontmatter);
	if (!frontmatterWithDates) return;
	const inputFrontmatter = {
		title,
		description: normalizedDescription,
		...frontmatterWithDates,
	};
	const validatedFrontmatter = await getValidatedFrontmatter(inputFrontmatter);
	if (!validatedFrontmatter) return;

	const docsDirectory = await getDocsDirectory(process.cwd());
	if (!docsDirectory) return;

	const directoryValue =
		parsedArguments.values.directory ?? (await promptForDirectory(docsDirectory));
	if (!directoryValue) return;

	const directory = await getSafeDirectory(docsDirectory, directoryValue);
	if (!directory) return;

	const targetPath = join(directory, `${slug}.md`);
	if (await pathExists(targetPath)) {
		reportError(`file already exists: ${targetPath}`, 1);
		return;
	}

	const markdown = getMarkdown(
		getCanonicalValue(inputFrontmatter, validatedFrontmatter),
	);
	const displayedPath = relative(process.cwd(), targetPath).replaceAll('\\', '/');
	if (parsedArguments.values['dry-run']) {
		process.stdout.write(markdown);
		process.stderr.write(`Would create: ${displayedPath}\n`);
		return;
	}

	await mkdir(directory, { recursive: true });
	try {
		await writeFile(targetPath, markdown, { flag: 'wx' });
	} catch (error) {
		if ((error as NodeJS.ErrnoException).code === 'EEXIST') {
			reportError(`file already exists: ${targetPath}`, 1);
			return;
		}
		throw error;
	}
	process.stdout.write(`Created: ${displayedPath}\n`);
}

const entryPath = process.argv[1] ? pathToFileURL(resolve(process.argv[1])).href : undefined;
if (entryPath === import.meta.url) {
	try {
		await main();
	} catch (error) {
		reportError(error instanceof Error ? error.message : 'could not create the page', 1);
	}
}
