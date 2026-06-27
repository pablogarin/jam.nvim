# Product Requirements Document (PRD)

## 1. Introduction & Objectives
The purpose of this document is to define the functional specifications for the **Java Project Creation Wizard**. This system prioritizes a zero-friction, minimalist configuration workflow that allows a user to scaffold a compilation-ready Java development environment using only a single mandatory input: the project name. 

All secondary operational configurations—such as path destinations, package architectures, and compilation runtimes—are silently inferred by system defaults. This ensures immediate progression from initiation to active development while retaining configuration toggles for advanced users.

---

## 2. Core User Workflow
The project initialization lifecycle uses an optimized, linear automated stream:

```
[User Action: Input Project Name] ---> [System: Infer Default Settings] ---> [Execution: Automatic Scaffolding & Code Injection]
```

1. **Minimalist Input**: The user provides a text string for the project identity. All other configurations are pre-populated with system defaults.
2. **Automated Inference**: The system resolves local path directories, selects the active system compiler, and configures the default package build scripts in the background.
3. **Scaffolding & Boilerplate Injection**: The engine writes the nested directory structures, drops the build tool configuration file, and injects a functional main method execution entry point file.

---

## 3. Functional Requirements

### 3.1 Phase 1: Project Metadata Elements
These requirements govern the identity constraints and structural pathways needed to create the project workspace.

#### `FR-1.1: Project Name Input`
* **Description**: A mandatory text entry field to title the application root folder.
* **Validation Rules**: Must reject spaces or special characters if restricted by the active file system. 
* **User Experience**: This is the only field required to trigger project generation.

#### `FR-1.2: Project Location Selector`
* **Description**: A configuration pointer declaring the destination path where the project directory will be written.
* **Default Behavior**: Inferred automatically based on the user's active working directory or a globally configured default workspace path (e.g., `~/projects/[Project Name]`).
* **Validation Rules**: Must verify directory write permissions prior to execution. If the path does not exist, the system safely creates it.

#### `FR-1.3: Version Control System (VCS) Initialization`
* **Description**: An automated baseline local repository option.
* **Default Behavior**: Enabled by default. The system automatically executes `git init` inside the new root directory and populates a default `.gitignore` file tracking common Java build artifacts.
* **User Control**: Can be explicitly disabled by the user via an advanced setting toggle before execution.

---

### 3.2 Phase 2: Environment & Core Configuration
These requirements handle the hidden structural and compilation architectures required to build and compile the application.

#### `FR-2.1: Java Development Kit (JDK) Pointer`
* **Description**: A selection mechanism to identify the target Java compiler and runtime version.
* **Default Behavior**: Inferred automatically by reading active system environment variables (targeting `$JAVA_HOME` or the first available system `javac` binary).

#### `FR-2.2: Project Build Tool Architecture Selector`
* **Description**: A choice determining how dependencies, packages, and compiling tasks are handled.
* **Default Behavior**: Pre-selected to **Maven**. The system initializes the environment using a standard Maven structure (`pom.xml`) out of the box.
* **User Control**: Can be explicitly modified by the user to "No Build Tools" or "Gradle" via an advanced options menu.

#### `FR-2.3: Java Structural Package Name Definition`
* **Description**: The base classpath directory architecture for source files.
* **Default Behavior**: Inferred automatically using a sanitized lowercase variant of the project name (e.g., `org.example.[projectname]`).
* **Validation Rules**: Standard reverse-domain-name naming syntax. Replaces periods (`.`) directly with nested folder separators (`/`) during physical scaffolding.

---

### 3.3 Phase 3: Project Generation & Automation
These requirements define the direct file tree outcomes and initial codebase state upon completion.

#### `FR-3.1: Base Structure Directory Scaffolding`
* **Description**: Generates the exact Maven directory trees using the variables defined in Phase 1 and Phase 2.
* **Inferred Output Matrix**:
  ```text
  [Project Root]/
  ├── .gitignore
  ├── pom.xml
  └── src/
      ├── main/
      │   ├── java/
      │   │   └── org/
      │   │       └── example/
      │   │           └── [projectname]/
      │   └── resources/
      └── test/
          └── java/
  ```

