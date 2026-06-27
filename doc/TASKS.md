# Java Application Manager — User Stories & Tasks

## User Stories

**Project Name**
- As a user, if I invoke the create project command and provide only a project name, the result should be a fully scaffolded, compilation-ready Java project using all defaults.
- As a user, if I enter a project name containing spaces or characters invalid for the filesystem, the result should be a validation error and no files should be written.
- As a user, if I submit an empty project name, the result should be a validation error prompting me to provide a name.

**Project Location**
- As a user, if I skip specifying a project location, the result should be the project created under my current working directory (or the configured default workspace).
- As a user, if I specify a project location that does not yet exist, the result should be those directories created automatically before scaffolding proceeds.
- As a user, if I specify a project location where I lack write permissions, the result should be a clear error before any files are written.

**VCS Initialization**
- As a user, if I create a project without disabling VCS, the result should be a git repository initialized inside the project root with a Java-appropriate `.gitignore`.
- As a user, if I disable VCS via the advanced options, the result should be a project with no `git init` executed and no `.gitignore` generated.

**JDK Detection**
- As a user, if I create a project without specifying a JDK, the result should be the active system Java version (resolved from `$JAVA_HOME` or the first `javac` on `$PATH`) recorded in the project configuration.

**Build Tool**
- As a user, if I create a project without specifying a build tool, the result should be a Maven project with a valid `pom.xml`.
- As a user, if I select Gradle as the build tool in advanced options, the result should be a Gradle project structure instead of Maven.
- As a user, if I select "No Build Tools" in advanced options, the result should be a project with no build configuration file.

**Package Name**
- As a user, if I create a project without specifying a package name, the result should be the package set to `org.example.<projectname>` (lowercased, sanitized).
- As a user, if I provide a custom package name in advanced options, the result should be the directory tree and boilerplate reflecting that package exactly.

**Scaffolding**
- As a user, if I complete the creation wizard, the result should be the full Maven directory tree (`src/main/java/...`, `src/main/resources/`, `src/test/java/`) present on disk.

**Entry Point**
- As a user, if I create a project with defaults, the result should be a `Main.java` file placed inside the resolved package directory containing a runnable `main()` method.
- As a user, if I disable the entry point option in advanced options, the result should be an empty project tree with no `Main.java` generated.

**Build**
- As a user, if I run `:Jam build` inside a Maven project, the result should be the project compiled with `mvn compile` and output streamed to a dedicated scratch buffer. → T-19, T-20, T-21
- As a user, if I run `:Jam build` inside a Gradle project, the result should be the project compiled with `gradle classes`. → T-19, T-21
- As a user, if I run `:Jam build` with no build tool configured, the result should be all `*.java` files under `src/` compiled with `javac` into `target/classes/`. → T-19, T-21
- As a user, if the build succeeds, the result should be an INFO notification confirming success. → T-21
- As a user, if the build fails, the result should be an ERROR notification with the exit code, and the full compiler output visible in the scratch buffer. → T-20, T-21
- As a user, if I run `:Jam build` outside a recognised project root, the result should be a clear ERROR notification and no compilation attempted. → T-19, T-21

**Build & Run**
- As a user, if I run `:Jam run` and the build succeeds, the result should be the main class executed immediately and its output streamed to the scratch buffer. → T-22, T-23
- As a user, if I run `:Jam run` and the build fails, the result should be the run step skipped entirely, with only a build-failure ERROR shown. → T-23
- As a user, if no main class can be inferred automatically, the result should be a prompt asking me for the fully-qualified class name before execution proceeds. → T-22

**Testing**
- As a user, if I run `:Jam test` on a source file that has an existing test counterpart, the result should be only that test class executed using the project's build tool. → T-24, T-25
- As a user, if I run `:Jam test` on a source file with no test counterpart, the result should be a JUnit 5 test file created, scaffolded with a placeholder test, and opened in the active buffer. → T-24, T-26
- As a user, if I run `:Jam test` outside a `src/main/java/` tree, the result should be a clear ERROR notification with no side effects. → T-24, T-25
- As a user, if all tests pass, the result should be an INFO notification. → T-25
- As a user, if any tests fail, the result should be a WARN notification and full test output visible in the test scratch buffer. → T-25

