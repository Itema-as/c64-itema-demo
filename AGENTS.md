# Repository Guidelines

## Project Structure & Assets
- `itema.asm` is the entry point; it links music (`music/*.sid`), intro art (`intro.koa`), and gameplay data to produce `itema.prg`.
- `library/` holds shared routines (`lib*.asm`, `font.asm`, `sprites.asm`, `sfx.asm`) plus generated symbol/vice debug outputs in `library/out/`.
- `petscii/` stores level screens and sequences; `out/` and `target/` are build/output directories; `tools/KickAss.jar` is the bundled compiler. Keep binary assets small and documented.

## Build & Run
- Build locally (requires Java 11+): `mkdir -p target && java -jar ./tools/KickAss.jar -o ./target/itema.prg itema.asm`.
- Run in VICE with mouse-as-paddle: `x64sc -mouse -controlport1device 2 target/itema.prg` (use ⌘M on macOS to toggle mouse grab). Keep `target/` out of commits; the GitHub Actions workflow mirrors this build.

## Coding Style & Naming
- `.editorconfig`: tabs (size 4) for `.asm`, LF endings, final newline; trim trailing whitespace except in Markdown.
- Line comments start at column 33. Hardware constants are `UPPER_SNAKE`; gameplay constants use `CamelCase`; 16-bit values are prefixed with `w`; subroutines are `lower_snake_case`.
- Keep tables aligned for readability; prefer KickAssembler directives (`.const`, `.segment`, `.byte`, `.word`) over ad hoc macros unless shared across files.

## Testing & QA
- No automated tests; rely on manual playthroughs. After each change, build, then verify: intro koala screen shows ~5 seconds, paddle magnetism and ball velocity feel correct, scores/lives update, and music/sfx play without distortion.
- When altering assets, confirm level screens render correctly and that sprite/tile changes match color expectations on real hardware palettes.

## Commit & Pull Request Guidelines
- Follow the existing short, imperative commit style (e.g., “Show high res intro screen for 5 seconds”). Keep commits scoped and note asset sources when adding or regenerating binaries.
- PRs should explain gameplay impact, list manual test steps (emulator flags included), and attach screenshots/GIFs for visual changes. Link related issues where applicable.
- Exclude generated artifacts (`target/*.prg`, `.sym/.vs/.dbg`, `bin/`, temporary `out/` files) from version control; keep the tree reproducible from source and assets.
