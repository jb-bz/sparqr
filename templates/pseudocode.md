# Pseudocode: <feature or system name>

> Stage 3 of SPARC+Design. High-level logic without implementation details. The Architecture stage will turn this into a system design; the Refinement stage will turn that into code.

## Algorithm Overview

<one paragraph: what's the core algorithm/flow? what's the time/space complexity? what are the key tradeoffs?>

## Numbered Steps

1. <step — high-level action, not implementation>
2. <step>
3. <step>
4. <step>
5. <step>
6. <step>
7. <step>
8. <step — as many as needed, typically 5-30>

## Decision Points

### Decision 1: <name>
- **Condition**: <when this branch is taken>
- **Then**: <what happens>
- **Else**: <what happens>

### Decision 2: <name>
- **Condition**: <when>
- **Then**: <what>
- **Else**: <what>

## Data Structures

### Structure 1: <name>
- **Fields**:
  - `field_a`: <purpose>
  - `field_b`: <purpose>
  - `field_c`: <purpose>
- **Lifetime**: <created when, destroyed when>
- **Owned by**: <which component>

### Structure 2: <name>
- …

## Edge Cases

| Case | Expected behavior | Notes |
|---|---|---|
| Empty input | <behavior> | <e.g. return empty result, do not error> |
| Max-size input | <behavior> | <e.g. paginate, stream> |
| Partial failure mid-operation | <behavior> | <e.g. rollback / partial commit> |
| Concurrent access | <behavior> | <e.g. lock or queue> |
| Network timeout | <behavior> | <e.g. retry 3x with backoff> |
| Duplicate request | <behavior> | <e.g. idempotency key> |

## Complexity

- **Time**: <Big-O analysis per major operation>
- **Space**: <Big-O analysis>

## Dependencies on Other Components

- **Calls into**: <list of components / services this algorithm depends on>
- **Called by**: <list of callers>
- **Shared state with**: <list, if any — shared state is a risk and should be explicit>

## Open Pseudocode Questions

- <any logic that's still unclear and needs to be resolved before/during Architecture>
