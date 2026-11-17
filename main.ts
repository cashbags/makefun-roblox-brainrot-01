// Brainrot Bay — entry program for make.fun roblox-brainrot-01 (Node 22,
// standard library only). The game itself is the Rojo project in this
// directory: `rojo build default.project.json --output game.rbxl` turns
// src/ and default.project.json into game.rbxl, and this program hands
// that place in. It copies game.rbxl, PLAY.json, src/ and screenshots/
// from beside this file into the output directory and writes
// /output/dossier.json, the summary the judge reads, using the vendored
// make.fun library (vendor/makefun-roblox.ts, the kit's copy, unchanged).
//
// The grader runs this in a fresh container with a writable /output;
// outside it, MAKEFUN_OUTPUT_DIR stands in for /output:
//   mkdir -p out && MAKEFUN_OUTPUT_DIR=out node main.ts
//
// One rule shapes the copying below: every name under /output must
// start with a letter, a digit or _ and hold only letters, digits, . _
// and -, so anything whose name starts with a dot (.gitkeep, .DS_Store,
// .git) is left out at every depth, or the grader fails the entry.
// A second rule shapes the failure mode: if game.rbxl is missing the
// program stops with a clear error instead of handing in a half entry.

import { copyFileSync, cpSync, existsSync, mkdirSync, readdirSync, writeFileSync } from 'node:fs';
import { basename, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { buildDossier } from './vendor/makefun-roblox.ts';

const here = fileURLToPath(new URL('.', import.meta.url));
const out = process.env.MAKEFUN_OUTPUT_DIR ?? '/output';

/** cpSync's filter: skip every file and directory whose name starts with a dot. */
const notDotted = (path: string): boolean => !basename(path).startsWith('.');

const placeFile = join(here, 'game.rbxl');
if (!existsSync(placeFile)) {
	throw new Error('game.rbxl is missing: run `rojo build default.project.json --output game.rbxl` first.');
}

mkdirSync(out, { recursive: true });
copyFileSync(placeFile, join(out, 'game.rbxl'));
copyFileSync(join(here, 'PLAY.json'), join(out, 'PLAY.json'));
cpSync(join(here, 'src'), join(out, 'src'), { recursive: true, filter: notDotted });
mkdirSync(join(out, 'screenshots'), { recursive: true });
if (existsSync(join(here, 'screenshots'))) {
	cpSync(join(here, 'screenshots'), join(out, 'screenshots'), { recursive: true, filter: notDotted });
}

// Brainrot Bay's own log line: what actually went into the entry.
console.log('Brainrot Bay entry: ' + readdirSync(join(out, 'src')).join(', ') + ' + game.rbxl + PLAY.json');

// The scorer's own caps (reference/gate.json): only text_max_bytes shapes
// the bytes; the others refuse an entry the scorer would refuse (more than
// 4 screenshots or one over 256 KiB; a place of more than 500000 instances,
// whose scripts' sources come to over 8 MiB or whose scripts' paths come
// to over 1048576 characters, in all).
writeFileSync(
	join(out, 'dossier.json'),
	buildDossier(out, { text_max_bytes: 65536, screenshots: { max: 4, max_bytes: 262144 }, max_instances: 500000, scripts_max_source_bytes: 8388608, scripts_max_path_chars: 1048576 }),
);
