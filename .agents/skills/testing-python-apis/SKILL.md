---
name: testing-python-apis
description: Standards for writing API component tests and contract tests for FastAPI endpoints in this repo.
module: make.python.test.api
test-status: tests-have-been-run
---

# API Testing

This skill defines conventions for testing FastAPI endpoints. It covers two complementary test types: **API Component Testing** (endpoint behavior in isolation) and **Contract Testing** (schema/shape enforcement via Pydantic and OpenAPI).

For general testing philosophy (Arrange/Act/Assert, equivalence classes, parametrize guidelines, mocking boundaries), see the `testing-python-core` skill — this skill does **not** duplicate those rules.

## Scope

Apply these rules when writing or updating tests for FastAPI router modules and MCP server tools.

API component tests are technically thin integration tests -- they spin up the ASGI app in-process via `TestClient` -- but they still follow the rigorous assertion standards from the unit testing skill.

## Test Placement & Organization

### Directory structure

Mirror the source layout under `tests/`:

```text
tests/<package>/app/
    conftest.py                          # app fixture, shared mocks
    api/v1/
        conftest.py                      # api_v1_client fixture
        routers/
            test_health.py               # maps to src/.../routers/health.py
            test_items.py                # maps to src/.../routers/items.py
    mcp/v1/
        test_server.py                   # maps to src/.../mcp/v1/server.py
```

No `__init__.py` files are needed when pytest is configured with `--import-mode=importlib`.

### Rules

- **Test layout is a structural invariant, not just an initial-creation convention.** When source code moves from one module to a different module, the corresponding tests must also move from the old test module to a new test module that mirrors the new source path. Updating import paths inside the old test file is not sufficient — the test file's location and name must track the source module it covers.
- One test module per router/server module.
- Apply `pytestmark = pytest.mark.api_v1` in every API v1 test module (or `pytest.mark.mcp_v1` for MCP v1 tests). These markers allow selective test execution.
- **Group tests into classes per router** (e.g., `TestHealth`, `TestCreateItem`, `TestGetItem`). Classes group related tests, collapse nicely in the test runner, and allow class-scoped fixture overrides when needed.
- Place fixture layers strategically:
  - `tests/<package>/app/conftest.py` -- app-level fixtures (`app`, shared mocks).
  - `tests/<package>/app/api/v1/conftest.py` -- v1-specific fixtures (`api_v1_client`).

## Core Fixtures

### App fixture

```python
from collections.abc import Generator

import pytest
from fastapi import FastAPI
from myapp.main import create_app


@pytest.fixture
def app() -> Generator[FastAPI, None, None]:
    """Provide the FastAPI application instance."""
    application = create_app()
    yield application
    application.dependency_overrides.clear()
```

The teardown call to `dependency_overrides.clear()` ensures test isolation when overrides are applied.

### Client fixture

Use `TestClient` from `fastapi.testclient` (sync, built on `requests`) for component tests. Reserve `httpx.AsyncClient` for integration tests that hit a running server.

**Bypass authentication via `dependency_overrides`** -- do not read the real API key from config files. This decouples tests from deployment configuration and is the idiomatic FastAPI approach.

```python
from fastapi.testclient import TestClient
from myapp.core.security import get_api_key


@pytest.fixture
def api_v1_client(app):
    """Provide a TestClient with API key auth bypassed via dependency override."""
    app.dependency_overrides[get_api_key] = lambda: "test-key"
    return TestClient(app)
```

Tests should include the versioned prefix in request paths (e.g., `/api/v1/health`), since `TestClient` does not prepend a path component automatically.

### Shared mock fixtures

When the same patches are needed across multiple test classes, define them as **explicit fixtures in conftest** (not `autouse`). Request them by name in each test so dependencies are visible.

```python
from pathlib import Path


@pytest.fixture
def mock_storage_setup(mocker):
    """Patch storage path resolution and config loading for isolation."""
    mocker.patch(
        "myapp.api.v1.routers.items._resolve_storage_path",
        return_value=Path("dummy/storage"),
    )
    mocker.patch(
        "myapp.api.v1.routers.items._load_config",
        return_value={"bucket": "test"},
    )
```

Place shared fixtures at `tests/<package>/app/conftest.py` so all test modules can use them.

## Mocking Strategy (Hybrid)

This repo uses a hybrid mocking approach:

| What to mock                                  | Technique                  |
| --------------------------------------------- | -------------------------- |
| `Depends()` callables (auth, DB sessions)     | `app.dependency_overrides` |
| Module-level functions in endpoint call chain | `mocker.patch()`           |
| Outbound HTTP calls made by application code  | `pytest-httpx`             |

