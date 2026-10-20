# AGENTS.md

This repository recreates the Windows `replace` command in the Loup
programming language, as part of the loup-cmd series of example
applications. The program is `host.dual` Loup built as a native executable
for Linux, with cmd's switch, wildcard, path and message conventions. It
copies source files over same-named files of a destination directory (or
its tree with `/S`), or adds the missing ones (`/A`); `/U` compares
contents because Loup 1.26.0 cannot read file dates. `source/win/` is a
copy of the shared Windows code (master: loup-cmd-type).

## Skills

| Skill | Location | Use it when |
|-------|----------|-------------|
| `loup-programmer` | [skills/loup-programmer/SKILL.md](skills/loup-programmer/SKILL.md) | Writing, reviewing, debugging or explaining Loup code: `.lpscr`, `.loup`, `.lphc`, `.lpweb` or `.lpfree` source files, `.lppkg` manifests, `@mode(...)` directives, or the `loup` / `loup-bootstrap` commands. |

Read `skills/loup-programmer/SKILL.md` before writing or changing any Loup code
in this repository. It links to detailed references under
`skills/loup-programmer/references/` for syntax, types and ownership, execution
modes and projects, errors and diagnostics, the standard library, and common
mistakes. Load those only as needed.

## Code layout

```text
.
├── package.lppkg                # Loup manifest: name, version, toolchain, [build] entry, [test] pattern
├── Makefile                     # run, check, test, build, e2e, ci, clean
├── source/                      # all Loup code; modules import each other by path from here
│   ├── main.loup                # entry point: func main() calls run(runtime.args())
│   ├── appinfo.loup             # APP_NAME, APP_VERSION, APP_SUMMARY, exit statuses 0/2/3/5/11
│   ├── cli/
│   │   ├── args.loup            # struct Options, replace_switches(), looks_like_switch(), parse_args()
│   │   ├── usage.loup           # usage() (short /? text), version_line()
│   │   └── app.loup             # run(): parse, /? and --version, run_replace, exit status
│   ├── commands/
│   │   ├── replace.loup         # source_names(), replace_targets(), add_targets(), messages, run_replace()
│   │   ├── fileops.loup         # is_writable(), same_content(), copy_over() (verified copy)
│   │   ├── fullpath.loup        # normalize_path(), full_path(), current_dir(), physical_dir()
│   │   └── console.loup         # wait_for_key() (/W), ask_yes_no() (/P) through a sh child
│   └── win/                     # shared Windows code (a copy; master in loup-cmd-type)
│       ├── switches.loup        # cmd switch parser: /S -s /A:H /T 10 /S/Q /? --
│       ├── wildcard.loup        # Win32 wildcard matcher, list_matches(), sort_names()
│       ├── paths.loup           # fs_path(), display_path(), split/join helpers
│       └── messages.loup        # Windows message texts
├── tests/
│   ├── *_test.loup              # unit tests: func test_*(): void (win_*_test.loup test source/win/)
│   ├── e2e.sh                   # end-to-end tests of the native binary (fixture tree under $TMP)
│   └── fixtures/help.txt        # the expected /? output
├── specs/replace/               # requirements.md, design.md, tasks.md
├── skills/loup-programmer/      # the Loup skill and its references
├── .github/workflows/ci.yml     # installs Loup and runs `make ci`
└── build/                       # build output (git-ignored); unit tests write fixtures to build/tmp/
```

## Build, run and test

Prerequisites: Loup 1.26.0 (`loup` and `loup-bootstrap` on `PATH`), `make`,
and `clang` 17 or later for native builds.

