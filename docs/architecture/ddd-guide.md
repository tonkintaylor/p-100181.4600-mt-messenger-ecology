# Domain-Driven Design Guide — Data Pipeline Architecture

## Purpose

Apply DDD principles to data pipeline projects. Use this guide when:

- Designing module boundaries and data flow
- Deciding what belongs in a domain vs. shared infrastructure
- Reviewing whether a design is testable, maintainable, and extensible

## Viability Check

Use DDD patterns when at least two of these are true:

- Multiple source formats feed into a common output (anti-corruption needed)
- Business rules are domain-specific and must be ecologist/scientist-signed
- The system must be maintainable by people other than the original author
- Future domains will be added incrementally (extensibility matters)

Skip full DDD when:

- Simple CRUD or single-file script
- No domain complexity (just reshaping data)
- Throwaway / exploratory work

## Core Concepts (Adapted for Data Pipelines)

### Ubiquitous Language

Code uses the same terms as the domain expert. In an ecological monitoring
pipeline, this means:

- ✅ `taxa`, `site`, `season`, `replicate`, `qmci`, `ept_richness`
- ❌ `column_A`, `input_df`, `result_array`, `value1`

Column names, function names, module names, and error messages should all be
readable by the ecologist who reviews the output.

### Bounded Context

A boundary within which a particular domain model applies. Each bounded context:

- Has its own internal model (data shapes, validation rules, business logic)
- Exposes a clear interface to the outside (what it accepts, what it returns)
- Does NOT leak its internal details to other contexts

**In a data pipeline, a bounded context is typically a domain module** — e.g.
`macroinvertebrate`, `sediment`, `sediment_size`. Each module knows how to read
its source, validate it, and transform it into the target shape.

### Context Map

How bounded contexts relate to each other:

```
┌──────────────────┐       ┌─────────────────────┐
│ Macroinvertebrate│       │ Sediment            │
│ Context          │       │ Context             │
│                  │       │                     │
│ Source: MacroDB  │       │ Source: AquaticDB   │
│ Output: Macro1,  │       │ Output: Sediment,   │
│   MacroSpecies   │       │   SedimentSize      │
└────────┬─────────┘       └──────────┬──────────┘
         │                            │
         ▼                            ▼
┌──────────────────────────────────────────────────┐
│ Shared Kernel: Site, Season, Period, validation  │
└──────────────────────────────────────────────────┘
         │                            │
         ▼                            ▼
┌──────────────────────────────────────────────────┐
│ Writer (Infrastructure): Assembles Data.xlsx     │
└──────────────────────────────────────────────────┘
```

## Building Blocks

### Value Object

Immutable, equality by value. Use for domain concepts that have rules.

```python
from dataclasses import dataclass

@dataclass(frozen=True)
class Site:
    """A monitoring site with validated code."""
    code: str

    def __post_init__(self) -> None:
        valid = {"EM1", "EM2", "EM3", "EM4", "EM5", "EM7", "EM8", "MMA6", "MMA6b"}
        if self.code not in valid:
            msg = f"Unknown site: {self.code!r}. Expected one of {sorted(valid)}"
            raise ValueError(msg)

@dataclass(frozen=True)
class Season:
    """A monitoring season (e.g. 'Baseline', 'Construction', 'Routine')."""
    label: str
    start: date
    end: date
```

### Entity

Has identity that persists. In a data pipeline, entities are rare — most things
are value objects. An entity might be a `Sample` (identified by site + date +
replicate) or a `MonitoringCycle` (identified by reporting period).

### Aggregate

A cluster of objects treated as a unit with invariants enforced at the boundary.
In a data pipeline, the aggregate is typically the **domain module's output** —
the complete validated DataFrame that either exists in full or not at all.

```python
@dataclass
class MacroResult:
    """Aggregate: complete macroinvertebrate domain output."""
    macro1: pd.DataFrame      # 175×7 validated
    macro_species: pd.DataFrame  # 3194×6 validated

    def __post_init__(self) -> None:
        # Invariant: sites in macro1 must match sites in macro_species
        m1_sites = set(self.macro1["Site"].unique())
        ms_sites = set(self.macro_species["Site"].unique())
        if m1_sites != ms_sites:
            msg = f"Site mismatch: macro1 has {m1_sites}, macro_species has {ms_sites}"
            raise ValueError(msg)
```