### `app.dependency_overrides` -- for FastAPI DI callables

Use for anything declared as a `Depends()` parameter in a router signature.

```python
from myapp.core.security import get_api_key


def test_endpoint_rejects_bad_key(app):
    """Endpoint returns 403 when the API key dependency rejects the request."""
    # Do NOT override the dependency -- let the real auth check run
    client = TestClient(app)

    response = client.get("/api/v1/health")

    assert response.status_code == 403
```

Always clear overrides in fixture teardown (the `app` fixture above handles this).

### `mocker.patch()` -- for non-DI functions

Use for patching business-logic generators, helper functions, and third-party SDK calls that are not injected via `Depends()`.

```python
def test_create_item_calls_service(api_v1_client, mocker):
    """POST /items delegates to the item service and returns 201."""
    mocker.patch(
        "myapp.api.v1.routers.items.item_service.create",
        return_value={"id": 1, "name": "Widget"},
    )

    response = api_v1_client.post(
        "/api/v1/items", json={"name": "Widget"},
    )

    assert response.status_code == 201
```

Follows `mocker` from `pytest-mock` (never `unittest.mock`), consistent with the unit testing skill.

### `pytest-httpx` -- for outbound HTTP

Use when application code makes HTTP calls (e.g., downloading a file from a URL). The `pytest-httpx` library (already in test dependencies) intercepts `httpx` calls without hitting the network.

```python
def test_fetch_remote_resource(httpx_mock):
    """Endpoint fetches the remote file when given a URL."""
    httpx_mock.add_response(
        url="https://example.com/data.csv",
        content=b"col1,col2\n1,2",
        headers={"content-type": "text/csv"},
    )
    # ... call the endpoint or helper that uses httpx internally
```

## API Component Testing

### What to test

- **Status codes**: correct codes for success, auth failure, validation failure.
- **Response body shape**: JSON structure matches expectations.
- **Header behavior**: content-type, custom headers.
- **Router orchestration**: the router calls the right downstream functions and handles errors correctly (verified via mocks and response assertions).
- **Auth rejection**: one test per router module confirming 403 without API key.

### What NOT to test here

- **Business logic** inside service/logic layers -- that belongs in unit tests.
- **Private helper functions** directly -- test them through the endpoint.
- **Framework internals** (FastAPI routing mechanics, Pydantic validation internals).
- **Database access** -- use `dependency_overrides` for session injection and test the query logic in dedicated repository tests.

### Testing pure helper functions

If a router module contains **pure functions with no I/O** (e.g., a serialiser or formatter), test them as standard unit tests in the same test module. No `TestClient` needed.

```python
from myapp.api.v1.routers.items import format_sse_event


class TestFormatSseEvent:
    """Unit tests for the SSE frame serializer."""

    def test_serializes_event_to_sse_frame(self):
        """format_sse_event produces a valid SSE frame."""
        event = {"type": "progress", "data": {"status": "Processing"}}

        result = format_sse_event(event)

        assert result == 'event: progress\ndata: {"status": "Processing"}\n\n'
```

### Examples

#### Simple GET endpoint

```python
import pytest
from fastapi.testclient import TestClient

API_V1_PREFIX = "/api/v1"

pytestmark = pytest.mark.api_v1


class TestHealth:
    """Component tests for GET /api/v1/health."""

    def test_returns_200(self, api_v1_client):
        """Health endpoint returns 200."""
        response = api_v1_client.get(f"{API_V1_PREFIX}/health")

        assert response.status_code == 200

    def test_returns_status_and_timestamp(self, api_v1_client, mocker):
        """Health response contains status and timestamp."""
        mock_dt = mocker.patch("myapp.api.v1.routers.health.datetime")
        mock_dt.now.return_value.isoformat.return_value = "2025-01-01T00:00:00+00:00"

        response = api_v1_client.get(f"{API_V1_PREFIX}/health")

        assert response.json() == {
            "status": "healthy",
            "timestamp": "2025-01-01T00:00:00+00:00",
        }

    def test_rejects_without_api_key(self, app):
        """Requests without a valid API key receive 403."""
        client = TestClient(app)

        response = client.get(f"{API_V1_PREFIX}/health")

        assert response.status_code == 403
```

#### POST with JSON body