Loup Lite comes from <https://github.com/code-craft-ai-company/loup-releases>;
[README.md](README.md#installing-loup-lite) has the install commands.

| Task | Command | Notes |
|------|---------|-------|
| Run from source | `make run ARGS="'src\*.txt' dst /U"` | `loup-bootstrap run source/main.loup -- ARGS` (the self-hosted `loup run` mangles `exec` arguments) |
| Type-check | `make check` | checks `source/main.loup` and every module it imports; tests are not checked |
| Run all tests | `make test` | every `tests/*_test.loup`, one at a time (`--no-parallel`) |
| Run matching tests | `make test TEST_ARGS="--filter targets"` | tests whose name contains `targets` |
| Run one test file | `make test TEST_ARGS="--file tests/replace_test.loup"` | |
| Build | `make build` | native binary at `build/replace` |
| Run the binary | `build/replace 'src\*.txt' dst /S` | quote `\`, `*`, `?` and `/?` in the shell |
| End-to-end tests | `make e2e` | runs `tests/e2e.sh build/replace`: stdout byte for byte, stderr exactly, files afterwards |
| Everything CI runs | `make ci` | check, test, build, e2e, then `build/replace --version` |
| Clean | `make clean` | removes `build/`, `.temp/` and `.loup-cache/` |

Run `make ci` before reporting a change as done. `loup run` and the native
build do not support the same things, so a change can pass `make test` and
still fail `make build`.

Do not call `loup test` or `loup check` directly on Linux x86-64. There `loup`
is the self-hosted driver: it refuses `check`, and its test runner cannot
resolve this project's imports. The Makefile uses `loup-bootstrap` (Stage0) for
both, and sets `LOUPPATH=source` for tests. Keep `--no-parallel`: Stage0's
parallel test runner fails these tests at random.

The e2e read-only cases rely on `chmod a-w` taking effect, so run them as
an ordinary user, not root.

## Making a change

1. Update the spec in `specs/replace/` (see [specs/README.md](specs/README.md)).
2. Change the code under `source/`.
3. Add or update unit tests in `tests/` and cases in `tests/e2e.sh`.
4. Run `make ci`.
5. Tick the finished tasks in the spec's `tasks.md`.

Keep behaviour in pure functions that return values (`source_names`,
`replace_targets`, `add_targets`, `summary`, `normalize_path`,
`answer_value`) so unit tests can check them; only `run_replace` and its
two helpers print and copy.

`source/win/` is a copy of the shared Windows code: do not change it here
alone. Improvements go to the master copy in loup-cmd-type and to
`ccai-examples/shared/windows/`, and are then copied back.

## Conventions

- Every source file is `@mode(host.dual)` with the `.loup` extension. Only
  `source/main.loup` has a `main()`.
- Modules import each other by path from `source/`:
  `from win.switches import (parse_switches);`. Tests import them the same
  way. Do not use relative imports (`from .args import ...`): the
  self-hosted `loup run` on Linux x86-64 fails on them.
- Windows conventions: switches via `win.switches`; operands go through
  `fs_path()` before file access and printed paths through
  `display_path()` (full paths, `\`); messages use replace's wording; usage
  errors are ERRORLEVEL 11.
- Struct fields read from another module must be `pub`.
- The native build supports less than `loup run` does. For example,
  `list.is_empty()` fails native codegen (`E-CODEGEN-UNHANDLED-METHOD`; use
  `len() == 0`), `system.text.parseInt` does not link, and `IoError` cannot
  be caught: check `isFile`/`isDir` before reading. Native `io.fs.copy` and
  `remove` fail silently, so verify the result (`copy_over` reads the
  target back). `exec()`'s `ProcResult` must be read in the function that
  called `exec` (see `current_dir`, `physical_dir`, `ask_yes_no`). A
  `match` expression whose arms build strings must be written in statement
  form.
- Standard input can only be read whole in Loup 1.26.0; `/P` and `/W` read
  through a `sh` child that inherits it and takes one line or one byte.
- Keep `APP_VERSION` in `source/appinfo.loup` equal to `version` in
  `package.lppkg`.
- The skill's examples use the `loup init` layout (`src/`, `tests/`, and
  `from ..src.x import` in tests). This project uses `source/` and
  `tests/` with plain imports; follow this file.
- The skill documents toolchain 1.25.1; this template targets 1.26.0. When
  they disagree, trust the toolchain's behaviour.
