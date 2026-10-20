# loup-cmd-replace

The Windows `replace` command recreated in [Loup](https://code-craft.ai/references/loup):
copy source files over the files of the same name in a folder (or a whole
tree), or add the ones the folder lacks, on Linux.

Part of the **loup-cmd** series of example applications: classic Linux and
Windows commands, and projects for each Loup execution mode, each in its own
repository under [myronccai](https://github.com/myronccai?tab=repositories&q=loup-cmd).
This one is `host.dual` Loup built as a native binary. It shows a directory
walk that matches names, content comparison in place of timestamps, file
copies that are verified afterwards, and line-at-a-time prompts through a
`sh` child, on top of the shared Windows code in
[`source/win/`](source/win/) (switch parser, wildcard matcher, paths,
messages).

## Requirements

- [Loup Lite](https://github.com/code-craft-ai-company/loup-releases) 1.26.0
  or later; see [Installing Loup Lite](#installing-loup-lite).
- `make`, and `clang` 17 or later for the native build.

## Installing Loup Lite

This example is built and tested with **Loup Lite**, the free public build of
the Loup toolchain from [Code Craft AI](https://code-craft.ai), meant for
education and training. Code Craft AI publishes the official builds,
installers and signed checksums at
**<https://github.com/code-craft-ai-company/loup-releases>**, for Linux
(x86-64, arm64), macOS (Apple silicon, Intel) and Windows (x86-64).

Linux and macOS:

```sh
curl -fsSL https://github.com/code-craft-ai-company/loup-releases/releases/latest/download/loup-install.sh | sh
```

Windows (PowerShell):

```powershell
irm https://github.com/code-craft-ai-company/loup-releases/releases/latest/download/loup-install.ps1 | iex
```

The installer picks the archive for your machine, checks it against the
release's `SHA256SUMS`, unpacks it into `~/.loup`
(`%LOCALAPPDATA%\Programs\Loup` on Windows) and puts its `bin` directory on
your `PATH`; it needs no administrator rights. You get `loup`, the Stage0
compiler `loup-bootstrap` and the Wasm runtime `loup-launcher`. Open a new
shell and check:

```sh
loup --version             # loup 1.26.0 or later
```

CI installs the exact version it tests with, 1.26.0. To do the same:

```sh
curl -fsSL https://github.com/code-craft-ai-company/loup-releases/releases/download/v1.26.0/loup-install.sh | sh -s -- --version 1.26.0
```

To install by hand, download your platform's archive from the
[releases page](https://github.com/code-craft-ai-company/loup-releases/releases),
check it against `SHA256SUMS`, unpack it anywhere and add its `bin` directory to
`PATH`. The [loup-releases README](https://github.com/code-craft-ai-company/loup-releases#verify-a-download)
explains how to verify the Sigstore signature on `SHA256SUMS`.

Loup Lite leaves out Loup's cryptography library and the full set of Loup
packages; this example needs neither. The full release is at
<https://code-craft.ai/loup/download>, and commercial use of Loup needs a
license: <https://code-craft.ai/loup/license>.

## Usage

```sh
make build                     # native binary: build/replace
make ci                        # check, unit tests, build, end-to-end tests
make run ARGS="'src\*.txt' dst /U"   # run from source (Stage0: loup-bootstrap run)
```

```text
REPLACE source [destination] [/A] [/P] [/R] [/W]
REPLACE source [destination] [/P] [/R] [/S] [/W] [/U]
```

Quote operands that contain `\`, `*` or `?` so that the Linux shell passes
them through: cmd does not expand wildcards, replace does. In this example
`demo\new` holds `index.html`, `about.html` and `robots.txt`; `demo\site`
holds an older `index.html`, `blog\index.html` and a read-only
`robots.txt`:

```text
$ build/replace 'demo\new\*.html' 'demo\site'

Replacing \home\myron\repos\ccai-examples\loup-cmd-replace\demo\site\index.html

1 file(s) replaced
$ build/replace 'demo\new\*.html' 'demo\site' /A

Adding \home\myron\repos\ccai-examples\loup-cmd-replace\demo\site\about.html

1 file(s) added
$ build/replace 'demo\new\*.html' 'demo\site' /S /U

Replacing \home\myron\repos\ccai-examples\loup-cmd-replace\demo\site\blog\index.html

1 file(s) replaced
$ build/replace 'demo\new\robots.txt' 'demo\site'; echo "ERRORLEVEL $?"

Replacing \home\myron\repos\ccai-examples\loup-cmd-replace\demo\site\robots.txt
Access denied - \home\myron\repos\ccai-examples\loup-cmd-replace\demo\site\robots.txt
ERRORLEVEL 5
$ printf 'n\n' | build/replace 'demo\new\robots.txt' 'demo\site' /R /P

Replace \home\myron\repos\ccai-examples\loup-cmd-replace\demo\site\robots.txt? (Y/N)N

No files replaced
$ build/replace 'demo\new\robots.txt' 'demo\site' /R

Replacing \home\myron\repos\ccai-examples\loup-cmd-replace\demo\site\robots.txt

1 file(s) replaced
$ build/replace 'demo\new\*.doc' 'demo\site'; echo "ERRORLEVEL $?"

No files found - \home\myron\repos\ccai-examples\loup-cmd-replace\demo\new\*.doc
ERRORLEVEL 2
$ build/replace 'demo\new\index.html' 'demo\nowhere'; echo "ERRORLEVEL $?"
Path not found - \home\myron\repos\ccai-examples\loup-cmd-replace\demo\nowhere
ERRORLEVEL 3
$ build/replace 'demo\new\*.html' 'demo\site' /A /S; echo "ERRORLEVEL $?"
Invalid parameter combination
ERRORLEVEL 11
$ build/replace --version
replace (loup-cmd-replace) 0.1.0
```

In the third run `index.html` and `about.html` already match their sources,
so `/U` leaves them alone.

### Operands

- `source`: one file, or a wildcard in the last component (`*` and `?`,
  Windows rules, any case). Directories never count as source files.
- `destination`: the folder to update (default: the current folder).
  Either separator works (`\` or `/`).

Without `/A`, every file in the destination whose name is a source file's
name is overwritten with that source file; files with other names are left
alone. With `/S` the destination's subfolders are searched too, in name
order, each one where it falls among the files. With `/A`, the source files
that the destination does not have are copied in, and nothing is
overwritten.

### Switches

| Switch | Meaning |
|---|---|
| `/A` | add the source files missing from the destination (not with `/S` or `/U`) |
| `/P` | ask `Replace X? (Y/N)` or `Add X? (Y/N)` before each file |
| `/R` | overwrite read-only files too |
| `/S` | replace in every subfolder of the destination as well |
| `/W` | print `Press any key to continue . . .` and wait for a key first |
| `/U` | replace only the files whose contents differ from the source's |
| `/?` | help |

Switches start with `/` or `-` in any case and may come anywhere; `--`
ends them. A `/x` that is not a switch and names nothing is reported as
`Invalid switch - /x`; an existing path such as `/tmp/a.txt` stays a path.

`/P` reads one line per question: an answer starting with `Y` or `N` (any
case) decides, anything else asks again, and the end of the input means
No. When the answers come from a pipe or a file, the answer is echoed after
the question. `/W` takes one key from a terminal (one byte from a pipe).

Messages print full paths with `\`. Each `Replacing`/`Adding` line and the
summary (`N file(s) replaced`, `No files added`, ...) follow an empty line,
as on Windows. A file that is the source itself (the destination is the
source folder) is skipped with `File cannot be copied onto itself`.

Exit status (ERRORLEVEL): `0` done (also when nothing needed replacing), `2`
no source file found, `3` source folder or destination not found, `5` a
read-only file without `/R` or a failed copy (replace stops there), `11` a
command-line error (`Source path required`, `Too many parameters - X`,
`Invalid switch - X`, `Invalid parameter combination`).

## Differences from the original

- `/U` replaces the files whose **contents** differ from the source, not
  the ones that are older: Loup 1.26.0 cannot read file dates (no
  `stat()`). Files are read in full to compare them.
- `/R` and the read-only check use the Unix write permission (`test -w`);
  there are no hidden or system attributes, so dot-files are ordinary
  files and nothing is skipped for being hidden.
- File names are case-sensitive on Linux: a destination file is replaced
  when its name equals a source name exactly, and a literal source name
  must match its case (wildcards ignore case). There are no 8.3 short
  names and no drive letters: full paths look like `\home\me\site\a.txt`.
- A copy writes the source's bytes only; no attributes are carried over.
  A replaced file keeps its own permissions, and a read-only one replaced
  with `/R` is recreated with default permissions.
- `/P` reads its answers one line at a time through a `sh` child and
  `/W` through `dd` (Loup 1.26.0 reads standard input only as a whole).
  The roadmap had deferred `/P`; it is implemented.
- Messages end with LF, not CRLF.
- The `/?` text is a short summary written for this project, not Windows' help.
- `--help` and `--version` as the only argument are series conventions.

## Layout

```text
source/main.loup                 # entry point
source/appinfo.loup              # name, version, exit statuses (0, 2, 3, 5, 11)
source/cli/args.loup             # operands and /A /P /R /S /W /U via win.switches, usage errors
source/cli/usage.loup            # /? and --version text
source/cli/app.loup              # run(): parse, dispatch, exit status
source/commands/replace.loup     # source names, targets, replace and add, messages
source/commands/fileops.loup     # write check, content comparison, verified copy
source/commands/fullpath.loup    # full and physical paths (no getcwd in Loup 1.26.0)
source/commands/console.loup     # /W key wait and /P questions
source/win/                      # shared Windows code (a copy of loup-cmd-type's)
tests/*_test.loup                # unit tests (make test)
tests/e2e.sh                     # end-to-end tests of build/replace (make e2e)
specs/replace/                   # requirements, design, tasks
```

[AGENTS.md](AGENTS.md) has every build and test command and the conventions
for changing the code.

## License

[MIT](LICENSE), copyright 2026 Code Craft AI LLC. The Loup skill in
[`skills/loup-programmer/`](skills/loup-programmer/) is copied from the Loup
project and is not covered by this license; it keeps the Loup project's terms.
