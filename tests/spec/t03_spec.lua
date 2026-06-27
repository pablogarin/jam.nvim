local function reset()
  package.loaded["jam.create"] = nil
end

describe("T-03 | Project name validation", function()
  before_each(reset)

  local function validate(raw)
    return require("jam.create")._validate_name(raw)
  end

  it("rejects an empty string", function()
    local name, err = validate("")
    expect(name).to_be_nil()
    expect(err).not_to_be_nil()
  end)

  it("rejects a name containing a space", function()
    local name, err = validate("my project")
    expect(name).to_be_nil()
    expect(err).not_to_be_nil()
  end)

  it("rejects a name containing '/'", function()
    local name, err = validate("my/project")
    expect(name).to_be_nil()
    expect(err).not_to_be_nil()
  end)

  it("rejects a name containing '\\'", function()
    local name, err = validate("my\\project")
    expect(name).to_be_nil()
    expect(err).not_to_be_nil()
  end)

  it("rejects a name containing ':'", function()
    local name, err = validate("my:project")
    expect(name).to_be_nil()
    expect(err).not_to_be_nil()
  end)

  it("rejects a name containing '*'", function()
    local name, err = validate("my*project")
    expect(name).to_be_nil()
    expect(err).not_to_be_nil()
  end)

  it("rejects a name containing '?'", function()
    local name, err = validate("my?project")
    expect(name).to_be_nil()
    expect(err).not_to_be_nil()
  end)

  it("rejects a name containing '\"'", function()
    local name, err = validate('my"project')
    expect(name).to_be_nil()
    expect(err).not_to_be_nil()
  end)

  it("rejects a name containing '<'", function()
    local name, err = validate("my<project")
    expect(name).to_be_nil()
    expect(err).not_to_be_nil()
  end)

  it("rejects a name containing '>'", function()
    local name, err = validate("my>project")
    expect(name).to_be_nil()
    expect(err).not_to_be_nil()
  end)

  it("rejects a name containing '|'", function()
    local name, err = validate("my|project")
    expect(name).to_be_nil()
    expect(err).not_to_be_nil()
  end)

  it("accepts a simple alphanumeric name", function()
    local name, err = validate("MyProject")
    expect(name).to_be("MyProject")
    expect(err).to_be_nil()
  end)

  it("accepts a name with hyphens", function()
    local name, err = validate("my-project")
    expect(name).to_be("my-project")
    expect(err).to_be_nil()
  end)

  it("accepts a name with underscores", function()
    local name, err = validate("my_project")
    expect(name).to_be("my_project")
    expect(err).to_be_nil()
  end)

  it("accepts a name with digits", function()
    local name, err = validate("project2")
    expect(name).to_be("project2")
    expect(err).to_be_nil()
  end)
end)
