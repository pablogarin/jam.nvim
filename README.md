<p align="center">
  <img src="assets/logo_banner.png" alt="jam.nvim" width="100%"/>
</p>

<p align="center">
  <strong>Java Application Manager for Neovim</strong><br/>
  Scaffold, build, run, test, and fix imports — without leaving your editor.
</p>

<p align="center">
  <a href="#installation">Installation</a> ·
  <a href="#usage">Usage</a> ·
  <a href="#commands">Commands</a> ·
  <a href="#configuration">Configuration</a> ·
  <a href="#lsp-integration">LSP Integration</a>
</p>

---

## Overview

**jam.nvim** (Java Application Manager) is a Neovim plugin that manages the full Java development lifecycle from inside the editor. It handles project scaffolding, compilation, running, test generation, and import organisation — all driven by a single `:Jam` command with no external tooling required beyond your JDK and build tool.

- **Scaffold** a Maven or Gradle project with a single command
- **Build** with `mvn compile` / `gradle classes` / `javac`, output streamed to a scratch buffer
- **Run** your main class immediately after a successful build
- **Test** the current file: run its test counterpart or generate a JUnit 5 boilerplate if it doesn't exist
- **Fix imports** via jdtls (optional) with `:Jam imports`

---

## Requirements

- Neovim 0.11+
- A JDK on `$PATH` or `$JAVA_HOME` set (Java 11+ recommended)
- Maven and/or Gradle installed if you use those build tools

---

## Installation

### lazy.nvim

```lua
{
  "pablogarin/jam.nvim",
  config = function()
    require("jam").setup()
  end,
}
```

### packer.nvim

```lua
use {
  "pablogarin/jam.nvim",
  config = function()
    require("jam").setup()
  end,
}
```

### vim-plug

```vim
Plug 'pablogarin/jam.nvim'
lua require("jam").setup()
```

---

## Optional Dependencies

### nvim-jdtls (LSP features)

For autocomplete, go-to-definition, and `:Jam imports`, install [nvim-jdtls](https://github.com/mfussenegger/nvim-jdtls) and the Eclipse JDT Language Server:

```
:MasonInstall jdtls
```

Then add `mfussenegger/nvim-jdtls` to your plugin manager. jam.nvim detects it automatically — no extra configuration required. If nvim-jdtls is absent, a one-time warning will appear the first time you open a Java file; all other features continue to work normally.

---

## Usage

### Project Creation

<p align="center">
  <img src="assets/gifs/create.gif" alt="Creating a new Java project"/>
  <br/><em>Scaffolding a new Maven project with defaults</em>
</p>

Run `:Jam create` from anywhere in Neovim. You will be prompted for:

1. **Project name** — validated against filesystem rules
2. **Location** — defaults to the current working directory
3. **Package name** — defaults to `org.example.<name>`
4. **Build tool** — Maven (default), Gradle, or none
5. **Entry point** — optionally generate `Main.java` with a `Hello, World!` main method
6. **VCS** — optionally run `git init` and write a `.gitignore`

After creation, the working directory switches to the new project root and `Main.java` opens automatically.

---

### Build

<p align="center">
  <img src="assets/gifs/build.gif" alt="Building a Java project"/>
  <br/><em>Compiling a Maven project and viewing streamed output</em>
</p>

```
:Jam build
```

Compiles the project using the detected build tool. Output is streamed in real time to the `[jam:build]` scratch buffer that opens at the bottom of the screen. An `INFO` notification confirms success; `ERROR` is shown on failure.

| Build tool | Command issued |
|------------|---------------|
| Maven      | `mvn compile` |
| Gradle     | `gradle classes` |
| None       | `javac -d target/classes src/**/*.java` |

---

### Build & Run

<p align="center">
  <img src="assets/gifs/run.gif" alt="Building and running a Java project"/>
  <br/><em>Running a project after a successful build</em>
</p>

```
:Jam run
```

Builds first; if the build succeeds, resolves the main class and executes it. The main class is found by (in order):

1. A `mainClass` key in `.jam.json` at the project root
2. The first `Main.java` found under `src/main/java/`, reading its `package` declaration
3. A prompt asking you for the fully-qualified class name

Program output is streamed to the same `[jam:build]` buffer.

---

### Testing

<p align="center">
  <img src="assets/gifs/test-run.gif" alt="Running tests for the current file"/>
  <br/><em>Running the test counterpart for the current source file</em>
</p>

<p align="center">
  <img src="assets/gifs/test-generate.gif" alt="Generating a JUnit 5 test boilerplate"/>
  <br/><em>Generating a JUnit 5 scaffold when no test file exists yet</em>
</p>

```
:Jam test
```

With a Java source file open inside `src/main/java/`:

- If a test counterpart exists (e.g. `FooTest.java` for `Foo.java`), it is run immediately.
- If no test exists, a JUnit 5 boilerplate is generated, saved to `src/test/java/`, and opened in the current buffer with the cursor placed on the `// TODO` placeholder.

| Build tool | Command issued |
|------------|---------------|
| Maven      | `mvn test -Dtest=<ClassName>` |
| Gradle     | `gradle test --tests <fqcn>` |
| None       | JUnit Platform Console Standalone |

Exit code mapping: `0` → INFO, `1` → WARN (test failures), `≥ 2` → ERROR (runner error).

---

### Import Organisation

<p align="center">
  <img src="assets/gifs/imports.gif" alt="Organising imports with jdtls"/>
  <br/><em>Removing unused imports and sorting the import block via jdtls</em>
</p>

```
:Jam imports
```

Requires nvim-jdtls to be installed and attached. Triggers the `source.organizeImports` code action — unused imports are removed and the import block is sorted. If jdtls is not attached, a descriptive `ERROR` notification explains why.

---

## Commands

| Command | Description |
|---------|-------------|
| `:Jam create` | Run the new-project wizard |
| `:Jam build` | Compile the current project |
| `:Jam run` | Build then run the main class |
| `:Jam test` | Run or generate tests for the current file |
| `:Jam imports` | Organise imports via jdtls (requires nvim-jdtls) |

Tab completion is available for all subcommands.

---

## Configuration

`setup()` accepts an optional table. All keys are optional; the defaults shown below are used when a key is omitted.

```lua
require("jam").setup({
  -- Default build tool used when creating a new project.
  -- One of: "maven" | "gradle" | "none"
  default_build_tool = "maven",

  -- Default workspace directory for new projects.
  -- nil means "use the current working directory".
  default_workspace = nil,

  -- Run `git init` by default when creating a new project.
  git_init = true,

  -- Generate a Main.java entry point by default when creating a new project.
  inject_main = true,
})
```

---

## LSP Integration

When nvim-jdtls is installed, jam.nvim attaches the language server automatically every time a Java file is opened inside a recognised project root (one that contains a `pom.xml`, `build.gradle`, or `.git`).

The workspace data directory is set to:
```
<stdpath("data")>/jam-workspaces/<sha256(project_root)>
```

This keeps each project's index isolated without any manual configuration.

If nvim-jdtls is not installed, you will see a single `WARN` notification per Neovim session explaining what is missing and providing the exact install command. No other behaviour is affected.

---

## Project Root Detection

jam.nvim walks upward from the active buffer's directory until it finds one of:

| Marker | Detected tool |
|--------|--------------|
| `pom.xml` | Maven |
| `build.gradle` | Gradle |
| `.git` (only) | None |

The search stops at the first match. If no marker is found before the filesystem root, an `ERROR` is shown.

---

## License

MIT