```python
class TestCreateItem:
    """Component tests for POST /api/v1/items."""

    def test_returns_201_on_success(self, api_v1_client, mocker):
        """Valid payload returns 201 with created item."""
        mocker.patch(
            "myapp.api.v1.routers.items.item_service.create",
            return_value={"id": 1, "name": "Widget"},
        )

        response = api_v1_client.post(
            f"{API_V1_PREFIX}/items",
            json={"name": "Widget"},
        )

        assert response.status_code == 201

    def test_rejects_without_api_key(self, app):
        """Requests without API key receive 403."""
        client = TestClient(app)

        response = client.post(
            f"{API_V1_PREFIX}/items",
            json={"name": "Widget"},
        )

        assert response.status_code == 403
```

#### Validation rejection (invalid Pydantic payload)

```python
    def test_rejects_missing_required_field(self, api_v1_client):
        """Endpoint returns 422 when a required field is missing."""
        response = api_v1_client.post(
            f"{API_V1_PREFIX}/items",
            json={},
        )

        assert response.status_code == 422
```

#### Using `@pytest.mark.usefixtures` for side-effect fixtures

When a fixture is needed only for its patch side effect (not return value), use `@pytest.mark.usefixtures()` instead of adding unused parameters. This avoids lint warnings (`ARG002`) and makes the test signature cleaner.

```python
    @pytest.mark.usefixtures("mock_storage_setup", "mock_item_service")
    def test_returns_200_on_success(self, api_v1_client):
        """Endpoint succeeds when all dependencies are mocked."""
        response = api_v1_client.post(
            f"{API_V1_PREFIX}/items",
            json={"name": "Widget"},
        )

        assert response.status_code == 200
```

## Testing SSE / Streaming Responses

For testing `StreamingResponse` and SSE endpoints (stream parsing, event assertion, error-path testing), see the `testing-python-apis-streaming` skill.

## Contract Testing (Lightweight)

For contract testing patterns (Pydantic DTO validation tests, OpenAPI schema validation), see the `testing-python-apis-contracts` skill.

## Design Decisions

| #   | Decision             | Choice                                               | Rationale                                                      |
| --- | -------------------- | ---------------------------------------------------- | -------------------------------------------------------------- |
| 1   | Auth mocking         | `dependency_overrides`                               | Idiomatic FastAPI; decouples from deployment config            |
| 2   | Mocking depth        | Mock everything except the router                    | Tests router orchestration; avoids coupling to internals       |
| 3   | SSE assertions       | Parse and assert frame content                       | Status code alone is insufficient for streaming endpoints      |
| 4   | Pure helpers         | Unit-test directly; private helpers through endpoint | Pure formatters are testable in isolation; I/O helpers are not |
| 5   | Test grouping        | Classes per router                                   | Collapse in runner; class-scoped fixture overrides             |
| 6   | Auth rejection scope | One test per router module                           | Confirms dependency wiring per router                          |
| 7   | Private helpers      | Keep private, test through endpoint                  | Preserves encapsulation                                        |
| 8   | Shared mocks         | Explicit fixtures in conftest                        | Visible dependency graph; no hidden `autouse` side effects     |

## Quick Reference

| Aspect                        | Convention                                                  |
| ----------------------------- | ----------------------------------------------------------- |
| **Test framework**            | `pytest`                                                    |
| **HTTP client (component)**   | `fastapi.testclient.TestClient` (sync)                      |
| **HTTP client (integration)** | `httpx.AsyncClient` (async, hits running server)            |
| **DI mocking**                | `app.dependency_overrides` for `Depends()` callables        |
| **Function mocking**          | `mocker.patch()` via `pytest-mock`                          |
| **Outbound HTTP mocking**     | `pytest-httpx`                                              |
| **Marker (API v1)**           | `pytestmark = pytest.mark.api_v1`                           |
| **Marker (MCP v1)**           | `pytestmark = pytest.mark.mcp_v1`                           |
| **DTO contract tests**        | Test Pydantic models directly with `ValidationError`        |
| **OpenAPI contract test**     | `openapi-spec-validator` against `/openapi.json`            |
| **SSE parsing**               | Module-level `parse_sse_events()` helper                    |
| **Test grouping**             | One class per router (e.g., `TestHealth`, `TestCreateItem`) |
| **Auth rejection**            | One `test_rejects_without_api_key` per router module        |

## Related Skills

- `testing-python-apis-streaming` — Testing patterns for SSE and `StreamingResponse` endpoints (stream parsing, event assertion, error-path testing).
- `testing-python-apis-contracts` — Contract testing patterns for Pydantic DTOs and OpenAPI schema validation.
- `testing-python-core` — Shared testing foundations (Arrange/Act/Assert, equivalence classes, parametrize guidelines, mocking boundaries, side-effect fixtures).
- `testing-python-units` — Unit-specific testing rules (what to test, what NOT to test, naming conventions).
