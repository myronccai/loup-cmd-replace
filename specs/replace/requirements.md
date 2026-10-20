# Requirements: replace

## Introduction

`replace` is the Windows command that copies source files over the files
of the same name in a destination directory (optionally its whole tree), or
with `/A` adds the source files the destination does not have. This
repository recreates it in Loup for Linux, keeping Windows' switch syntax
(`/A`, `/P`, `/R`, `/S`, `/W`, `/U`, `/?`), messages and ERRORLEVELs. Since
Loup 1.26.0 cannot read file dates, `/U` compares contents instead of
timestamps.

## Requirements

### Requirement 1: Source and destination

**User Story:** As a cmd user, I want to name the files to copy and the
folder to update the way `replace` takes them.

#### Acceptance Criteria

1. THE program SHALL take a source operand (a file, or a wildcard in its
   last component) and an optional destination directory (default: the
   current directory), with `\` or `/` as separators.
2. WHEN the source has a wildcard, THE source files SHALL be the files (not
   directories) of the source directory whose names match it under Windows
   wildcard rules, case-insensitively; otherwise the one file named.
3. WHEN the source directory does not exist, or a directory component holds
   a wildcard, THE program SHALL print `Path not found - FULLPATH` on
   standard error and exit with status 3.
4. WHEN no source file is found, THE program SHALL print an empty line and
   `No files found - FULLPATH` on standard error and exit with status 2.
5. WHEN the destination is not a directory, THE program SHALL print
   `Path not found - FULLPATH` on standard error and exit with status 3.

### Requirement 2: Replace

**User Story:** As a cmd user, I want newer copies of files pushed over the
old ones wherever they are in a folder.

#### Acceptance Criteria

1. WITHOUT `/A`, THE program SHALL overwrite every file of the destination
   whose name equals a source file's name with that source file, and leave
   every other file alone.
2. WHEN `/S` is given, THE program SHALL also search every subdirectory of
   the destination, visiting entries in NTFS name order and each
   subdirectory where it appears among them, depth first.
3. BEFORE each replacement, THE program SHALL print an empty line and
   `Replacing FULLPATH` on standard output.
4. WHEN `/U` is given, THE program SHALL skip the files whose contents equal
   the source's.
5. WHEN a target lies in the source directory itself (also through `..` or
   symbolic links), THE program SHALL print
   `File cannot be copied onto itself` on standard error and skip it.
6. WHEN a target is read-only and `/R` is not given, or a copy fails, THE
   program SHALL print `Access denied - FULLPATH` on standard error and stop
   with status 5. WITH `/R`, read-only targets SHALL be replaced.
7. AT the end, THE program SHALL print an empty line and
   `N file(s) replaced`, or `No files replaced`, and exit with status 0.

### Requirement 3: Add

**User Story:** As a cmd user, I want to copy in only the files a folder is
missing, without touching the ones it has.

#### Acceptance Criteria

1. WHEN `/A` is given, THE program SHALL copy each source file that has no
   entry of the same name in the destination (not its subdirectories), in
   name order, printing an empty line and `Adding FULLPATH` before each.
2. AT the end, THE program SHALL print an empty line and
   `N file(s) added`, or `No files added`, and exit with status 0.

### Requirement 4: Interaction

**User Story:** As a cmd user, I want to confirm each file, or to be given
time to prepare before the copying starts.

#### Acceptance Criteria

1. WHEN `/P` is given, THE program SHALL ask `Replace FULLPATH? (Y/N)` (or
   `Add FULLPATH? (Y/N)`) after an empty line, read one line of standard
   input, act on an answer that starts with `Y` and skip on one that starts
   with `N` (any case), ask again on anything else, and take the end of the
   input as No. WHEN standard input is not a terminal, it SHALL echo the
   answer.
2. WHEN `/W` is given, THE program SHALL print
   `Press any key to continue . . .`, wait for one key (one byte of
   non-terminal input, or its end), and then start.
3. THE program SHALL read only as much standard input as each question
   needs.

### Requirement 5: Command line and errors

**User Story:** As a cmd user, I want Windows' switch syntax and messages.

#### Acceptance Criteria

1. THE program SHALL accept `/A`, `/P`, `/R`, `/S`, `/W`, `/U` with `/` or
   `-` in any case, anywhere among the operands; `--` ends the switches.
2. WHEN `/?` or `-?` is given, THE program SHALL print the help text and
   exit 0.
3. WHEN no source is given, THE program SHALL print `Source path required`;
   WHEN more than two operands are given, `Too many parameters - X` (the
   third); WHEN a switch is repeated, or an operand looks like a switch
   (`/x`, `-q`: no further separator or wildcard, naming nothing that
   exists), `Invalid switch - X`; WHEN `/A` is combined with `/S` or `/U`,
   `Invalid parameter combination`. Each on standard error, with status 11.
4. THE program SHALL show paths in messages in full, with `\`.
5. WHEN `--version` is the only argument, THE program SHALL print
   `replace (loup-cmd-replace) 0.1.0`; `--help` alone SHALL print the help.