#### `FR-3.2: Bootstrap Entry Point Injection`
* **Description**: Automatically injects a functional boilerplate entry point file to allow immediate code execution.
* **Default Behavior**: Enabled by default. Generates a `Main.java` class inside the base package directory containing a runnable main method.
* **User Control**: Can be explicitly disabled via a configuration option if the user prefers an empty project tree.
* **Boilerplate Layout**:
  ```java
  package org.example.projectname;

  public class Main {
      public static void main(String[] args) {
          System.out.println("Hello, World!");
      }
  }
  ```

---

### 3.4 Phase 4: Build & Run
These requirements govern compilation and execution of an existing Java project from within Neovim.

#### `FR-4.1: Project Context Detection`
* **Description**: Before any build or run action, the system must locate the project root and identify the active build tool.
* **Detection Strategy**: Walk upward from the current working directory (or the directory of the active buffer) until a `pom.xml`, `build.gradle`, or `.git` directory is found.  The first build descriptor encountered determines the build tool (`pom.xml` → Maven, `build.gradle` → Gradle, neither → bare `javac`).
* **Failure Behavior**: If no project root can be identified, emit an `ERROR` notification and abort.

#### `FR-4.2: Build Command`
* **Description**: Compiles the project using the build tool identified by `FR-4.1`.
* **Command Mapping**:

  | Build Tool | Compilation Command |
  | :--- | :--- |
  | Maven | `mvn compile` |
  | Gradle | `gradle classes` |
  | None (bare javac) | `javac` on all `*.java` files under `src/`, output to `target/classes/` |

* **Output**: Compiler output is streamed into a dedicated scratch buffer (`:Jam build output`) that opens automatically. The buffer is reused across invocations.
* **Notification**: On completion, a single `INFO` notification reports success ("Build succeeded") or an `ERROR` notification reports failure with the exit code ("Build failed (exit 1)").
* **Async Execution**: Compilation runs asynchronously via `vim.uv.spawn` so the editor remains responsive.

#### `FR-4.3: Build and Run Command`
* **Description**: Compiles the project and, upon successful compilation, immediately runs the main class.
* **Prerequisite**: Compilation must succeed (exit code 0) before execution is attempted.
* **Main Class Resolution**: The main class is inferred in priority order:
  1. A `mainClass` key in a plugin configuration file (`.jam.json`) at the project root.
  2. The first file named `Main.java` found under `src/main/java/`, with its package derived from the `package` declaration.
  3. A `vim.ui.input` prompt asking the user for the fully-qualified class name.
* **Run Command Mapping**:

  | Build Tool | Run Command |
  | :--- | :--- |
  | Maven | `mvn exec:java -Dexec.mainClass=<class>` |
  | Gradle | `gradle run` (requires the `application` plugin) |
  | None (bare javac) | `java -cp target/classes <class>` |

* **Output**: Program output is streamed into the same scratch buffer used by the build step (`:Jam build output`), cleared before each new run.

---

### 3.5 Phase 5: Testing
These requirements govern test execution and test-file scaffolding for source files open in the active buffer.

#### `FR-5.1: Test File Mapping`
* **Description**: The system maps any source file under `src/main/java/` to its canonical test counterpart under `src/test/java/` using the standard Java convention: the class name is suffixed with `Test` and the package structure is mirrored exactly.
* **Example**:
  ```
  src/main/java/org/example/app/UserService.java
         ↓  maps to
  src/test/java/org/example/app/UserServiceTest.java
  ```
* **Failure Behavior**: If the active buffer is not inside a recognisable `src/main/java/` tree, emit an `ERROR` notification and abort.

#### `FR-5.2: Run Tests for Current File`
* **Description**: When the test counterpart identified by `FR-5.1` already exists on disk, execute only the tests contained in that file.
* **Command Mapping**:

  | Build Tool | Test Command |
  | :--- | :--- |
  | Maven | `mvn test -Dtest=<TestClassName>` |
  | Gradle | `gradle test --tests "<fully.qualified.TestClassName>"` |
  | None (bare javac) | Compile with JUnit on classpath, then `java org.junit.platform.console.standalone.ConsoleLauncher --select-class=<class>` |

