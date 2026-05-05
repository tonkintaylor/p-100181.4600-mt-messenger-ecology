---
name: testing-python-apis-streaming
description: Use when writing or reviewing tests for FastAPI SSE or StreamingResponse endpoints — covers stream parsing, event assertion, and error-path testing patterns
module: make.python.test.api.streaming
test-status: tests-have-been-run
---

# Testing SSE / Streaming Responses

The main endpoints return `StreamingResponse` with `media_type="text/event-stream"`. Testing only the status code is insufficient -- verify the **content** of the stream.

For general API component testing conventions (fixtures, mocking strategy, test organization), see the `testing-python-apis` skill.

## Pattern: module-level `parse_sse_events` helper

`TestClient` buffers the full response by default. Access the streamed content via `response.text`, then parse SSE frames with a **module-level helper** defined at the top of each test module that needs it (or in `conftest.py` for wider reuse).

```python
import json


def parse_sse_events(raw: str) -> list[dict]:
    """Parse raw SSE text into a list of event dicts.

    Each SSE frame is separated by a blank line. Lines starting with
    ``event:`` and ``data:`` are extracted.
    """
    events = []
    for frame in raw.strip().split("\n\n"):
        event = {}
        for line in frame.strip().split("\n"):
            if line.startswith("event: "):
                event["type"] = line[len("event: "):]
            elif line.startswith("data: "):
                event["data"] = json.loads(line[len("data: "):])
        if event:
            events.append(event)
    return events
```

## Example: assert on streamed events

```python
class TestProcessItems:
    @pytest.mark.usefixtures("mock_storage_setup")
    def test_streams_progress_and_result(
        self, api_v1_client, mocker,
    ):
        """Processing endpoint streams progress then result events."""
        async def mock_generator(*_args, **_kwargs):
            yield {"type": "progress", "data": {"status": "Processing"}}
            yield {"type": "result", "data": {"message": "Done"}}

        mocker.patch(
            "myapp.api.v1.routers.items.process_items",
            new=mocker.MagicMock(side_effect=mock_generator),
        )

        response = api_v1_client.post(
            "/api/v1/items/process", json={"ids": [1, 2]},
        )

        assert response.status_code == 200
        events = parse_sse_events(response.text)
        assert events[0]["type"] == "progress"
        assert events[0]["data"]["status"] == "Processing"
        assert events[1]["type"] == "result"
        assert events[1]["data"]["message"] == "Done"
```

## Testing error paths through SSE

When a downstream call raises, the endpoint should stream an error event rather than returning a non-200 status. Test this by patching the failing dependency:

```python
    def test_streams_error_on_service_failure(
        self, api_v1_client, mock_storage_setup, mocker,
    ):
        """Endpoint streams an error event when the service raises."""
        mocker.patch(
            "myapp.api.v1.routers.items._fetch_remote_data",
            new=mocker.AsyncMock(side_effect=ValueError("Connection refused")),
        )

        response = api_v1_client.post(
            "/api/v1/items/process", json={"ids": [1]},
        )

        events = parse_sse_events(response.text)
        assert events[0]["type"] == "error"
```

Place `parse_sse_events` at module level in the test file that needs it, or in conftest for wider reuse across multiple test modules.

## Related Skills

- `testing-python-apis` — Parent skill covering core API component testing conventions (fixtures, mocking, organization).
- `testing-python-apis-contracts` — Contract testing patterns for Pydantic DTOs and OpenAPI schema validation.
- `testing-python-units` — General testing philosophy (Arrange/Act/Assert, equivalence classes, parametrize guidelines).