### Anti-Corruption Layer (ACL)

Translates between messy external formats and your clean domain model. The
**ingest step** of each domain module IS the anti-corruption layer:

```python
def ingest_raw_data(path: Path) -> RawDataSheet:
    """ACL: reads the messy multi-row-header spreadsheet into a clean internal form."""
    # Handles: merged cells, QA flags, non-rectangular headers
    # Returns: a well-typed internal representation
    ...
```

The ACL is the ONLY place that knows about the source format. If Geotechnics
changes their template, only the Geotechnics ACL changes — nothing downstream.

### Domain Service

Logic that doesn't belong to a single entity/value object. In this project,
**metric derivation** is a domain service:

```python
def derive_metrics(taxa_counts: pd.DataFrame, mci_scores: pd.DataFrame) -> pd.DataFrame:
    """Domain service: compute MCI, QMCI, EPT from raw counts and tolerance scores.

    This logic is ecologist-signed. Changes require domain expert review.
    """
    ...
```

## Strategic Patterns

### Shared Kernel

A small, explicitly managed set of concepts shared across bounded contexts:

- `Site` — monitoring site codes and their properties (has_replicates, catchment)
- `Season` / `Period` — temporal classification of samples
- `ValidationError` — common error representation with file/sheet/cell pointers
- Schema definitions for the output contract (Data.xlsx column specs)

Keep the shared kernel **small and stable**. If something is only used by one
domain, it belongs in that domain, not the kernel.

### Open Host Service

The `writer.py` module acts as an open host: it accepts a standard interface
(DataFrames with known schemas) from any domain module and emits the xlsx. New
domains plug in by conforming to the interface, not by modifying the writer.

## Design Checklist

When reviewing architecture, ask:

1. **Could someone understand this module without reading its internals?**
   - Clear inputs, clear outputs, named at the domain level
2. **Could you change the source format without touching other modules?**
   - Anti-corruption layer isolates format knowledge
3. **Could you add a new domain without modifying existing ones?**
   - Orchestrator discovers/calls domains; domains don't know about each other
4. **Are domain rules in the domain, not in infrastructure?**
   - Metric derivation lives in `domains/macro.py`, not in `writer.py`
5. **Would an ecologist recognise the function names?**
   - Ubiquitous language test

## Module Layout Template

```
src/mgen/
  config.py              # Read cycle.toml, resolve paths
  pipeline.py            # Orchestrator: load config, call domains, emit or report
  validation.py          # Shared validation primitives (schema, range, null checks)
  shared/
    __init__.py
    types.py             # Value objects: Site, Season, Period
    schemas.py           # Output DataFrame schemas (column names, dtypes)
    errors.py            # ValidationError with file/sheet/cell context
  domains/
    __init__.py
    macro.py             # ACL + derive + transform → Macro1 + Macro
    macro_species.py     # ACL + pivot → MacroSpecies
    sediment.py          # ACL + reshape → Sediment
    sediment_size.py     # ACL + reshape → SedimentSize
  writer.py              # Infrastructure: DataFrame → Data.xlsx (5 sheets)
```

## Anti-Patterns to Avoid

- **Anemic domain modules** — don't put all logic in pipeline.py and make domains
  just readers. Each domain owns its validation and transformation.
- **Leaky abstractions** — don't pass raw openpyxl objects between modules. Each
  module converts to pandas internally.
- **Shared mutable state** — domains return results, they don't mutate a shared
  context object.
- **Over-engineering** — no event bus, no microkernel, no DI container. This is a
  data pipeline with 4 domains and <2000 lines of code. Protocols and dataclasses
  are sufficient.

## When to Use These Patterns

| Pattern | Use when... | Skip when... |
|---------|-------------|--------------|
| Value Object | A concept has validation rules (Site, Season) | It's just a string with no invariants |
| ACL | Reading from a messy external format | Source is already clean |
| Domain Service | Logic spans multiple value objects | Logic is trivial (one-liner) |
| Shared Kernel | Multiple domains need the same concept | Only one domain uses it |
| Aggregate | Multiple outputs must be consistent together | Outputs are independent |

## References

- Evans, Eric. *Domain-Driven Design*. Addison-Wesley, 2003.
- Fowler, Martin. "BoundedContext." martinfowler.com/bliki.
- Vernon, Vaughn. *Implementing Domain-Driven Design*. Addison-Wesley, 2013.