* **Output**: Test output is streamed into a dedicated scratch buffer (`:Jam test output`), reused across invocations.
* **Notification**: `INFO` on all-pass ("Tests passed"), `WARN` on partial failure, `ERROR` on build or runner failure.

#### `FR-5.3: Generate Test Boilerplate`
* **Description**: When the test counterpart identified by `FR-5.1` does **not** exist, the command creates the test file with a JUnit 5 bootstrap instead of running tests.
* **Default Test Framework**: JUnit 5 (`org.junit.jupiter`).
* **Boilerplate Layout**:
  ```java
  package org.example.app;

  import org.junit.jupiter.api.Test;
  import static org.junit.jupiter.api.Assertions.*;

  class UserServiceTest {

      @Test
      void exampleTest() {
          // TODO: write test
      }
  }
  ```
* **Post-creation**: The newly created test file is opened in the active buffer and the cursor is positioned inside the example test method body.
* **Notification**: `INFO` notification confirms the file path of the generated test.

---

### 3.6 Phase 6: LSP Integration (Optional)
These requirements govern IDE-grade language intelligence — completions, auto-import, and diagnostics — powered by the Eclipse JDT Language Server (jdtls). This entire phase is **optional**: all features in Phases 1–5 function without it. When the optional dependency is absent the plugin communicates this clearly rather than failing silently.

#### `FR-6.1: Optional Dependency Declaration`
* **Runtime dependency**: `nvim-jdtls` (`mfussenegger/nvim-jdtls`).
* **Detection**: On the first `FileType java` event inside a recognised project root, jam.nvim checks for the dependency via a protected `require("jdtls")` call.
* **If absent**: A single `WARN` notification is emitted per Neovim session (not per buffer) stating that LSP features are unavailable and providing the exact install instruction:
  ```
  [jam] LSP features require nvim-jdtls.
  Install via Mason: :MasonInstall jdtls  (plugin: mfussenegger/nvim-jdtls)
  LSP will not be started until it is installed.
  ```
  No further action is taken; the buffer opens normally without LSP.
* **If present**: Proceed with `FR-6.2`.

#### `FR-6.2: Automatic LSP Attachment`
* **Description**: When nvim-jdtls is detected, jam.nvim auto-attaches jdtls to every Java buffer that belongs to a recognised project root (identified by the walk-up logic defined in `FR-4.1`).
* **jam.nvim's contribution to the jdtls config**:
  * `root_dir` — the project root resolved by `FR-4.1`.
  * `java` executable path — resolved by the existing `detect.lua` module (`FR-2.1`).
  * `data_dir` — a per-project workspace path derived by hashing the project root, stored under `vim.fn.stdpath("data") .. "/jam-workspaces/<hash>"`. This prevents workspace collisions between projects.
* **nvim-jdtls's responsibility**: launcher JAR discovery, OSGi JVM arguments, platform-specific config directory selection, and all workspace lifecycle management.
* **Trigger**: An `autocmd FileType java` registered during `setup()`. If the buffer is not under a recognised project root the autocmd does nothing (no LSP, no warning).

#### `FR-6.3: Completion and Auto-Import`
* **Description**: Once jdtls is attached, standard Neovim LSP completion (`textDocument/completion`) is available. Completion items for classes that require an `import` statement carry `additionalTextEdits` that insert the import automatically when the item is accepted — this is handled transparently by Neovim's LSP client and requires no extra code in jam.nvim.
* **Dependency classpath**: jdtls reads `pom.xml` / `build.gradle` directly and resolves dependencies through Maven's and Gradle's own tooling APIs. jam.nvim does not need to enumerate or pass dependencies manually.
* **Organize imports**: jam.nvim exposes a `:Jam imports` subcommand that fires the `java.action.organizeImports` jdtls code action on the current buffer, removing unused imports and sorting the import block.
* **Availability guard**: `:Jam imports` checks that jdtls is attached to the current buffer before acting; if not, it emits an `ERROR` notification explaining why (not in a Java file, or nvim-jdtls not installed).

