---
name: testing-python-apis-contracts
description: Use when writing or reviewing contract tests for API DTOs (Pydantic models) and OpenAPI schema validation — covers shape enforcement and schema regression detection
module: make.python.test.api.contract
test-status: tests-have-been-run
---

# Contract Testing (Lightweight)

Treat Pydantic as the contract enforcement layer. Dedicated consumer-driven contract testing tools (e.g., Pact) are out of scope unless external consumers explicitly require version-locked contracts.

For general API component testing conventions (fixtures, mocking strategy, test organization), see the `testing-python-apis` skill.

## Pydantic DTO validation tests

Test request/response models directly to confirm the contract holds:

```python
import pytest
from pydantic import ValidationError

from myapp.core.models.items import CreateItemRequest


class TestCreateItemRequestContract:
    """Contract tests for CreateItemRequest."""

    def test_valid_payload_accepted(self):
        """Model accepts a valid payload."""
        req = CreateItemRequest(name="Widget")

        assert req.name == "Widget"

    def test_missing_required_field_rejected(self):
        """Model rejects payload missing a required field."""
        with pytest.raises(ValidationError):
            CreateItemRequest()  # 'name' is required

    def test_extra_fields_rejected(self):
        """Model rejects extra fields (extra='forbid')."""
        with pytest.raises(ValidationError, match="extra_forbidden"):
            CreateItemRequest(
                name="Widget",
                unexpected="value",
            )
```

This tests the shape of the data contract independent of the HTTP layer. Keep DTO tests in a dedicated module (e.g., `tests/<package>/app/core/models/test_items.py`) mirroring the source path.

For the relationship between API DTOs and domain models, see the `modeling-python-domains` skill -- they must be separate classes.

## OpenAPI specification validation

Validate that the generated OpenAPI schema is structurally correct:

```python
from openapi_spec_validator import validate


def test_openapi_schema_is_valid(api_v1_client):
    """Generated OpenAPI schema passes structural validation."""
    response = api_v1_client.get("/api/v1/openapi.json")

    assert response.status_code == 200
    validate(response.json())  # raises on invalid schema
```

`openapi-spec-validator` is already in the test dependency group. This single test catches schema regressions (missing response models, invalid refs, broken examples) automatically.

## Related Skills

- `testing-python-apis` — Parent skill covering core API component testing conventions (fixtures, mocking, organization).
- `testing-python-apis-streaming` — Testing patterns for SSE and StreamingResponse endpoints.
- `testing-python-units` — General testing philosophy (Arrange/Act/Assert, equivalence classes, parametrize guidelines).
- `modeling-python-domains` — Domain modeling conventions; API DTOs must be separate from domain models.