**LSP Integration**
- As a user, if nvim-jdtls is installed and I open a Java file inside a recognised project root, the result should be jdtls automatically attached with no manual configuration required. → T-27, T-28
- As a user, if nvim-jdtls is not installed and I open a Java file inside a project root, the result should be a single WARN notification per session explaining what is missing and providing the exact install command. → T-27
- As a user, if jdtls is attached and I accept a completion for a class that requires an import, the result should be the import statement automatically inserted at the top of the file. → T-28
- As a user, if I run `:Jam imports` with jdtls attached, the result should be unused imports removed and the import block sorted. → T-29
- As a user, if I run `:Jam imports` without jdtls attached, the result should be a clear ERROR notification explaining why the feature is unavailable. → T-29

---

## Tasks

### T-01 — Register `:JamCreate` command
- Add a `:JamCreate` user command in the plugin entry point that calls a `create.lua` module.
- No logic yet — just a stub that prints "create triggered".

### T-02 — Project name prompt
- Open a `vim.ui.input` prompt asking for the project name.
- Store the raw string for downstream validation.

### T-03 — Project name validation
- Reject empty strings (show error and abort).
- Reject strings containing characters illegal on the filesystem (spaces, `/ \ : * ? " < > |`).
- Return the validated name or an error message.

### T-04 — Project location resolution
- Default: resolve to `cwd .. "/" .. project_name`.
- Accept an optional override path from the caller.
- Expand `~` and environment variables in the resolved path.

### T-05 — Project location validation
- Check that the resolved path does not already exist (abort with error if it does).
- Check write permission on the parent directory.
- Create the full path with `vim.fn.mkdir(..., "p")` if it does not exist.

### T-06 — JDK detection
- Read `$JAVA_HOME`; fall back to `which javac`.
- Store the resolved java binary path.
- Warn (but do not abort) if no Java is found.

### T-07 — Package name inference
- Default: lowercase the project name, strip non-alphanumeric characters, prepend `org.example.`.
- Expose a `package_name_to_path(pkg)` helper that converts dots to `/`.

### T-08 — Maven directory scaffolding
- Given the project root and the resolved package path, create:
  - `src/main/java/<pkg_path>/`
  - `src/main/resources/`
  - `src/test/java/`

### T-09 — `pom.xml` generation
- Write a minimal `pom.xml` to the project root.
- Populate `<groupId>`, `<artifactId>`, and `<version>` from the resolved values.
- Hard-code Java source/target version from the detected JDK major version.

### T-10 — `Main.java` boilerplate injection
- Write `Main.java` into `src/main/java/<pkg_path>/`.
- Contents: correct `package` declaration + `public class Main` with a `main()` that prints `Hello, World!`.

### T-11 — Git initialization
- Run `git init` inside the project root via `vim.fn.jobstart`.
- Write a `.gitignore` covering common Java/Maven artifacts (`target/`, `*.class`, `*.jar`, `*.iml`, `.idea/`).

### T-12 — Advanced options menu (build tool)
- Before scaffolding, optionally open a `vim.ui.select` prompt: `["Maven (default)", "Gradle", "No Build Tools"]`.
- Wire the selection into the scaffolding step (T-08/T-09).

### T-13 — Advanced options menu (VCS + entry point toggles)
- Add toggles for "Skip git init" and "Skip Main.java" to the advanced options flow.
- Pass the flags into T-11 and T-10 respectively.

### T-14 — Advanced options: custom location and package name
- Let the user override the project location (T-04) and package name (T-07) via additional prompts in the advanced options flow.

### T-15 — Gradle scaffolding support
- When Gradle is selected: create `build.gradle` + `settings.gradle` instead of `pom.xml`.
- Adjust directory layout if needed (Gradle uses the same Maven standard layout).

### T-16 — End-to-end integration test (manual)
- Run `:JamCreate`, accept all defaults, and verify:
  - Directory tree matches the PRD matrix.
  - `pom.xml` is valid XML.
  - `Main.java` compiles with `javac`.
  - `git log` shows an initial state.

### T-17 — Open project root in Neovim after creation
- After scaffolding succeeds, change the working directory to the new project root (`vim.cmd("cd " .. root)`) and optionally open `Main.java` in the current buffer.

