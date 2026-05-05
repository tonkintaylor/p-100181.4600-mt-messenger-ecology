---
name: testing-python-core
description: Shared testing foundations for all Python test types — AAA pattern, equivalence classes, parametrize guidelines, mocking boundaries, and side-effect fixture conventions.
module: make.python.test.core
test-status: tests-have-been-run
---

# Python Testing Foundations

Shared testing conventions used by both unit and API testing skills. This skill defines the **how** of Python testing — the patterns and principles that apply regardless of what you're testing.

## Core Philosophy

**Test behavior, not implementation.** Tests should verify that code works correctly, not how it achieves that. If you refactor internal logic while preserving external behavior, tests should still pass.

This approach prevents the **Fragile Test Problem**, where tests break every time code is refactored, turning the test suite from an asset into a burden. By focusing on observable behavior (outputs, state changes, exceptions) rather than internal mechanics (which private methods are called, in what order), you ensure tests enable refactoring rather than hinder it.

## Testing Styles

**State-based testing (Classicist approach)**: Assert on return values, object state, and observable side effects. This is the preferred style because it decouples tests from implementation details.

**Interaction-based testing (Mockist approach)**: Verify that specific methods were called with specific arguments. Use this sparingly and only for external boundaries (APIs, databases, file I/O). Overusing this style couples tests to implementation and makes refactoring painful.

## Core Rules

- Use pytest.
- **Preserve test-source mirroring during refactors**: When source code moves from one module to a different module, move the corresponding tests to a test module that mirrors the new source path. Updating imports inside the old test file is not sufficient — the test file's location and name must track the source module it covers. The mirror convention is a structural invariant that applies during refactors, not just during initial file creation.
- Prefer the arrange / act / assert structure.
- Keep assertions at the end of the test; split tests if needed.
- **Test essential functionality only** — one test per function/method is often sufficient.
- **Avoid over-testing parameter variations** — don't test every possible input combination unless they represent distinct behavioral paths.
- **Mock only external dependencies** — APIs, file I/O, databases, third-party services. Follow the principle: **"Don't mock what you don't own."** Don't mock internal functions unless necessary.
- **Verify outcomes, not method calls** — prefer state-based testing (assert on return values and state changes) over interaction-based testing (verifying which internal methods were called).

## Procedure

1. Arrange inputs and fixtures.
2. Act by calling the function under test.
3. Assert results at the end.

## Parametrize Wisely

Use `@pytest.mark.parametrize` only when:

- Testing the same logic with different representative inputs
- Verifying boundary conditions
- NOT when testing implementation details

**Important: Parameter names must be a tuple, not a string.**

```python
# Correct: Use a tuple for parameter names
@pytest.mark.parametrize(
    ("prefix", "expected_count"),
    [("H", 12), ("S", 8), ("A", 5)],
    ids=["filter_H_rules", "filter_S_rules", "filter_A_rules"],
)
def test_filter_rules_by_prefix(prefix: str, expected_count: int) -> None:
    result = filter_rules(rulebank, prefix=prefix)
    assert len(result) == expected_count

# Incorrect: Don't use a comma-separated string
# @pytest.mark.parametrize(
#     "prefix,expected_count",  # Wrong! This triggers PT006
```

## Equivalence Classes and Boundary Values

Instead of exhaustive testing, use **equivalence partitioning** and **boundary value analysis**:

- **Equivalence class**: A set of inputs that are handled the same way by the code. Test one representative from each class.
- **Boundary value**: The edges where behavior changes (0, -1, empty string, null, max values). These are where bugs hide.

### Example: Testing Age Validation

```python
# Function validates: 0 <= age <= 120
# Equivalence classes: negative, valid (0-120), excessive (>120)
# Boundaries: -1, 0, 120, 121

@pytest.mark.parametrize(
    ("age", "is_valid"),
    [
        (-1, False),      # Boundary: just below valid range
        (0, True),        # Boundary: minimum valid
        (25, True),       # Representative: middle of valid range
        (120, True),      # Boundary: maximum valid
        (121, False),     # Boundary: just above valid range
    ],
    ids=["below_min", "min_valid", "mid_valid", "max_valid", "above_max"],
)
def test_validate_age(age: int, is_valid: bool) -> None:
    assert validate_age(age) == is_valid
```

## Side-Effect-Only Fixtures

Some fixtures exist only to patch external I/O (e.g. `mocker.patch(...)` calls). They produce no value that the test body uses directly. **Never inject them as function or method parameters**; doing so triggers `ARG001` (standalone functions) or `ARG002` (class methods) for unused arguments. Prefixing with `_` to silence the linter triggers `PT019` (fixture without value injected as parameter).

**Quick check before writing any test:** ask "does the test body reference this fixture by name?" If no — use `@pytest.mark.usefixtures` instead of a parameter.

Instead, apply them at the class or function level via `@pytest.mark.usefixtures`:

```python
# Bad: standalone async function — triggers ARG001
@pytest.mark.asyncio
async def test_something(mock_llm_flow) -> None:  # ARG001: mock_llm_flow never used in body
    result = await my_service()
    assert isinstance(result, MyResult)

# Bad: class method — triggers ARG002
async def test_something(self, mock_pipeline_boundaries, mock_rulebank_repo): ...

# Also bad: underscore prefix "fixes" ARG001/ARG002 but triggers PT019
async def test_something(_mock_llm_flow) -> None: ...

# Good (standalone): apply decorator directly on the function
@pytest.mark.asyncio
@pytest.mark.usefixtures("mock_llm_flow")
async def test_something() -> None:
    result = await my_service()
    assert isinstance(result, MyResult)

# Good (class): declare at the class level; pytest applies the fixture automatically
@pytest.mark.usefixtures("mock_pipeline_boundaries")
class TestSomething:
    async def test_something(self, mock_rulebank_repo): ...
```

If every test in a class needs the same side-effect fixture, put `@pytest.mark.usefixtures` on the class. If only some tests need it, put it on those individual test methods. For standalone test functions, apply `@pytest.mark.usefixtures` directly on each function that needs it.

## Mocking Guidelines

### "Don't Mock What You Don't Own"

Mock only code at the boundaries of your system:

#### Good candidates for mocking

- HTTP clients (requests, httpx)
- Database connections (SQLAlchemy sessions)
- File system operations (Path.open, Path.exists)
- External APIs (Stripe, SendGrid, AWS SDK)
- Time/random functions (time.time, random.randint)

#### Bad candidates for mocking

- Your own internal functions
- Domain model methods
- Business logic

### Example: Proper Mocking Boundary

```python
# Good: Mock the external HTTP library
def test_get_user_profile_works(mocker) -> None:
    mock_get = mocker.patch("myapp.services.requests.get")
    mock_get.return_value.json.return_value = {"name": "Alice"}

    profile = get_user_profile(user_id=123)

    assert profile.name == "Alice"

# Bad: Mock internal business logic
def test_process_order_calls_validator(mocker) -> None:
    mock_validate = mocker.patch("myapp.orders._validate_order")
    process_order(order_data)
    mock_validate.assert_called_once()  # Fragile! Breaks on refactor
```

## Related Skills

- `testing-python-units` — Unit-specific rules: what to test, what not to test, when to write multiple tests.
- `testing-python-apis` — API component testing: TestClient, dependency overrides, endpoint conventions.
