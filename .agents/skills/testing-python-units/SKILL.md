---
name: testing-python-units
description: Unit-specific testing rules — what to test, what NOT to test, when to write multiple tests, and naming conventions. For shared foundations (AAA, parametrize, mocking), see testing-python-core.
module: make.python.test.unit
test-status: tests-have-been-run
---

# Python Unit Testing

Unit-specific testing conventions. For shared testing foundations (AAA pattern, equivalence classes, parametrize guidelines, mocking boundaries, side-effect fixtures), see the `testing-python-core` skill — this skill does **not** duplicate those rules.

## Scope

Apply these rules when writing or updating unit tests under `tests/`.

## What to Test

### DO Test

- **Core functionality works** — the function/method produces expected outputs
- **State changes correctly** — objects are modified as expected
- **Error handling works** — exceptions are raised when appropriate
- **Integration points work** — external dependencies are called (via mocks)

### DON'T Test

- **Scripts and orchestration code** — scripts, CLI entry points, notebooks, and pipeline runners are orchestration glue that wires together function calls, I/O, configuration, and side effects. They are never test targets. If a script contains logic complex enough to warrant testing, that is an **architectural issue**: extract the logic into a library function and test the function, not the script. The remedy is always "extract and test the logic," never "test the script."
- **Domain value objects directly** — never create a `test_<value_object>.py` file. Value objects (Pydantic `BaseModel` subclasses in `domain/value_objects/`) are exercised indirectly through the service or function that uses them. See the `modeling-python-domains` skill.
- **Every parameter permutation** — use **equivalence classes** and **boundary values** instead. If a function handles all positive integers the same way, test one representative value and the boundaries (0, -1, maxint).
- **Private functions** (prefixed with `_`) — these are implementation details, not public contracts. Testing them couples your test suite to refactoring decisions and breaks when you optimize internal logic. Always test through the public API.
- **Internal implementation details** — which private methods are called, in what order
- **Framework internals** — trust that third-party libraries work correctly
- **Trivial getters/setters** — if a property just returns a value, skip it
- **Functions defined in script files** (`src/scripts/`) — untestable by location; move to a package module first (see `placing-python-functions`)

## When to Write Multiple Tests

Write multiple tests for the same function only when:

1. **Distinct behavioral paths exist** — success vs. error cases
2. **Edge cases are critical** — empty inputs, boundary values, special states
3. **Multiple integration points** — different external dependencies

### Example: Multiple Tests Justified

```python
def test_parse_config_with_valid_yaml() -> None:
    result = parse_config("valid.yaml")
    assert result.database_url is not None

def test_parse_config_raises_on_invalid_yaml() -> None:
    with pytest.raises(ConfigError):
        parse_config("invalid.yaml")

def test_parse_config_with_missing_file() -> None:
    with pytest.raises(FileNotFoundError):
        parse_config("nonexistent.yaml")
```

## Naming Conventions

- **Preserve acronym casing in test class names** — when deriving a PascalCase test class name from a snake_case function (e.g. `infer_final_gwl` → `TestInferFinalGWL`), do not blindly title-case each segment. First check how the acronym appears in existing PascalCase identifiers in the codebase and restore that established form. If there is no PascalCase precedent, fall back to common domain knowledge: keep well-known acronyms fully uppercased (e.g. `API`, `HTTP`, `CSV`, `ID`, `URL`) and otherwise use the normal title-cased segment rather than inventing a new all-caps acronym.

## Examples

### Good Example: Behavior-Focused

```python
def test_build_report_works() -> None:
    """Test that build_report creates a report with expected data."""
    data = {"metric": 42}

    result = build_report(data)

    assert result.metric == 42
    assert result.timestamp is not None
```

### Bad Example: Over-Testing Implementation

```python
# Don't test every parameter variation
def test_build_report_with_default_format() -> None: ...
def test_build_report_with_json_format() -> None: ...
def test_build_report_with_xml_format() -> None: ...
def test_build_report_with_csv_format() -> None: ...

# Instead, test once with a representative case
def test_build_report_works() -> None:
    result = build_report(data, format="json")
    assert result.format == "json"
```

### Bad Example: Testing Internal Calls

```python
# Don't verify which internal functions were called
def test_process_data_calls_validator(mocker) -> None:
    mock_validator = mocker.patch("module._validate_data")
    process_data({"key": "value"})
    mock_validator.assert_called_once()  # Too coupled to implementation

# Instead, test the outcome
def test_process_data_works() -> None:
    result = process_data({"key": "value"})
    assert result.is_valid is True
```

### Good Example: Minimal Mocking

```python
# Mock only external dependencies
def test_fetch_user_data_works(mocker) -> None:
    """Test that fetch_user_data retrieves data from API."""
    mock_http = mocker.patch("module.requests.get")
    mock_http.return_value.json.return_value = {"name": "Alice"}

    result = fetch_user_data(user_id=123)

    assert result["name"] == "Alice"
```

## Related Skills

- `testing-python-core` — Shared testing foundations: AAA pattern, equivalence classes, parametrize guidelines, mocking boundaries, side-effect fixtures.
- `testing-python-apis` — When testing FastAPI endpoints or MCP server tools, use this for API component test conventions (TestClient, dependency overrides, contract testing).
