local M = {}

-- Characters forbidden by common filesystems (FAT, NTFS, ext* on Linux/macOS
-- as used via Neovim). The pattern matches any of: space / \ : * ? " < > |
local ILLEGAL_PAT = '[%s/\\:*?"<>|]'

local GITIGNORE = table.concat({
  "# Maven",
  "target/",
  "",
  "# Gradle",
  "build/",
  ".gradle/",
  "",
  "# Compiled output",
  "*.class",
  "*.jar",
  "*.war",
  "*.ear",
  "",
  "# IDE",
  "*.iml",
  ".idea/",
  "out/",
  "",
}, "\n")

---T-03: Validate a raw project name.
---@param raw string
---@return string|nil name, string|nil err
local function validate_name(raw)
  if raw == "" then
    return nil, "project name cannot be empty"
  end
  if raw:find(ILLEGAL_PAT) then
    return nil, 'project name contains illegal characters (spaces and /\\:*?"<>| are not allowed)'
  end
  return raw, nil
end

---T-04: Resolve the project root path.
---Uses cwd/name by default; expands ~ and env vars in any override.
---@param name string
---@param override? string
---@return string
local function resolve_location(name, override)
  local raw = override or (vim.uv.cwd() .. "/" .. name)
  return vim.fn.expand(raw)
end

---T-07: Infer a default Java package name from the project name.
---Lowercases, strips non-alphanumeric chars, guards against digit-leading segments.
---@param name string
---@return string
local function infer_package(name)
  local seg = name:lower():gsub("[^a-z0-9]", "")
  if seg == "" then
    seg = "app"
  elseif seg:match("^%d") then
    seg = "p" .. seg
  end
  return "org.example." .. seg
end

---T-07: Convert a dotted package name to a filesystem path.
---@param pkg string e.g. "org.example.myproject"
---@return string e.g. "org/example/myproject"
local function package_to_path(pkg)
  return (pkg:gsub("%.", "/"))
end

---T-09: Render a minimal Maven pom.xml.
---@param artifact_id string
---@param pkg string Full package name, e.g. "org.example.myproject"
---@param java_version integer JDK major version, e.g. 17
---@return string
local function pom_xml(artifact_id, pkg, java_version)
  local parts = vim.split(pkg, ".", { plain = true })
  table.remove(parts)
  local group_id = table.concat(parts, ".")

  return string.format(
    [[<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0
         http://maven.apache.org/xsd/maven-4.0.0.xsd">
  <modelVersion>4.0.0</modelVersion>

  <groupId>%s</groupId>
  <artifactId>%s</artifactId>
  <version>1.0-SNAPSHOT</version>
  <packaging>jar</packaging>

  <properties>
    <maven.compiler.source>%d</maven.compiler.source>
    <maven.compiler.target>%d</maven.compiler.target>
    <project.build.sourceEncoding>UTF-8</project.build.sourceEncoding>
  </properties>
</project>
]],
    group_id,
    artifact_id,
    java_version,
    java_version
  )
end

---T-10: Render a Main.java boilerplate.
---@param pkg string Full package name, e.g. "org.example.myproject"
---@return string
local function main_java(pkg)
  return string.format(
    [[package %s;

public class Main {
    public static void main(String[] args) {
        System.out.println("Hello, World!");
    }
}
]],
    pkg
  )
end

---T-15: Render a minimal Gradle build.gradle.
---@param pkg string Full package name, e.g. "org.example.myproject"
---@param java_version integer JDK major version, e.g. 17
---@return string
local function build_gradle(pkg, java_version)
  local parts = vim.split(pkg, ".", { plain = true })
  table.remove(parts)
  local group_id = table.concat(parts, ".")

  return string.format(
    [[plugins {
    id 'java'
}

group = '%s'
version = '1.0-SNAPSHOT'

java {
    sourceCompatibility = JavaVersion.VERSION_%d
    targetCompatibility = JavaVersion.VERSION_%d
}

repositories {
    mavenCentral()
}
]],
    group_id,
    java_version,
    java_version
  )
end

