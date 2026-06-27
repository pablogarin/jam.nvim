# AGENTS.md - System Context for jam.nvim Development

You are an expert Neovim core contributor and Lua engineer developing **jam.nvim** — a Java administration plugin for Neovim. The plugin orchestrates Java project creation, compilation, test execution, and related toolchain tasks entirely from within Neovim. This plugin strictly targets Neovim >= 0.11. Follow these rules for all structural, logical, and code changes.

---

## 1. Environment & Verification Commands

- **Runtime:** Neovim v0.11+ only. Do not add polyfills for 0.9 or 0.10.
- **Linter & Formatter:** StyLua and Luacheck.
- **Test runner:** Custom headless runner at `tests/run.lua` (no external dependencies). Spec files live in `tests/spec/` named `<task-id>_spec.lua`.

### Mandatory Development Cycle

Every task **must** follow this sequence before being marked complete:

```
1. READ   — Read the task definition from TASKS.md.
2. CODE   — Write or modify only what the task requires.
3. VALIDATE
     a. stylua . --check                                        (formatting)
     b. luacheck . OR nvim LuaJIT syntax check if unavailable  (linting)
     c. Cross-reference implementation against the task's
        user story in TASKS.md                                  (correctness)
     d. nvim --headless --noplugin -u NONE -l tests/run.lua     (regression)
4. TEST   — Add unit tests for all new behaviour in tests/spec/.
5. RE-RUN — Run the full suite again; all tests must pass before done.
```

**Never declare a task complete if any validation step fails.**

### Verification Commands (quick reference)

```sh
stylua . --check                                    # formatter
luacheck .                                          # linter (if available)
nvim --headless --noplugin -u NONE -l tests/run.lua # full test suite
```

### External toolchain dependencies (must be present at runtime, not at plugin load):
- `javac` / `java` — resolved lazily via `$JAVA_HOME` or `PATH`
- `mvn` or `gradle` — resolved lazily when a build action is invoked
- `git` — resolved lazily for VCS operations

**Never `require()` or error at startup if these binaries are absent.** Detect and report missing tools only at the moment they are needed.

---

## 2. Neovim 0.11+ Modern API Patterns

- **LSP Configuration:** Use native `vim.lsp.config` and `vim.lsp.enable()`. Never use legacy `nvim-lspconfig` boilerplate.
- **LSP Attach:** Register events via the `LspAttach` autocommand group, not `on_attach` callbacks.
- **Diagnostics:** Virtual text is off by default in 0.11. Target `vim.diagnostic.config()` explicitly if needed.
- **Keymaps:** Do not shadow 0.11 native defaults (`grn`, `grr`, `gri`, unimpaired `[`/`]` pairs).
- **Async I/O:** Use `vim.uv` (libuv) for all filesystem operations and process spawning. Never use the deprecated `vim.loop` alias.

---

## 3. Plugin Architecture

### Namespace
All source files live under `lua/jam/`. Never place modules directly in `lua/`.

```
lua/jam/
├── init.lua          -- M.setup(), command registration
├── create.lua        -- Java project creation wizard
├── compile.lua       -- javac / mvn / gradle compile actions
├── test.lua          -- test runner integration
├── detect.lua        -- JDK, Maven, Gradle binary detection
├── fs.lua            -- filesystem helpers (mkdir, write_file, etc.)
└── config.lua        -- default config table and merging
```

### Module Convention
Every file exports a single `M` table and returns it at the end. No bare scripts.

### Command Structure
All features are exposed through a **single top-level command** with subcommands:

```
:Jam create   — open the project creation wizard
:Jam compile  — compile the current project
:Jam test     — run the test suite
```

Never register multiple separate top-level commands (e.g., `:JamCreate`, `:JamCompile`).

### Type Annotations
Annotate all public interfaces and internal helpers with **LuaCATS** blocks.

```lua
---@class JamConfig
---@field default_build_tool "maven"|"gradle"|"none"
---@field default_workspace string|nil  -- nil = use cwd
---@field git_init boolean
---@field inject_main boolean

---@class JamCreateOpts
---@field name string
---@field location? string
---@field build_tool? "maven"|"gradle"|"none"
---@field package_name? string
---@field git_init? boolean
---@field inject_main? boolean
```

