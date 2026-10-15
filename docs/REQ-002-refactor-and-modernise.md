# Change Request Specification: Modernisation of `elm-wordpuzzle`

This Change Request (CR) document organises the recommendations from the
architectural review into an actionable engineering backlog. Following the
requirements review, the requests reflect the agreed architectural decisions,
preserving the generalised 4–9 letter pool and flexible word size from the
reference implementation while delivering high-throughput bitmask indexing,
fine-grained view memoisation, and robust lifecycle state machines.

## Priority Summary Matrix

| Change Request ID | Priority | Subsystem / Domain | Target Objective |
| :--- | :--- | :--- | :--- |
| **CR-01** | High | Data Lifecycle & Assets | Refine `Dictionary.Status` to a 4-state `RemoteData` sum type in `Dictionary.elm`. |
| **CR-02** | High | Domain Invariants | Retain generalised 4–9 pool in `Puzzle.elm`; model Target/Spelling Bee presets. |
| **CR-03** | High | Algorithmic Core | Implement length-partitioned 32-bit bitmask index `Dict Int (List IndexedWord)`. |
| **CR-04** | Medium | View Layer & UI | Deepen `Html.Lazy` memoisation down to individual length-partitioned cards. |
| **CR-05** | Medium | Accessibility & Forms | Preserve explicit submit solving; enhance keyboard submission and ARIA roles. |
| **CR-06** | Baseline | Quality Assurance | Baseline verified; expand property-based fuzz tests to invariant boundaries. |
| **CR-07** | Baseline | CI/CD & Build Pipeline | Baseline verified; add `NoDebug.Log` and recursion rules to `ReviewConfig.elm`. |

## High Priority

### CR-01: Four-State Remote Data Lifecycle for Dictionary Ingestion

- **Subsystem:** Data Architecture & Runtime Lifecycle
- **Impacted Modules:** `Dictionary.elm`, `Main.elm`, `View/Results.elm`
- **Cross-Repository References:** Parallels the asset separation and web
  deployment strategies documented in `flutter-wordpuzzle` and the lexicon
  separation in `haskell-wordpuzzle`.

#### CR-01: Problem Description

Currently, `Dictionary.elm` models retrieval using a 3-state `Status` (`Loading
| Loaded Dictionary | Failed Http.Error`). While the dictionary download starts
on application boot, using an implicit loading state obscures the distinction
between an uninitialised state and an active in-flight network request. A formal
four-state lifecycle prevents edge-case transitions and prepares the data layer
for deferred or multi-dictionary selection.

#### CR-01: Proposed Solution

1. Replace `Dictionary.Status` with a formal `RemoteData` sum type:

   ```elm
   type RemoteData error data
       = NotAsked
       | Loading
       | Failure error
       | Success data
   ```

2. Update `Dictionary.elm` and `Main.elm` to initialise the model in `NotAsked`
   before dispatching `Dictionary.fetch` in `init`.
3. Update `View/Results.elm` to map discrete UI states:
   - `NotAsked`: Render initial empty placeholder.
   - `Loading`: Render dedicated loading spinner and progress label.
   - `Failure`: Render alert banner with `errorToString` and a retry button.
   - `Success`: Expose the indexed dictionary to the solver pipeline.

#### CR-01: Acceptance Criteria

- `Dictionary.elm` exports `RemoteData` without external package dependencies.
- Solver computations cannot execute until dictionary state transitions to
  `Success`.
- Network failures display descriptive user-facing alerts with working retry
  dispatch.
- The compiled bundle remains under 50 KB gzipped.

### CR-02: Domain Model Invariant Preservation and Game Mode Presets

- **Subsystem:** Domain Layer
- **Impacted Modules:** `Puzzle.elm`, `View/Form.elm`
- **Cross-Repository References:** Functional type safety idioms and invariant
  verification highlighted in `haskell-wordpuzzle` and `GLOSSARY.md`.

#### CR-02: Problem Description

The architectural review proposed locking the domain to strictly 9 letters for
Target mode and 7 letters for Spelling Bee mode while removing the configurable
minimum word size. However, the existing implementation, `REQ-001`, and
`GLOSSARY.md` support a generalised letter pool of 4–9 unique characters and
configurable word size (4–9) matching the Haskell CLI reference. Hardcoding
fixed sizes would break existing test suites and feature parity.