### T-18 — User-facing notifications
- Replace all `print()` calls with `vim.notify()` using appropriate log levels (`INFO` for success, `WARN` for missing JDK, `ERROR` for validation failures).

---

### T-19 — Project root and build tool detection (FR-4.1)
- Create `lua/jam/project.lua` with a `find_root()` function.
- Walk upward from the active buffer's directory (falling back to cwd) until `pom.xml`, `build.gradle`, or `.git` is found.
- Return `{ root = <path>, tool = "maven"|"gradle"|"none" }`, where `tool` is determined by the first build descriptor found (`pom.xml` → maven, `build.gradle` → gradle, `.git` only → none).
- Return `nil` if no marker is found; callers are responsible for emitting the ERROR notification.
- Expose `M._find_root` for unit tests via injectable `stat_fn` parameter.

### T-20 — Output scratch buffer (FR-4.2)
- Create `lua/jam/output.lua` with:
  - `get_or_create(name)` — returns an existing scratch buffer by that name or creates a new `nofile`/`noswap` one.
  - `open(buf)` — opens the buffer in a bottom split, reusing the window if already visible.
  - `append(buf, lines)` — appends a list of strings to the buffer.
  - `clear(buf)` — wipes the buffer content.
- Buffer names follow the pattern `[jam:build]` and `[jam:test]`.
- Tests: buffer is created with correct `buftype`; a second `get_or_create` call returns the same buffer number; `append` and `clear` behave correctly.

### T-21 — `:Jam build` command (FR-4.2)
- Add `build` as a recognised subcommand in `lua/jam/init.lua`.
- Create `lua/jam/build.lua` with a `build(callback)` function that:
  - Calls `project.find_root()`; emits ERROR and returns if nil.
  - Opens and clears the `[jam:build]` output buffer.
  - Spawns the correct command asynchronously via `vim.uv.spawn`, streaming stdout and stderr lines to the buffer via `vim.uv.read_start`.
  - Calls `callback(ok, exit_code)` on process exit; the default callback emits INFO on exit 0, ERROR otherwise.
- Command mapping: `maven` → `mvn compile`, `gradle` → `gradle classes`, `none` → `javac` (all `*.java` under `src/`, `-d target/classes/`).
- Tests: correct argv per tool; INFO notification on exit 0; ERROR notification on non-zero exit; output buffer is opened; root-not-found path emits ERROR without spawning.

### T-22 — Main class resolution (FR-4.3)
- Add `M.resolve_main_class(root, callback)` to `lua/jam/build.lua`.
- Resolution order:
  1. Read `.jam.json` at `root` and return the `mainClass` key if present.
  2. Find the first `Main.java` under `root/src/main/java/`, read its `package` declaration line, and assemble the FQCN (`<package>.Main`).
  3. Fall back to `vim.ui.input` asking for a fully-qualified class name; cancellation aborts silently.
- Expose `M._resolve_main_class` for tests with injectable `read_fn` and `find_fn` parameters.
- Tests: `.jam.json` key returned first; `Main.java` scan produces correct FQCN; prompt used when neither source exists; cancellation returns nil without error.

### T-23 — `:Jam run` command (FR-4.3)
- Add `run` as a recognised subcommand in `lua/jam/init.lua`.
- Add `M.run()` to `lua/jam/build.lua` that:
  - Calls `build()` internally; if exit code is non-zero, stops.
  - On success calls `resolve_main_class()`; if nil (user cancelled), stops.
  - Clears and reopens `[jam:build]`, then spawns the run command, streaming output to the same buffer.
- Run command mapping: `maven` → `mvn exec:java -Dexec.mainClass=<class>`, `gradle` → `gradle run`, `none` → `java -cp target/classes <class>`.
- Tests: run not spawned when build exits non-zero; correct run argv per tool; main class correctly interpolated into the command.

### T-24 — Test file mapping (FR-5.1)
- Create `lua/jam/test.lua` with `M.map_to_test(buf_path, root)`.
- Verify `buf_path` is under `<root>/src/main/java/`; return nil + error string if not.
- Derive: relative package path, class name (basename without `.java`), test class name (`<ClassName>Test`), test file path (`<root>/src/test/java/<pkg>/<ClassName>Test.java`), and FQCN.
- Return `{ test_path, class_name, fqcn, exists }` where `exists` is a `vim.uv.fs_stat` check.
- Expose `M._map_to_test` for unit tests.
- Tests: correct mapping for a nested package path; `Test` suffix applied to class name; `exists` reflects real filesystem state; nil returned with error for paths outside `src/main/java/`.