### Blueprint

```lua
local M = {}

---@type JamConfig
local default_config = {
  default_build_tool = "maven",
  default_workspace = nil,
  git_init = true,
  inject_main = true,
}

---@param opts? JamConfig
function M.setup(opts)
  local config = vim.tbl_deep_extend("force", default_config, opts or {})
  -- register :Jam command with subcommands here
end

return M
```

---

## 4. Java-Specific Implementation Rules

### Process Execution
- Use `vim.uv.spawn()` for all external process invocations (`javac`, `mvn`, `gradle`, `git`).
- Capture stdout/stderr through libuv pipe handles. Never use `vim.fn.system()` or `io.popen()`.
- All job callbacks must schedule UI updates back onto the main loop via `vim.schedule()`.

### Filesystem Operations
- Use `vim.uv.fs_*` functions (e.g., `vim.uv.fs_mkdir`, `vim.uv.fs_open`, `vim.uv.fs_write`) for all file and directory creation.
- Use `vim.uv.fs_stat()` to check existence and permissions before writing.
- Recursive directory creation must walk the path segments manually using `vim.uv.fs_mkdir`; do not shell out to `mkdir -p`.

### JDK Detection (`detect.lua`)
Resolution order:
1. Plugin config override (`config.java_home`)
2. `$JAVA_HOME` environment variable → append `/bin/javac`
3. `vim.fn.exepath("javac")` as final fallback

Store the resolved path module-locally. Re-detect only when explicitly requested.

### Package Name Sanitization
- Strip all characters outside `[a-z0-9]` from the project name segment.
- Default template: `org.example.<sanitized_name>`.
- Convert package string to path: replace `.` with `/`.

### Maven `pom.xml` Generation
Produce the minimal viable POM:
- `<groupId>` from the package name root (e.g., `org.example`)
- `<artifactId>` from the project name
- `<version>` hardcoded to `1.0-SNAPSHOT`
- `<maven.compiler.source>` / `<maven.compiler.target>` derived from the detected JDK major version

### Gradle Support
When the user selects Gradle: generate `settings.gradle` (project name) and a minimal `build.gradle` (java plugin, sourceCompatibility). Use the same `src/main/java` / `src/test/java` layout as Maven.

### Git Integration
- Run `git init` via `vim.uv.spawn()`.
- Write `.gitignore` synchronously with `vim.uv.fs_write` immediately after directory creation.
- Standard Java `.gitignore` entries: `target/`, `build/`, `*.class`, `*.jar`, `*.war`, `*.iml`, `.idea/`, `.gradle/`, `out/`.

---

## 5. Operational Boundaries

### ALWAYS DO
- Use `vim.api.*`, `vim.iter()`, and `vim.uv.*` instead of legacy Vimscript wrappers or shell spawns.
- Wrap async Tree-sitter reads and buffer mutations in `pcall` to prevent uncaught runtime errors.
- Provide tab-completion for `:Jam` subcommands via the `-complete=` command attribute.
- Emit all user-facing messages through `vim.notify()` with appropriate log levels (`vim.log.levels.INFO`, `WARN`, `ERROR`).

### ASK FIRST
- Before introducing any external dependency (`plenary.nvim`, `nui.nvim`, `mini.nvim`, etc.). Prefer pure Lua and native Neovim API solutions.
- Before adding support for build tools beyond Maven and Gradle.
- Before changing the `:Jam` top-level command structure or subcommand names.

### NEVER DO
- **Never use `vim.cmd[[ ... ]]`** if a native `vim.api` or `vim.keymap` Lua abstraction exists.
- **Never use `vim.loop`** — always use `vim.uv`.
- **Never use `vim.fn.system()` or `io.popen()`** for process execution.
- Never pollute `_G` or any global namespace. All state lives in module-local variables.
- Never error at plugin load time due to a missing Java toolchain binary.
- Never write files to disk before all validation (project name, location permissions) has passed.