---T-15: Render a minimal Gradle settings.gradle.
---@param artifact_id string
---@return string
local function settings_gradle(artifact_id)
  return ("rootProject.name = '%s'\n"):format(artifact_id)
end

---@type string[]
local BUILD_TOOL_ITEMS = { "Maven (default)", "Gradle", "No Build Tools" }

---@type table<string, "maven"|"gradle"|"none">
local LABEL_TO_TOOL = {
  ["Maven (default)"] = "maven",
  ["Gradle"] = "gradle",
  ["No Build Tools"] = "none",
}

---T-12: Prompt the user to select a build tool.
---Calls `callback` with "maven", "gradle", or "none". Cancellation silently returns.
---@param callback fun(tool: "maven"|"gradle"|"none")
local function prompt_build_tool(callback)
  vim.ui.select(BUILD_TOOL_ITEMS, { prompt = "Build tool:" }, function(choice)
    if choice == nil then
      return
    end
    callback(LABEL_TO_TOOL[choice])
  end)
end

---T-14: Optionally ask for a custom project location.
---Empty input keeps the default. Cancellation (nil) aborts.
---@param default string The resolved default path shown as a hint.
---@param callback fun(override: string|nil)
local function prompt_location_override(default, callback)
  vim.ui.input({ prompt = ("Project location (Enter for '%s'): "):format(default) }, function(input)
    if input == nil then
      return
    end
    callback(input ~= "" and input or nil)
  end)
end

---T-14: Optionally ask for a custom package name.
---Empty input keeps the inferred default. Cancellation (nil) aborts.
---@param default string The inferred default package shown as a hint.
---@param callback fun(override: string|nil)
local function prompt_package_override(default, callback)
  vim.ui.input({ prompt = ("Package name (Enter for '%s'): "):format(default) }, function(input)
    if input == nil then
      return
    end
    callback(input ~= "" and input or nil)
  end)
end

---T-13: Ask whether to inject Main.java.
---@param callback fun(inject: boolean)
local function prompt_inject_main(callback)
  vim.ui.select({ "Yes", "No" }, { prompt = "Inject Main.java?" }, function(choice)
    if choice == nil then
      return
    end
    callback(choice == "Yes")
  end)
end

---T-13: Ask whether to initialise a git repository.
---@param callback fun(init: boolean)
local function prompt_git_init(callback)
  vim.ui.select({ "Yes", "No" }, { prompt = "Initialise git repository?" }, function(choice)
    if choice == nil then
      return
    end
    callback(choice == "Yes")
  end)
end

---Prompt the user for a project name and pass the raw input to `callback`.
---Cancellation (nil) silently returns without calling `callback`.
---@param callback fun(raw_name: string)
local function prompt_name(callback)
  vim.ui.input({ prompt = "Project name: " }, function(input)
    if input == nil then
      return
    end
    callback(input)
  end)
end