---

### 3.7 Phase 7: Floating UI

#### `FR-7.1: Floating Input Dialog`
* **Description**: Every text prompt in jam.nvim (project name, location, package name, main class) is presented in a centered floating window with a rounded border, completely bypassing the native command-line input (`vim.ui.input`) and any third-party overrides such as noice.nvim.
* **Keyboard contract**: The window opens in insert mode. `<CR>` confirms the input and closes the window; `<Esc>` cancels and closes the window with no side effects.
* **Implementation**: `lua/jam/ui.lua` exposes `M.input(opts, callback)` with the same signature as `vim.ui.input` so it can be used as a drop-in replacement inside jam modules.

#### `FR-7.2: Floating Selection Dialog`
* **Description**: Every selection prompt (build tool, yes/no toggles) is presented in a centered floating window listing the available options, one per line, with the first item highlighted. No mouse interaction is required.
* **Keyboard contract**: `j` / `<Down>` moves the highlight down; `k` / `<Up>` moves it up. `<CR>` confirms the highlighted item; `<Esc>` or `q` cancels. Navigation wraps at the top and bottom of the list.
* **Implementation**: `M.select(items, opts, callback)` in `lua/jam/ui.lua`, with the same signature as `vim.ui.select`.

---

## 4. Platform Implementation Matrix
This matrix maps how the minimalist wizard's functional lifecycle processes user interactions versus automated fallback values:

| Feature ID | Feature Name | User Interaction | Automated Fallback / Default System Behavior |
| :--- | :--- | :--- | :--- |
| **`FR-1.1`** | Project Name | Mandatory Text Input | *None (Fails validation if left blank)* |
| **`FR-1.2`** | Project Location | Skipped by default | Infers path via current system path or home root directory |
| **`FR-1.3`** | VCS Setup | Skipped by default | Automatically runs `git init` and generates `.gitignore` |
| **`FR-2.2`** | Build Tool | Skipped by default | Sets to **Maven** and targets production of a baseline `pom.xml` |
| **`FR-2.3`** | Package Name | Skipped by default | Synthesizes standard string mapping: `org.example.[projectname]` |
| **`FR-3.2`** | Entry Point | Skipped by default | Injects fully qualified `Main.java` with a active `main()` method |
| **`FR-4.1`** | Project Root | Automatic | Walk-up search from cwd/buffer dir for `pom.xml`, `build.gradle`, `.git` |
| **`FR-4.2`** | Build | Single command | Selects `mvn compile` / `gradle classes` / `javac` based on detected tool |
| **`FR-4.3`** | Build & Run | Single command | Builds then resolves main class and runs; prompts if class cannot be inferred |
| **`FR-5.1`** | Test Mapping | Automatic | Mirrors `src/main/java/` path into `src/test/java/` with `Test` suffix |
| **`FR-5.2`** | Run Tests | Single command | Runs only the test class matching the current buffer |
| **`FR-5.3`** | Generate Test | Single command (when no test file exists) | Creates JUnit 5 bootstrap and opens it in the active buffer |
| **`FR-6.1`** | nvim-jdtls presence | None required | Detected automatically; single WARN per session if absent, no silent failure |
| **`FR-6.2`** | LSP Attachment | None required | Auto-attaches jdtls on `FileType java` inside a project root; skipped otherwise |
| **`FR-6.3`** | Completions & Imports | `:Jam imports` for organise | Completions + import insertion via standard LSP; classpath resolved by jdtls itself |
| **`FR-7.1`** | Floating Input | Keyboard: `<CR>` confirm, `<Esc>` cancel | Replaces `vim.ui.input`; centered floating window, insert mode, rounded border |
| **`FR-7.2`** | Floating Selection | Keyboard: `j`/`k` navigate, `<CR>` confirm, `<Esc>`/`q` cancel | Replaces `vim.ui.select`; centered floating window, first item pre-highlighted |

