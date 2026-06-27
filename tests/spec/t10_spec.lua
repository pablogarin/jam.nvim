local function reset()
  package.loaded["jam.create"] = nil
end

describe("T-10 | Main.java boilerplate injection", function()
  before_each(reset)

  local function main(pkg)
    return require("jam.create")._main_java(pkg)
  end

  it("contains the correct package declaration", function()
    local src = main("org.example.myproject")
    expect(src:find("package org.example.myproject;", 1, true) ~= nil).to_be_true()
  end)

  it("declares a public class Main", function()
    local src = main("org.example.myproject")
    expect(src:find("public class Main", 1, true) ~= nil).to_be_true()
  end)

  it("contains a public static void main method", function()
    local src = main("org.example.myproject")
    expect(src:find("public static void main", 1, true) ~= nil).to_be_true()
  end)

  it("contains String[] args parameter", function()
    local src = main("org.example.myproject")
    expect(src:find("String[] args", 1, true) ~= nil).to_be_true()
  end)

  it("prints Hello, World!", function()
    local src = main("org.example.myproject")
    expect(src:find('System.out.println("Hello, World!")', 1, true) ~= nil).to_be_true()
  end)

  it("uses the given package name verbatim", function()
    local src = main("com.acme.demo")
    expect(src:find("package com.acme.demo;", 1, true) ~= nil).to_be_true()
  end)
end)