function M.create()
  prompt_name(function(raw_name)
    -- T-03: validate name
    local name, name_err = validate_name(raw_name)
    if not name then
      vim.notify("[jam] " .. name_err, vim.log.levels.ERROR)
      return
    end

    -- T-14: optional location override (shown before any side effects)
    local default_location = resolve_location(name)
    vim.schedule(function()
      prompt_location_override(default_location, function(loc_override)
        -- T-04: resolve final project root
        local location = resolve_location(name, loc_override)

        -- T-12: select build tool
        vim.schedule(function()
          prompt_build_tool(function(build_tool)
            -- T-13: toggles for entry point and VCS
            vim.schedule(function()
              prompt_inject_main(function(inject_main)
                vim.schedule(function()
                  prompt_git_init(function(do_git_init)
                    -- T-14: optional package name override
                    local default_pkg = infer_package(name)
                    vim.schedule(function()
                      prompt_package_override(default_pkg, function(pkg_override)
                        -- All prompts done — now perform side effects
                        vim.schedule(function()
                          -- T-05: validate parent permissions and create the directory
                          local ok5, err5 = require("jam.fs").ensure_project_dir(location)
                          if not ok5 then
                            vim.notify("[jam] " .. err5, vim.log.levels.ERROR)
                            return
                          end

                          -- T-06: detect JDK; warn but continue if absent
                          if not require("jam.detect").find_java() then
                            vim.notify("[jam] no JDK found — compile steps may fail", vim.log.levels.WARN)
                          end

                          -- T-07: resolve final package and path segment
                          local pkg = pkg_override or infer_package(name)
                          local pkg_path = package_to_path(pkg)
                          local java_version = require("jam.detect").find_java_version()

                          -- T-08: source directory scaffolding (same layout for all build tools)
                          local ok8, err8 = require("jam.fs").scaffold_maven(location, pkg_path)
                          if not ok8 then
                            vim.notify("[jam] " .. err8, vim.log.levels.ERROR)
                            return
                          end

                          -- T-09/T-15: write build file based on selection
                          if build_tool == "maven" then
                            local ok, err =
                              require("jam.fs").write_file(location .. "/pom.xml", pom_xml(name, pkg, java_version))
                            if not ok then
                              vim.notify("[jam] " .. err, vim.log.levels.ERROR)
                              return
                            end
                          elseif build_tool == "gradle" then
                            local ok1, err1 =
                              require("jam.fs").write_file(location .. "/build.gradle", build_gradle(pkg, java_version))
                            if not ok1 then
                              vim.notify("[jam] " .. err1, vim.log.levels.ERROR)
                              return
                            end
                            local ok2, err2 =
                              require("jam.fs").write_file(location .. "/settings.gradle", settings_gradle(name))
                            if not ok2 then
                              vim.notify("[jam] " .. err2, vim.log.levels.ERROR)
                              return
                            end
                          end
                          -- "none" writes no build file

                          -- T-10: Main.java (conditional on toggle)
                          if inject_main then
                            local main_path = location .. "/src/main/java/" .. pkg_path .. "/Main.java"
                            local ok10, err10 = require("jam.fs").write_file(main_path, main_java(pkg))
                            if not ok10 then
                              vim.notify("[jam] " .. err10, vim.log.levels.ERROR)
                              return
                            end
                          end

                          -- T-17: cd into root and open Main.java on success
                          local function finish()
                            vim.api.nvim_set_current_dir(location)
                            vim.notify(
                              ("[jam] project '%s' created at %s"):format(name, location),
                              vim.log.levels.INFO
                            )
                            if inject_main then
                              vim.cmd.edit(location .. "/src/main/java/" .. pkg_path .. "/Main.java")
                            end
                          end

                          -- T-11: git init + .gitignore (conditional on toggle)
                          if do_git_init then
                            local _, gi_err = require("jam.fs").write_file(location .. "/.gitignore", GITIGNORE)
                            if gi_err then
                              vim.notify("[jam] failed to write .gitignore: " .. gi_err, vim.log.levels.WARN)
                            end
                            require("jam.fs").git_init(location, function(git_ok)
                              if not git_ok then
                                vim.notify("[jam] git init failed (is git installed?)", vim.log.levels.WARN)
                              end
                              finish()
                            end)
                          else
                            finish()
                          end
                        end) -- vim.schedule (side effects)
                      end) -- prompt_package_override
                    end) -- vim.schedule
                  end) -- prompt_git_init
                end) -- vim.schedule
              end) -- prompt_inject_main
            end) -- vim.schedule
          end) -- prompt_build_tool
        end) -- vim.schedule
      end) -- prompt_location_override
    end) -- vim.schedule
  end) -- prompt_name
end

-- Exposed for unit tests only.
M._validate_name = validate_name
M._resolve_location = resolve_location
M._infer_package = infer_package
M._package_to_path = package_to_path
M._pom_xml = pom_xml
M._main_java = main_java
M._GITIGNORE = GITIGNORE
M._BUILD_TOOL_ITEMS = BUILD_TOOL_ITEMS
M._LABEL_TO_TOOL = LABEL_TO_TOOL
M._build_gradle = build_gradle
M._settings_gradle = settings_gradle

return M