### T-25 — `:Jam test` — run tests for current file (FR-5.2)
- Add `test` as a recognised subcommand in `lua/jam/init.lua`.
- Add `M.run_tests(root, tool, fqcn)` to `lua/jam/test.lua` that:
  - Opens and clears the `[jam:test]` output buffer.
  - Spawns the test command asynchronously, streaming output to the buffer.
  - On exit: INFO if exit 0, WARN if exit 1 (test failures), ERROR for exit ≥ 2 (build/runner error).
- Test command mapping: `maven` → `mvn test -Dtest=<ClassName>`, `gradle` → `gradle test --tests "<fqcn>"`, `none` → JUnit Platform Console Standalone launcher.
- The `:Jam test` handler calls `map_to_test()` first; if `exists` is true, delegates to `run_tests()`; otherwise delegates to `generate_test()` (T-26).
- Tests: correct argv per tool; exit-code-to-notification-level mapping; output buffer opened and populated.

### T-26 — `:Jam test` — generate test boilerplate (FR-5.3)
- Add `M.generate_test(test_path, pkg, class_name)` to `lua/jam/test.lua`.
- Create any missing parent directories under `src/test/java/`.
- Write a JUnit 5 template: correct `package` declaration, `import` lines, class named `<ClassName>Test`, one `@Test void exampleTest()` with a `// TODO` body.
- Open the new file in the active buffer via `vim.cmd.edit(test_path)`.
- Position the cursor on the `// TODO` line using `vim.api.nvim_win_set_cursor`.
- Emit INFO notification with the created file path.
- Tests: file written with correct package and class name; JUnit 5 imports present; cursor positioned on the TODO line (check via `M._cursor_line` injectable).

### T-27 — nvim-jdtls detection and session warning (FR-6.1)
- Create `lua/jam/lsp.lua`.
- Module-level `_warned` flag (reset only on Neovim restart) to suppress repeated warnings.
- `M.check()` — does a `pcall(require, "jdtls")`; returns `ok, mod`.
- `M.maybe_warn()` — calls `check()`; if absent and `_warned` is false, emits the WARN notification (exact text from FR-6.1) and sets `_warned = true`; returns whether jdtls is available.
- Expose `M._reset_warned()` for tests.
- Tests: WARN emitted when require fails; WARN suppressed on second call; no error thrown; returns true/false correctly.

### T-28 — Automatic LSP attachment (FR-6.2)
- In `M.setup()` (`lua/jam/init.lua`), register an `autocmd FileType java` that calls `lsp.attach_if_project(buf)`.
- `M.attach_if_project(buf)` in `lua/jam/lsp.lua`:
  - Calls `maybe_warn()`; if jdtls unavailable, returns.
  - Calls `project.find_root()` from the buffer's directory; if nil, returns silently.
  - Constructs the jdtls config: `root_dir`, `java` binary from `detect.find_java()`, `data` path as `vim.fn.stdpath("data") .. "/jam-workspaces/" .. vim.fn.sha256(root)`.
  - Calls `require("jdtls").start_or_attach(config)`.
- Tests: `start_or_attach` called with correct `root_dir` and `data` path; skipped when not in a project root; skipped when jdtls unavailable; workspace path differs for different project roots.

### T-29 — `:Jam imports` command (FR-6.3)
- Add `imports` as a recognised subcommand in `lua/jam/init.lua`.
- Handler checks: current buffer `filetype` is `java`; at least one active LSP client named `jdtls` is attached (`vim.lsp.get_clients`).
- If either check fails, emit ERROR with a specific reason ("not a Java file" or "jdtls not attached — is nvim-jdtls installed and are you inside a project root?").
- If both pass, execute the `java.action.organizeImports` command via `vim.lsp.buf.code_action` filtered to that action title.
- Tests: code action triggered when jdtls client present; ERROR emitted (with correct reason) when filetype is wrong; ERROR emitted when no jdtls client attached.
