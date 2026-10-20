# Design: replace

## Overview

`main()` passes `runtime.args()` to `cli.app.run`, which parses them with the
shared switch parser (`win.switches`), handles `/?` and `--version`, and
calls `commands.replace.run_replace`. That resolves the current directory
once, optionally waits for a key (`/W`), checks the source directory, lists
the source file names and checks the destination, and then either adds the
missing files (`/A`) or walks the destination for files to replace. Every
copy is verified by reading the target back, because native `io.fs` fails
silently.

## Modules

| Module | Contents |
|---|---|
| `source/main.loup` | entry point: `run(runtime.args())` |
| `source/appinfo.loup` | name, version, summary, exit statuses 0, 2, 3, 5, 11 |
| `source/cli/args.loup` | `Options`, `replace_switches()`, `looks_like_switch`, `parse_args` with replace's usage errors |
| `source/cli/usage.loup` | `usage()` (a short help text in this project's own words), `version_line()` |
| `source/cli/app.loup` | `run()`: parse, help/version, run, exceptions to status 5 |
| `source/commands/replace.loup` | messages, `summary`, `source_dir`, `dest_dir`, `source_names`, `replace_targets`, `add_targets`, `run_replace` |
| `source/commands/fileops.loup` | `is_writable`, `same_content`, `copy_over` |
| `source/commands/fullpath.loup` | `normalize_path`, `full_path`, `current_dir`, `physical_dir` |
| `source/commands/console.loup` | `wait_for_key`, `ask_yes_no`, `answer_value`, `answer_echo` |
| `source/win/` | the shared Windows code: switches, wildcards, paths, messages |

### Command line

The six switches are flags. After the parse, in this order: a repeated
switch, then an operand before `--` that `looks_like_switch` (starts with
`/` or `-`, no other separator or wildcard, and nothing of that name
exists, so `/tmp/a.txt` and `/etc` stay paths), then more than two
operands, no operand, and `/A` with `/S` or `/U`. Each gives replace's own
message and status 11.

### Paths

Messages show full paths. Loup 1.26.0 has no `getcwd`, so `current_dir`
asks `sh -c pwd` once; `full_path` joins a relative path to it and
`normalize_path` removes `.` and `..` lexically; `display_path` turns `/`
into `\`. To tell whether a target is in the source directory,
`physical_dir` runs `cd DIR && pwd -P` (symbolic links resolved); the
result is cached per target directory while walking.

### Selection

- `source_names`: for a wildcard, `list_matches(source_dir, mask,
  MATCH_FILES)` (sorted NTFS-style, Win32 rules); otherwise the one name if
  it is a file.
- `replace_targets(dest, names, subdirs)`: lists the destination
  (`sort_names`), takes each file whose name is in `names` and, with `/S`,
  recurses into each directory where it appears, up to `MAX_DEPTH` (no
  `lstat`, so symbolic link loops are only bounded).
- `add_targets(dest, names)`: the destination paths of the source names for
  which nothing exists yet.

### Copying

`copy_over(src, dst)` removes a read-only `dst` first (reached only with
`/R`; the program checks `is_writable`, `test -w`, before that), calls
`io.fs.copy`, and returns whether `dst` is a file with the source's bytes
(`same_content` compares lengths, then byte by byte). `/U` uses
`same_content` to skip unchanged files.

### Interaction

Loup 1.26.0 reads standard input only as a whole, so `console.loup` runs
a `sh` child that inherits standard input and reads only what it needs:

- `/W`: prints the prompt, then `dd bs=1 count=1` (in raw mode via `stty`
  when standard input is a terminal), then a newline.
- `/P`: prints the question, then `IFS= read -r` in `sh`, which prints `1`
  or `0` (terminal or not) and the line, and fails at the end of input.
  `answer_value` reads `Y`/`N` from the first character (any case);
  anything else asks again; end of input is No. When the input is not a
  terminal the answer is echoed (`answer_echo`), as a terminal would have.

### Output

Every progress line, question and summary starts with `\n` (Windows prints
an empty line before each). Progress and summary go to standard output;
`Access denied`, `Path not found`, `No files found` and
`File cannot be copied onto itself` to standard error.

## Differences from the original

- `/U` compares contents, not dates (Loup 1.26.0 has no `stat()`).
- Read-only means "not writable by this user" (`test -w`); there are no
  hidden or system attributes, so no file is skipped for them.
- Names are case-sensitive on Linux (wildcards ignore case); no 8.3 names
  or drive letters.
- Copies carry no attributes: an overwritten file keeps its permissions, a
  read-only one replaced with `/R` is recreated with default permissions.
- `/P` and `/W` read through a `sh` child; `/P` was deferred in the
  roadmap and is implemented this way.
- Messages end with LF, not CRLF.
- The `/?` text is a short summary in this project's own words.
- `--help` and `--version` (alone) are series conventions.

## Error handling

Usage errors: status 11. Source directory or destination missing: 3. No
source file: 2. A read-only target without `/R` or a copy that does not
verify: `Access denied - PATH` and status 5, stopping the run (the files
already copied stay). An unexpected exception is printed with status 5.

## Testing

- `tests/args_test.loup`: operands, switches in any position and case,
  Linux paths as operands, help/version, every usage error, `--`,
  `looks_like_switch`.
- `tests/replace_test.loup`: messages and summaries, `source_dir`,
  `dest_dir`, `source_names`, `replace_targets` with and without `/S`,
  `add_targets`, on a fixture tree under `build/tmp/`.
- `tests/helpers_test.loup`: `normalize_path`, `full_path`,
  `physical_dir`, answers, `is_writable`, `same_content`, `copy_over`.
- `tests/app_test.loup`: exit statuses through `run()`.
- `tests/win_*_test.loup`: the shared Windows code.
- `tests/e2e.sh`: runs the native binary on a fixture tree under `$TMP`
  (rebuilt before each changing case) and compares standard output byte for
  byte, standard error, the status and the files' contents afterwards; `/P`
  and `/W` read their answers from files.