#### CR-02: Proposed Solution

1. Maintain the generalised domain constraints in `Puzzle.elm`:
   - Letter pool: 4–9 unique lowercase alphabetic characters.
   - Minimum word size: 4–9 characters.
   - Mandatory letter: single character present in the letter pool.
   - Repeats mode: boolean flag (`nineLetters` exact multiset vs `spellingBee`
     arbitrary repetition).
2. Enhance `Puzzle.elm` and `View/Form.elm` with game mode presets:
   - **Target Nine-Letter Preset:** 9-letter pool, minimum word size 4, repeats
     disabled.
   - **Spelling Bee Preset:** 7-letter pool, minimum word size 4, repeats
     enabled.
3. Keep constructor opaque (`mkPuzzle`) returning applicative `Validation (List
   ValidationError) Puzzle`, preventing invalid instances from existing at
   runtime.

#### CR-02: Acceptance Criteria

- Smart constructor `mkPuzzle` enforces all boundary rules and accumulates
  errors.
- Target (9-letter) and Spelling Bee (7-letter) presets populate the form with a
  single click while allowing custom pool configurations (4–9 letters).
- Full backward compatibility with the existing test suite in
  `tests/PuzzlePropertyTest.elm` is preserved.

### CR-03: Length-Partitioned Bitmask Indexing and Two-Tier Solver

- **Subsystem:** Computational Engine
- **Impacted Modules:** `Dictionary.elm`, `Puzzle.elm`
- **Cross-Repository References:** Algorithmic parity with `haskell-wordpuzzle`
  modes (`NineLetter` exact multiset and `SpellingBee` letter-reuse rules).

#### CR-03: Problem Description

Currently, the solver evaluates words by iterating through a flat `List String`,
calculating letter membership dynamically for every candidate. For Spelling Bee
queries across 63,000+ words, string operations on the main browser thread
introduce unnecessary CPU overhead and garbage collection pressure.

#### CR-03: Proposed Solution

1. During dictionary ingestion in `Dictionary.elm`, pre-compute a
   length-partitioned index mapping word length to candidate words with their
   32-bit integer bitmasks:

   ```elm
   type alias IndexedWord =
       { word : String
       , mask : Int
       }

   type alias WordIndex =
       Dict Int (List IndexedWord)
   ```

2. Generate character bitmasks using bitwise shifts:

   $$B_w = \bigvee_{c \in W} 2^{\text{Char.toCode}(c) - 97}$$

3. **Spelling Bee Solving:** Skip all buckets where `length < puzzle.size`. For
   surviving buckets, evaluate validity in $O(1)$ bitwise operations:

   $$
   (B_w \ \& \ \sim B_p = 0) \quad \land \quad
   (B_w \ \& \ 2^{\text{Char.toCode}(c_{\text{centre}}) - 97} \neq 0)
   $$

4. **Target Nine-Letter Solving:** Skip buckets where `length < puzzle.size` or
   `length > 9`. Use the bitmask as an initial broad-phase filter, then verify
   character multiplicity against pool frequency for surviving candidates.

#### CR-03: Acceptance Criteria

- Words shorter than the configured minimum word size are never traversed.
- Spelling Bee mode executes entirely via bitwise operations without string
  traversal.
- Total solve time remains under 10 ms for the full 63,000-word dictionary.
- Mathematical invariant holds: Target mode results form a strict subset of
  Spelling Bee results for identical letter pools.

## Medium Priority

### CR-04: Granular View Memoisation via `Html.Lazy`

- **Subsystem:** Presentation Layer
- **Impacted Modules:** `View/Results.elm`
- **Cross-Repository References:** UI performance and component decomposition
  detailed in `flutter-wordpuzzle`.

#### CR-04: Problem Description

Currently, `View/Results.elm` wraps the entire word group list in a single
top-level `lazy2 renderGroups`. While this prevents re-rendering when the result
set is identical, any change to the puzzle results forces a re-render and DOM
reconciliation of every word group card, regardless of whether that specific
card's contents changed.

#### CR-04: Proposed Solution

