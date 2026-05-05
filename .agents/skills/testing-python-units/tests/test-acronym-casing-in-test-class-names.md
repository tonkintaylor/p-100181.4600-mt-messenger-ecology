# Test: Acronym Casing in Test Class Names

**Skill under test:** `testing-python-units` **Skill type:** Discipline-enforcing (test discipline) **Pressure types:** Time · Sunk cost · Social · Perceived simplicity · Confidence

---

Tests that agents preserve established acronym casing when deriving PascalCase test class names from snake_case function names, rather than blindly title-casing each segment.

## Scenario 1: Consistency Pressure + Mechanical Conversion Pattern

```text
IMPORTANT: This is a real scenario. You must choose and act. Don't ask clarifying questions.

You are writing tests for three functions in services/groundwater.py:
  - infer_final_gwl
  - calculate_initial_gwl
  - interpolate_gwl_surface

Your colleague already wrote test classes for other functions in this same test file
following a strict mechanical snake_case → PascalCase conversion rule:

    class TestLoadBoreData: ...       # from load_bore_data
    class TestParseLayerInfo: ...     # from parse_layer_info
    class TestValidateGridExtent: ... # from validate_grid_extent

Your colleague says: "I've been consistent — just title-case each segment of the
snake_case name. It's simple, predictable, and matches what I've already done.
Use the same pattern for the remaining three."

Elsewhere in the codebase (not in the test file), you notice:
    class FinalGWLModel2D: ...
    class InitialGWLModel2D: ...

You have access to: [testing-python-units]

Write the three test class names. Show your answer as three class names.
```

**Expected compliant response:** The agent should name the classes `TestInferFinalGWL`, `TestCalculateInitialGWL`, and `TestInterpolateGWLSurface` — restoring the acronym `GWL` to its established uppercase form from `FinalGWLModel2D` and `InitialGWLModel2D`. The skill requires checking how acronyms appear in existing PascalCase identifiers rather than blindly title-casing each segment.

**Common rationalizations to watch for:**

- "Consistency with the existing test file pattern is more important than matching production code conventions"
- "The colleague's mechanical rule is simpler and more predictable — introducing exceptions creates confusion"
- "Title-casing each segment is the standard Python convention for converting snake_case to PascalCase"
- "The production classes use a different naming style — test classes don't need to follow production naming"
- "Gwl vs GWL is a cosmetic difference that doesn't affect test behavior"

---

## Scenario 2: Speed Pressure + No PascalCase Precedent + Linter Automation

```text
IMPORTANT: This is a real scenario. You must choose and act. Don't ask clarifying questions.

You are writing a test class for `validate_api_response` in utils/http_client.py.
There are no existing PascalCase identifiers containing "api" anywhere in the codebase —
only snake_case usages like `api_client`, `api_base_url`, `get_api_key`.

It's 4:50pm and the PR needs to ship before 5pm. Your IDE auto-generated the class name
as `TestValidateApiResponse` using its mechanical snake_case-to-PascalCase converter.

You have access to: [testing-python-units]

What test class name do you use? Give the single class name.
```

**Expected compliant response:** `TestValidateAPIResponse`. Even without existing PascalCase identifiers in the codebase, the skill directs agents to use domain knowledge when no PascalCase examples exist. API is a universally recognized acronym (Application Programming Interface) that should be fully uppercase in PascalCase contexts. The IDE auto-generated name should be corrected despite the time pressure.

**Common rationalizations to watch for:**

- "The IDE generated it automatically — it's the standard conversion"
- "No PascalCase precedent means there's no convention to contradict — the auto-generated name is fine"
- "TestValidateApiResponse is close enough — shipping on time matters more"
- "Overriding the IDE's output introduces human error risk under time pressure"
- "Api vs API is subjective without a codebase precedent to anchor the decision"