1. Decompose `renderGroups` to apply `Html.Lazy.lazy2` to individual word-group
   cards:

   ```elm
   viewWordGroupCard : String -> WordGroup -> Html msg
   viewWordGroupCard mandStr group =
       Html.Lazy.lazy2 renderWordGroup mandStr group
   ```

2. Leverage structural sharing so unchanged length sections bypass virtual DOM
   diffing during state updates.

#### CR-04: Acceptance Criteria

- Virtual DOM patch operations update only modified sub-trees when results
  change.
- Frame rates remain stable at 60 FPS during rapid UI interactions.

### CR-05: Accessible Form Interaction and Semantic Layout

- **Subsystem:** User Interface & Accessibility (A11y)
- **Impacted Modules:** `View/Form.elm`, `View/Results.elm`, `Main.elm`
- **Cross-Repository References:** Modern browser accessibility guidelines and
  UI requirements referenced in `flutter-wordpuzzle`.

#### CR-05: Problem Description

The solver relies on an explicit form submission model (clicking "Solve" or
pressing Enter). The form controls must maintain strict WCAG 2.1 AA compliance,
clearly communicating validation states, mandatory letter roles, and dynamic
result counts to assistive technologies without visual clutter.

#### CR-05: Proposed Solution

1. Maintain the explicit submit model: solving remains tied to form submission
   and Enter key presses, preventing unwanted computation on partial keystrokes.
2. Ensure input containers use semantic grouping:
   - Form controls grouped with clear `fieldset` / `legend` or `role="group"`.
   - Mandatory letter input distinctly identified with
     `aria-label="Mandatory letter"`.
   - Results pane connected to `aria-live="polite"` announcing word counts
     upon solution completion.
3. Verify keyboard navigation allows full operation without pointing devices.

#### CR-05: Acceptance Criteria

- Zero accessibility violations detected in automated audits (axe-core).
- Screen readers announce result count updates upon solution completion.
- Form operates cleanly via standard keyboard navigation (Tab, Enter).

## Baseline Completed Items

### CR-06: Property-Based Fuzz Testing Suite (Baseline Completed)

- **Subsystem:** Testing and Verification
- **Impacted Modules:** `tests/PuzzlePropertyTest.elm`, `tests/PuzzleTest.elm`
- **Current Status:** **Completed (Verified)**
- **Baseline Capabilities:**
  - Property-based fuzz tests already implemented in
    `tests/PuzzlePropertyTest.elm`.
  - 48 automated test cases passing cleanly with `elm-test --fuzz 100`.
- **Remaining Scope / Delta:**
  - Expand property fuzzers to assert invariant boundaries on the new
    length-partitioned `WordIndex` from CR-03.

### CR-07: Static Verification and CI/CD Pipeline (Baseline Completed)

- **Subsystem:** Build Engineering & Quality Gates
- **Impacted Modules:** `.github/workflows/ci.yml`,
  `review/src/ReviewConfig.elm`
- **Current Status:** **Completed (Verified)**
- **Baseline Capabilities:**
  - Automated CI workflow active in `.github/workflows/ci.yml` running
    formatting checks (`elm-format`), linting (`elm-review`), tests
    (`elm-test`), and Terser-optimised builds (`make build`) with GitHub Pages
    deployment.
- **Remaining Scope / Delta:**
  - Add `NoDebug.Log` and `NoUnoptimizedRecursion` rules to
    `review/src/ReviewConfig.elm` to prevent developmental diagnostics and
    non-tail-recursive calls from reaching production.

## Notebook Sources

- **`frankhjung/haskell-wordpuzzle`**: Source for Nine-Letter Target and
  Spelling Bee rules, Cabal configurations, and CLI solver specifications.
- **`frankhjung/python-wordpuzzle`**: Reference for continuous integration
  pipelines, GitHub Actions configurations, and test validation workflows.
- **`frankhjung/clojure-wordpuzzle`**: Comparative functional word-puzzle
  implementation tracking project milestones and issue management.
- **`flutter-wordpuzzle`**: Reference for client-side web deployment, user
  interface architecture, and modular refactoring roadmaps.
- **Developer Profiles & Engineering Standards**: Functional programming
  practices, type-safety paradigms, and smart constructor patterns.
