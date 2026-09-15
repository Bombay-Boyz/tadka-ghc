# Tadka-GHC

## Gold-Standard Implementation Specification

**Version:** 1.0  
**Parent specification:** Tadka-GHC Vision, Architecture and Gold-Standard Engineering Specification v9.0  
**Implementation baseline:** audited Tadka repository at `bc750f8`  
**Status:** Implementation specification; normative for engineering execution once the readiness gates below are closed

---

# 0. Purpose and authority

This document answers a different question from the Vision specification.

The Vision defines **what Tadka-GHC means**, the semantic contract it must satisfy, the compatibility boundary, and the architectural constraints.

This document defines **how the engineering team shall implement, verify, and release it** without weakening those contracts.

The authority order is:

```text
GHC protocol/schema contract
        ↓
Tadka public API and established semantics
        ↓
Tadka-GHC Vision v9.0
        ↓
this Implementation Specification
        ↓
individual implementation choices
```

An implementation choice is invalid when it contradicts a higher-level contract, even if it is simpler, shorter, or faster.

This document is intentionally more concrete than the Vision. It specifies package boundaries, module responsibilities, type-state boundaries, development order, test requirements, review gates, and release certification.

---

# 1. Implementation objective

The implementation shall deliver a Tadka-GHC adapter with this semantic pipeline:

```text
raw GHC diagnostic record
        │
        ▼
      decode
        │
        ▼
     validate
        │
        ▼
     normalize
        │
        ▼
      translate
        │
        ▼
 native Tadka Diagnostic
```

Process integration is outside that pure semantic pipeline:

```text
GHC process
    │
    │ stderr / structured diagnostics
    ▼
JSON-Lines framing
    │
    ▼
pure semantic pipeline
    │
    ▼
Tadka Diagnostic
    │
    ▼
existing Tadka renderers / consumers
```

The implementation must preserve the following invariant:

> No stage may consume a weaker representation merely because the underlying runtime value is still available.

The type of a stage is part of the proof that the previous stage's obligations have been discharged.

---

# 2. Repository constraints established by the Tadka audit

The implementation is constrained by the current Tadka repository, not by an imagined API.

## 2.1 Existing Tadka diagnostic authority

The adapter shall construct and populate the existing Tadka `Diagnostic` abstraction. It shall not introduce a parallel public diagnostic type that duplicates Tadka's message, severity, context, code, help, URL, related, or cause semantics.

## 2.2 Existing span authority

Tadka already distinguishes unresolved and resolved spans through its type-indexed span model.

The adapter shall use Tadka's source and span construction machinery rather than defining an alternative line/column/offset representation at the Tadka boundary.

## 2.3 Existing context authority

Tadka already supports multi-source contexts, primary and secondary labels, and explicit degradation/stale-label semantics.

The adapter shall preserve those semantics and must not silently drop a location because source resolution fails.

## 2.4 Existing GHC span interop

The existing `Tadka.Interop.GHC` package remains a distinct abstraction for converting GHC `SrcSpan` values into Tadka spans.

It shall not be repurposed into a structured-diagnostic parser merely for code reuse.

Shared semantic algorithms may be extracted only where the common abstraction is real and improves correctness.

## 2.5 Historical correctness constraints

The repository history contains fixes for:

- silent label loss;
- missing related-diagnostic causes;
- GHC span misattribution;
- span-end overflow.

These are treated as regression-sensitive semantics. Any implementation that touches related diagnostics, endpoint resolution, or span arithmetic must preserve the associated behavior and include explicit regression tests.

---

# 3. Implementation readiness gate

No implementation phase beyond repository scaffolding may be declared started until Gates A-G from Vision v9.0 have been addressed.

The gates are converted here into concrete engineering artifacts.

## Gate A — Tadka baseline

Record:

```text
Tadka repository revision: bc750f8
Tadka package version: <record exact value from tadka.cabal>
GHC versions used to build/test Tadka baseline: <record>
public modules consumed by Tadka-GHC: <record>
```

The implementation branch shall pin or document the intended Tadka dependency range.

## Gate B — exact external schema artifacts

Obtain and commit, as test fixtures or otherwise deterministically vendor/reference them:

```text
GHC 9.10.3 → exact schema artifact
GHC 9.12.4 → exact schema artifact
GHC 9.14.1 → exact schema artifact
```

The 9.12.4 schema shall not be inferred from adjacent releases.

For every schema artifact record:

```text
compiler release
schema identifier/version
source URL or release artifact
retrieval date
checksum
schema compatibility classification
```

## Gate C — actual emitted fixtures

For every supported compiler version, produce real diagnostics from actual GHC executions covering all supported semantic cases.

The fixture set must include ordinary and adversarial examples.

## Gate D — diagnostic identity

Resolve the mapping from GHC producer identity/code to Tadka `DiagnosticCode` before implementation freeze.

A temporary string transformation is not an acceptable substitute.

## Gate E — source acquisition

Freeze the source environment contract before span implementation.

At minimum specify:

```haskell
newtype SourceId = SourceId ...

data SourceEnvironment = ...
```

The source environment must define lookup, missing-source behavior, and source identity semantics without depending on process I/O.

## Gate F — representability matrix

Create a field-by-field table:

| GHC field/semantic | Tadka destination | policy | loss? | proof/test |
|---|---|---|---|---|

Every field must be classified as exactly one of:

```text
preserved
normalized without semantic change
explicitly discarded by contract
translation error because no faithful representation exists
```

There is no implicit `best effort` category.

## Gate G — worked end-to-end proof example

At least one real diagnostic from each supported GHC release must be traced:

```text
raw bytes
 → decoded value
 → validated value
 → normalized value
 → Tadka construction
 → rendered observation
```

The trace must identify where each piece of semantic information goes.

---

# 4. Package architecture

The initial implementation shall use a dedicated package for structured GHC diagnostics while preserving the existing Tadka packages.

Target layout:

```text
tadka/
  core public API
  interop/ghc/                 existing SrcSpan adapter
  ...

tadka-ghc/
  src/
    Tadka/GHC/
      ...
  test/
    ...
  fixtures/
    ghc-9.10.3/
    ghc-9.12.4/
    ghc-9.14.1/
  tadka-ghc.cabal
```

The exact package name remains subject to repository naming conventions, but the dependency direction is fixed:

```text
tadka-ghc → tadka
```

Never:

```text
tadka → tadka-ghc
```

and never:

```text
Tadka core → GHC diagnostic JSON schema
```

---

# 5. Module architecture

The initial module graph should be approximately:

```text
Tadka.GHC.Schema.*
        │
        ▼
Tadka.GHC.Decode
        │
        ▼
Tadka.GHC.Validate
        │
        ▼
Tadka.GHC.Normalize
        │
        ├──────────────► Tadka.GHC.Source
        │
        ▼
Tadka.GHC.Translate
        │
        ▼
Tadka

Tadka.GHC.Stream
        │
        ▼
Tadka.GHC.Decode / Validate / Normalize / Translate

Tadka.GHC.Process
        │
        ▼
Tadka.GHC.Stream
```

Responsibilities are strict.

## 5.1 `Schema`

Owns the exact wire representation for a specific supported schema.

It may contain:

- generated schema bindings;
- wire enumerations;
- optional fields;
- schema-version-specific compatibility code.

It must not construct Tadka diagnostics.

## 5.2 `Decode`

Owns only conversion:

```text
ByteString → schema-typed value
```

It must not perform semantic normalization.

## 5.3 `Validate`

Owns structural and schema-domain invariants that the decoder itself does not establish.

Examples:

- required field combinations;
- bounded recursion/collection constraints;
- cross-field validity;
- supported schema variants.

## 5.4 `Normalize`

Owns conversion from validated schema-specific values into one canonical GHC semantic representation.

This is where schema-version differences disappear when and only when they are semantically equivalent.

## 5.5 `Source`

Owns pure source lookup and source-coordinate transformation required to construct Tadka spans.

It must not read files itself.

## 5.6 `Translate`

Owns the semantic mapping:

```text
NormalizedGhcDiagnostic → Tadka Diagnostic
```

Only this layer should depend on the Tadka diagnostic construction API.

## 5.7 `Stream`

Owns JSON-Lines framing and record boundaries.

A stream framing error must remain distinct from a semantic diagnostic translation error.

## 5.8 `Process`

Owns:

- launching GHC;
- forwarding arguments;
- environment policy;
- stdout/stderr handling;
- exit status;
- process lifecycle.

It must not contain diagnostic semantics.

---

# 6. Concrete type-state architecture

The implementation shall preserve these type-state boundaries even if constructor names change during implementation review.

## 6.1 Raw input

```haskell
newtype RawDiagnosticLine = RawDiagnosticLine ByteString
```

No semantic assumptions are attached to this type.

## 6.2 Parsed schema value

```haskell
data SchemaVersion = ...

-- Exact representation is schema-specific.
data ParsedGhcDiagnostic = ...
```

The implementation may use distinct types for each schema where this materially improves exhaustiveness.

Preferred pattern:

```haskell
data GhcSchema
  = Schema_9_10_1_0
  | Schema_9_12_<exact>
  | Schema_9_14_1_1
```

The actual constructors must come from the pinned artifacts, not from assumption.

## 6.3 Validated value

```haskell
newtype ValidatedGhcDiagnostic = ValidatedGhcDiagnostic
  { unValidatedGhcDiagnostic :: ParsedGhcDiagnostic
  }
```

The constructor should remain internal.

A value of this type means schema/domain validation has completed.

## 6.4 Normalized semantic value

The normalized representation must remain independent of Tadka types.

The shape shall be along the following lines:

```haskell
data NormalizedGhcDiagnostic = NormalizedGhcDiagnostic
  { ngSeverity  :: !GhcSeverity
  , ngReason    :: !GhcDiagnosticReason
  , ngMessage   :: !Text
  , ngCode      :: !(Maybe GhcDiagnosticCode)
  , ngLocations :: ![NormalizedLocation]
  , ngHelp      :: ![NormalizedHelp]
  , ngRelated   :: ![NormalizedRelated]
  , ngCause     :: !(Maybe NormalizedCause)
  }
```

The exact field set is determined by the representability matrix.

Do not use Tadka `Severity`, `Doc`, `Url`, `Span`, or `Diagnostic` inside this type merely for convenience.

## 6.5 Normalized locations

Conceptually:

```haskell
data NormalizedLocation = NormalizedLocation
  { nlSource    :: !SourceId
  , nlStart     :: !GhcPosition
  , nlEnd       :: !GhcPosition
  , nlRole      :: !LocationRole
  , nlLabel     :: !(Maybe Text)
  }
```

`LocationRole` must distinguish semantic roles such as primary and secondary when the source protocol does so.

If the wire format contains an ambiguity between roles, that ambiguity must be resolved in validation/normalization, not hidden in translation.

## 6.6 GHC coordinate type

Do not represent line/column positions as anonymous tuples.

Use an explicit type, for example:

```haskell
data GhcPosition = GhcPosition
  { gpLine   :: !Integer
  , gpColumn :: !Integer
  }
```

The exact numeric domain must follow the proven protocol bounds. `Integer` is acceptable when it simplifies overflow-proof arithmetic and the values are later validated against source bounds.

Do not convert to `Int` merely because the eventual Tadka API uses machine integers.

The conversion boundary must prove that narrowing is safe.

---

# 7. Pure API

The pure API shall be explicit and compositional.

Conceptually:

```haskell
decode
  :: SchemaVersion
  -> RawDiagnosticLine
  -> Either DecodeError ParsedGhcDiagnostic

validate
  :: ParsedGhcDiagnostic
  -> Either ValidationError ValidatedGhcDiagnostic

normalize
  :: ValidatedGhcDiagnostic
  -> Either NormalizationError NormalizedGhcDiagnostic

translate
  :: SourceEnvironment
  -> NormalizedGhcDiagnostic
  -> Either TranslationError TadkaDiagnostic

adapt
  :: SchemaVersion
  -> SourceEnvironment
  -> RawDiagnosticLine
  -> Either AdapterError TadkaDiagnostic
```

`adapt` must be composition, not a second implementation:

```haskell
adapt schema sources line = do
  parsed     <- decode schema line
  validated  <- validate parsed
  normalized <- normalize validated
  translate sources normalized
```

No semantic logic may be duplicated between `adapt` and the individual phases.

---

# 8. Error algebra

Errors must encode the phase in which the contract failed.

Conceptually:

```haskell
data AdapterError
  = AdapterDecode !DecodeError
  | AdapterValidation !ValidationError
  | AdapterNormalization !NormalizationError
  | AdapterTranslation !TranslationError
```

Integration errors remain separate:

```haskell
data StreamError
  = InvalidFrame !FrameError
  | UnexpectedEnd
  | ResourceLimitExceeded !Limit
  ...

data ProcessError
  = SpawnFailure ...
  | ExitFailure ...
  | IoFailure ...
  ...
```

Do not collapse all failures into a single textual exception.

Do not use `Either Text` as the public semantic error API.

Every constructor that can occur in production must have a deterministic diagnostic meaning and test case.

---

# 9. Schema implementation strategy

## 9.1 Generated versus handwritten bindings

If the schema artifacts are stable and machine-readable, generated Haskell bindings are preferred for the wire representation.

Generated code must be checked into the repository or generated reproducibly in the build, according to the project's established source-generation policy.

Schema bindings must not become semantic business logic.

## 9.2 Closed-world schema representation

For all finite schema domains where exhaustiveness is practical, prefer closed algebraic data types.

Examples:

```haskell
data DiagnosticReason
  = ...
```

and:

```haskell
case reason of
  ...
```

Compiler warnings for incomplete matches shall be treated as build failures for semantic modules.

## 9.3 Unknown schema versions

An unknown schema version must fail explicitly.

Never decode it as the nearest known schema based only on compiler version.

## 9.4 Unknown fields

Unknown optional fields may be ignored only when the compatibility matrix explicitly classifies them as semantically irrelevant to the supported contract.

Unknown required semantics must reject the input.

---

# 10. Source environment implementation

The source environment is pure data plus pure lookup operations.

Conceptually:

```haskell
data SourceEnvironment = SourceEnvironment
  { sourceLookup :: SourceId -> Either SourceLookupError SourceText
  }
```

The implementation may use a map-backed representation for normal use.

File I/O occurs only at the process/integration boundary.

The semantic core must never open files itself.

## 10.1 Source identity

Source identity must preserve the producer's identity sufficiently to distinguish files that carry distinct diagnostic locations.

Normalize path syntax only under an explicit contract.

Do not silently convert:

```text
relative path ↔ absolute path
case-sensitive ↔ case-insensitive identity
symlink identity ↔ canonical identity
```

unless the contract explicitly requires it.

## 10.2 Missing source text

The behavior must be explicit.

Possible valid outcomes are:

```text
translation error
or
Tadka stale/unresolved label
```

The chosen behavior must follow Tadka semantics and the representability matrix.

It must never silently move or shrink a span to make it fit.

---

# 11. Span implementation

The span implementation is one of the highest-risk components.

## 11.1 Coordinate conversion

For each supported schema cell, document:

```text
line origin
column origin
column metric
end-position inclusivity/exclusivity
zero-width semantics
```

There shall be one conversion function per contractually distinct coordinate convention.

Do not encode the convention as an unexplained `+ 1` or `- 1`.

Prefer named transformations whose laws are obvious from the type and name.

## 11.2 Endpoint attribution

The current Tadka history demonstrates that start and end endpoint failures must not be conflated.

The implementation must test separately:

```text
valid start / valid end
invalid start / valid end
valid start / invalid end
invalid start / invalid end
```

## 11.3 Overflow

All intermediate arithmetic used to calculate offsets must use a domain proven large enough for the input.

Do not repeat the historical `Int` overflow failure mode.

Where narrowing is necessary, prove the bound first.

## 11.4 Tadka span construction

Only after GHC coordinates have been validated and resolved against the source environment may the implementation invoke Tadka span construction.

Do not construct fake Tadka spans and then attempt to repair them later.

---

# 12. Diagnostic construction

Translation should proceed in a fixed order so the implementation reads like the semantic mapping.

Recommended order:

```text
message
severity
code
source context
primary labels
secondary labels
help
URL, if faithfully representable
related diagnostics
cause
```

The actual order may follow Tadka's builder/constructor API, but the semantic dependencies must remain visible.

## 12.1 Primary versus secondary locations

Location role is semantic information and must not be inferred from list position unless the GHC contract explicitly defines list position as the role.

## 12.2 Related diagnostics

Related diagnostics must retain their relationship to the parent diagnostic.

The repository's existing related/cause semantics must be reused.

## 12.3 Causes

A GHC cause/nested diagnostic is not the same as an ordinary related diagnostic unless the schema says so.

Preserve the distinction all the way through normalization and translation.

---

# 13. Diagnostic code implementation

This is a release-blocking area.

Before coding the final representation, produce:

```text
GHC producer
GHC diagnostic identity
Tadka DiagnosticCode
provenance preservation
collision analysis
rendering consequence
```

The implementation shall guarantee:

```text
injective mapping
```

over the supported GHC code domain unless the compatibility specification proves that two producer identities are semantically identical.

A transformation such as:

```text
"E" <> show n
```

is not acceptable merely because it produces a syntactically valid Tadka code.

---

# 14. Information-loss policy implementation

The implementation must not hide information loss inside ordinary translation code.

Every loss must appear explicitly in one of these forms:

```text
Lossless
LosslessAfterNormalization
ExplicitlyDiscarded
Unrepresentable
```

If a field is deliberately discarded, the mapping table must say why.

If it is essential but has no faithful Tadka representation, translation must fail rather than invent semantics.

---

# 15. JSON-Lines stream implementation

The stream layer must separate framing from semantics.

Conceptually:

```haskell
data StreamEvent
  = DiagnosticRecord RawDiagnosticLine
  | NonDiagnosticOutput ByteString
  | StreamFailure StreamError
```

Whether non-diagnostic stderr is represented as an event or forwarded directly is a product decision, but the distinction must be explicit.

The framing parser shall:

1. accept one logical JSON record per line according to the supported protocol;
2. reject malformed framing deterministically;
3. enforce record-size limits;
4. avoid unbounded buffering;
5. preserve record ordering;
6. avoid treating arbitrary text as a diagnostic merely because it contains JSON-like fragments.

---

# 16. Process integration implementation

The process layer shall make GHC invocation as transparent as practical.

Responsibilities:

- executable selection;
- argument forwarding;
- environment inheritance policy;
- structured diagnostic enablement;
- stderr stream capture;
- stdout preservation;
- exit status preservation;
- signal/termination handling;
- cleanup.

The process layer must not reinterpret diagnostic content.

## 16.1 Exit-status model

Document separately:

```text
GHC successful compilation
GHC compilation failure
GHC process failure
adapter failure
unsupported schema
malformed diagnostic record
```

These states must not collapse into one exit condition.

---

# 17. Security implementation

Diagnostic content is untrusted data.

The implementation shall treat as data:

- messages;
- source file names;
- URLs;
- help text;
- code identifiers;
- arbitrary JSON strings.

It shall not:

- execute strings as Haskell;
- interpret file paths as commands;
- execute shell fragments contained in diagnostics;
- follow URLs automatically;
- allocate unbounded structures from malicious input;
- recurse without a configured semantic bound.

Any HTML, terminal escape, hyperlink, or markup rendering is governed by the existing Tadka rendering security model, not by GHC input.

---

# 18. Resource bounds

The adapter must define bounds for at least:

```text
maximum diagnostic record size
maximum message size
maximum number of locations
maximum related-diagnostic depth
maximum total related-diagnostic count
maximum source size used for a translation
maximum buffered JSON-Lines frame
```

The values must be configurable only where there is a principled user-facing reason. They must have deterministic defaults.

A resource-limit failure is not equivalent to malformed schema input.

---

# 19. Testing architecture

Testing shall mirror the type pipeline.

```text
schema fixtures
      ↓
decode tests
      ↓
validation properties
      ↓
normalization properties
      ↓
translation properties
      ↓
golden Tadka observations
      ↓
actual GHC end-to-end tests
```

The test suite is a second implementation artifact, not an afterthought.

---

# 20. Unit-test requirements

Every public pure function requires direct unit tests for:

- ordinary valid input;
- minimum boundary;
- maximum boundary;
- missing optional value;
- malformed required value;
- contradictory fields;
- unknown enum/value where applicable;
- overflow boundary;
- Unicode source;
- multi-source input;
- nested/related diagnostics;
- code identity.

Every constructor of a production error algebra must have at least one direct test.

---

# 21. Property-test requirements

Property tests must validate implementation-independent laws.

Required laws include:

## 21.1 Determinism

```text
adapt(s, source, x) = adapt(s, source, x)
```

for identical inputs.

## 21.2 Decode stability

For supported canonical fixtures:

```text
encode(decode(x)) ≈ canonical(x)
```

where the schema permits deterministic re-encoding.

## 21.3 Normalization identity

Semantically equivalent schema encodings must normalize to semantically equivalent normalized diagnostics.

## 21.4 Span preservation

For every valid location:

```text
GHC location semantics
    =
Tadka source span semantics
```

under the contractually defined coordinate transformation.

## 21.5 Code identity

Distinct supported producer codes must not collide after translation unless explicitly declared equivalent.

## 21.6 Related/cause preservation

Normalization and translation must preserve relation structure.

## 21.7 No silent loss

If an input field is classified as preserved by the mapping matrix, its information must remain observable in the resulting Tadka structure or in an explicitly equivalent Tadka representation.

---

# 22. Independent semantic oracle

At least one test-side mapping implementation must be independent from production translation code.

It must derive expected semantic observations from the normalized representation without calling production helpers for the mapping under test.

For example:

```text
expectedSemanticObservation(normalized)
```

is compared against:

```text
observeTadka(translate(normalized))
```

This is required to avoid self-confirming tests where the oracle reproduces the same production bug.

---

# 23. Golden-test requirements

Golden tests shall cover:

- rendered diagnostic output;
- JSON output where Tadka's JSON renderer is part of the contract;
- primary/secondary labels;
- multi-file context;
- related diagnostics;
- causes;
- help;
- codes;
- Unicode and display-width edge cases;
- stale/unresolved source situations where applicable.

Golden files shall be deterministic and reviewable.

Generated golden data must be regenerated by an explicit tool, not by hidden test behavior.

---

# 24. Actual-GHC end-to-end testing

Each supported GHC release requires actual compiler execution.

Minimum matrix:

| GHC | schema | basic error | warning | code | source span | multi-source | related/cause |
|---|---|---|---|---|---|---|---|
| 9.10.3 | pinned | required | required | required | required | required if emitted | required if emitted |
| 9.12.4 | pinned | required | required | required | required | required if emitted | required if emitted |
| 9.14.1 | pinned | required | required | required | required | required if emitted | required if emitted |

If a semantic case cannot be naturally emitted by GHC, the fixture must identify that fact and the schema-level case shall still be covered using a validated fixture where appropriate.

No release may be declared compatible solely because the decoder accepts synthetic JSON.

---

# 25. Adversarial tests

Mandatory adversarial cases include:

```text
truncated JSON
invalid UTF-8 where the transport permits bytes
extremely long message
extremely long source path
extremely large line number
extremely large column number
zero-width span
reversed span
same start/end boundary
invalid start / valid end
valid start / invalid end
both endpoints invalid
unknown schema version
known schema with unsupported semantic variant
excessive nesting
excessive related-diagnostic count
excessive line length
Unicode combining characters
wide characters
CRLF / LF source variants as applicable
missing source
missing optional fields
unknown optional fields
unexpected stderr text
multiple diagnostics in one build
```

Each adversarial case must have a classified expected outcome.

---

# 26. Mutation testing

The semantic tests shall be exercised against deliberate mutations in at least these areas:

- line origin;
- column origin;
- inclusive/exclusive endpoint;
- start/end swapping;
- primary/secondary role inversion;
- code transformation;
- related/cause confusion;
- source identity normalization;
- silent dropping of a label;
- ignored schema version;
- ignored optional/required distinction.

The suite should fail under each mutation.

If it does not, the relevant proof obligation is insufficiently tested.

---

# 27. Implementation phases

The implementation proceeds in strict phases. A later phase may not silently compensate for an unfinished earlier phase.

## Phase 0 — Repository and contract lock

### Deliverables

- Tadka commit and package version pinned.
- Public API dependency list.
- Exact GHC schema artifacts identified.
- Compatibility matrix opened.
- Representability table opened.
- Source contract decision recorded.
- Code identity decision recorded.
- One worked example per supported GHC version.

### Exit gate

All Gates A-G are closed.

---

## Phase 1 — Package/build foundation

### Work

- Create the package structure.
- Establish Cabal configuration.
- Enable strict warning settings.
- Add test suites.
- Add schema fixture directories.
- Add reproducible generation/check tooling where required.

### Quality requirements

The package must build cleanly with the declared compiler matrix before semantic implementation begins.

### Exit gate

Empty semantic stubs compile with the intended public API boundaries and dependency direction.

---

## Phase 2 — Schema layer

### Work

- Add exact schema representations.
- Add schema-version identity.
- Add generated bindings if justified.
- Add representative schema fixtures.
- Add schema decoding tests.

### Exit gate

Every pinned schema fixture decodes into a typed value, and unsupported schema identity fails deterministically.

---

## Phase 3 — Decode and validation

### Work

Implement:

```haskell
decode
validate
```

with complete error algebras.

Add malformed and boundary cases before moving on.

### Exit gate

No normalization logic is required to inspect raw JSON or unvalidated schema values.

---

## Phase 4 — Canonical normalization

### Work

Implement:

```haskell
normalize
```

Convert all supported schema variants into one canonical semantic representation.

### Required review

For each field, the implementation must point to the representability/mapping table.

### Exit gate

Equivalent supported schema encodings produce equivalent normalized semantics.

---

## Phase 5 — Source and span semantics

### Work

Implement:

- source environment;
- source lookup;
- coordinate validation;
- coordinate conversion;
- span resolution;
- source identity handling.

### Required regression suite

Include the historical endpoint and overflow failures discovered in the Tadka repository.

### Exit gate

All span laws pass independently of message/severity/code translation.

---

## Phase 6 — Diagnostic translation

### Work

Implement:

```haskell
translate
adapt
```

including:

- severity;
- reason;
- message;
- code;
- primary and secondary locations;
- help;
- related diagnostics;
- causes;
- explicit unsupported cases.

### Exit gate

Independent semantic oracle agrees with production translation on the full generated normalized domain covered by the test generators.

---

## Phase 7 — Stream integration

### Work

Implement JSON-Lines framing and bounded stream processing.

The stream implementation shall call the pure adapter, not reproduce its semantics.

### Exit gate

Large and malformed streams are handled deterministically without unbounded buffering.

---

## Phase 8 — Process integration

### Work

Implement actual GHC invocation and transparent argument forwarding.

Define stdout/stderr/exit-status behavior.

### Exit gate

A supported GHC invocation produces Tadka diagnostics through the complete stack without requiring knowledge of internal schema or Tadka configuration.

---

## Phase 9 — Renderer and UX certification

### Work

Verify that translated diagnostics behave as ordinary Tadka diagnostics through existing rendering/configuration mechanisms.

No Tadka-GHC-specific rendering path should be introduced unless required by a capability gap established in the mapping matrix.

### Exit gate

Golden outputs are stable and meet the consumer-experience requirement.

---

## Phase 10 — Compatibility certification

### Work

Run the complete compiler/schema matrix:

```text
GHC version
× schema version
× semantic fixture
× renderer
× source condition
× process condition
```

### Exit gate

Every compatibility cell is green and reproducible.

---

## Phase 11 — Release certification

### Work

- full test suite;
- property suite;
- mutation tests;
- end-to-end GHC suite;
- benchmark suite;
- documentation;
- changelog;
- compatibility report;
- reproducibility verification.

### Exit gate

Definition of Done is satisfied with no waived P0 item.

---

# 28. Work breakdown and ownership

Ownership should be assigned by responsibility rather than by arbitrary file count.

Recommended roles:

```text
Architecture owner
    contract, invariants, public API, review gates

Schema engineer
    schema artifacts, decoding, compatibility fixtures

Semantic engineer
    validation, normalization, mapping laws

Tadka integration engineer
    source/span/Diagnostic construction

Integration engineer
    JSON-Lines/process/exit-status behavior

Verification engineer
    property, golden, mutation, e2e, compatibility certification
```

One person may hold several roles, but no semantic module should be approved solely by its implementer.

---

# 29. Estimated engineering effort

The following is planning guidance, not a promise of elapsed time.

| Area | Relative effort | Complexity |
|---|---:|---|
| schema acquisition/pinning | 1 | medium |
| schema bindings/decoding | 2 | medium |
| validation/normalization | 3 | high |
| source/span semantics | 3 | high |
| Tadka translation | 2 | high |
| stream/process integration | 2 | medium |
| tests/fixtures/oracle | 4 | very high |
| compatibility certification | 3 | high |
| release hardening | 2 | medium |

Testing and fixture work is intentionally large. For a compiler adapter, the test artifact is part of the implementation rather than a post-implementation accessory.

---

# 30. Code-quality rules

## Mandatory

- `-Wall` and project-equivalent strict warning policy.
- No incomplete pattern matches in semantic modules.
- No `undefined`.
- No `error` in production semantic code.
- No `fromJust`.
- No `head`/`tail`/`last`/`init`/`!!` where correctness depends on non-emptiness.
- No partial numeric conversion without proven bounds.
- No hidden I/O in pure semantic modules.
- No broad `Text`-typed semantic fields when a closed type is justified.
- No duplicated semantic mapping logic.
- No hidden fallback from unsupported schema to an earlier schema.

## Preferred

- small total functions;
- explicit domain types;
- exhaustive case analysis;
- local invariants visible in function signatures;
- functions whose implementation mirrors their mathematical specification;
- data types that eliminate invalid states rather than merely checking them later.

---

# 31. Review checklist for each semantic module

Before merging a module, reviewers must answer:

1. What domain does the module accept?
2. What invariant does its output establish?
3. Where is that invariant represented—in the type, in a proof obligation, or both?
4. Can the function fail for a valid input? If so, why?
5. Is every failure constructor reachable and tested?
6. Does the implementation follow the normative semantic law directly?
7. Is any semantic meaning inferred from incidental representation details?
8. Does the module depend on a later phase's assumptions?
9. Is the module independently property-testable?
10. Is there a simpler total formulation?

A reviewer should be able to answer these without mentally executing large sections of code.

---

# 32. Definition of Done

Tadka-GHC is implementation-complete only when all of the following are true.

## Contract

- [ ] Vision v9.0 remains satisfied.
- [ ] Gates A-G are closed.
- [ ] exact schema artifacts are pinned.
- [ ] compatibility matrix is complete.

## Architecture

- [ ] dependency direction is correct.
- [ ] pure core is isolated.
- [ ] process integration is isolated.
- [ ] existing Tadka interop semantics are not duplicated unnecessarily.

## Types

- [ ] raw/parsed/validated/normalized states are distinct.
- [ ] normalized IR is Tadka-independent.
- [ ] schema-specific closed domains are exhaustive.
- [ ] production semantic code is total.

## Semantics

- [ ] severity is preserved.
- [ ] reason is preserved.
- [ ] message is preserved.
- [ ] code identity is preserved.
- [ ] location roles are preserved.
- [ ] source identity is preserved.
- [ ] related diagnostics are preserved.
- [ ] causes are preserved.
- [ ] help is preserved where representable.
- [ ] information loss is explicit.

## Verification

- [ ] unit tests complete.
- [ ] property tests complete.
- [ ] independent semantic oracle complete.
- [ ] golden tests complete.
- [ ] adversarial tests complete.
- [ ] mutation tests complete.
- [ ] actual-GHC tests complete.
- [ ] all supported compiler/schema cells pass.

## Engineering

- [ ] reproducible Cabal build.
- [ ] no undocumented generated artifacts.
- [ ] no unreviewed partial functions in semantic code.
- [ ] bounded resource usage.
- [ ] security review complete.
- [ ] documentation complete.
- [ ] changelog complete.
- [ ] release compatibility report complete.

---

# 33. What must not happen

The following are explicitly prohibited shortcuts.

## 33.1 Do not start from a giant hand-written JSON AST

The wire model must come from the exact schema artifacts.

## 33.2 Do not make the normalized IR a disguised Tadka object

Normalization is where GHC semantics become canonical. Translation is where they become Tadka.

## 33.3 Do not make Tadka-GHC responsible for Tadka rendering

Use Tadka's existing renderers.

## 33.4 Do not silently downgrade unsupported diagnostics

A translation error is preferable to a misleading diagnostic.

## 33.5 Do not add generic abstractions before there are two proven cases

Solve the declared GHC matrix first.

## 33.6 Do not infer schema compatibility from version numbers

Compiler version and schema version are independent contract axes.

## 33.7 Do not use synthetic fixtures as the only compatibility evidence

Actual GHC execution is mandatory.

---

# 34. Final implementation shape

The intended end state is:

```text
                         ┌───────────────────────┐
                         │       GHC process      │
                         └──────────┬────────────┘
                                    │
                              structured stderr
                                    │
                                    ▼
                         ┌───────────────────────┐
                         │ Tadka.GHC.Process    │
                         └──────────┬────────────┘
                                    │
                                    ▼
                         ┌───────────────────────┐
                         │ Tadka.GHC.Stream     │
                         └──────────┬────────────┘
                                    │ raw record
                                    ▼
                         ┌───────────────────────┐
                         │ Tadka.GHC.Decode      │
                         └──────────┬────────────┘
                                    │ parsed
                                    ▼
                         ┌───────────────────────┐
                         │ Tadka.GHC.Validate    │
                         └──────────┬────────────┘
                                    │ validated
                                    ▼
                         ┌───────────────────────┐
                         │ Tadka.GHC.Normalize   │
                         └──────────┬────────────┘
                                    │ normalized GHC semantics
                                    ▼
                         ┌───────────────────────┐
                         │ Tadka.GHC.Translate   │
                         └──────────┬────────────┘
                                    │
                                    ▼
                         ┌───────────────────────┐
                         │       Tadka           │
                         │ Diagnostic / Context  │
                         │ Span / Related / ...  │
                         └──────────┬────────────┘
                                    │
                                    ▼
                         existing Tadka renderers
```

The essential design property is that the pipeline remains visible in the code.

A senior Haskell engineer should be able to inspect the module graph and determine the semantic story without reconstructing it from framework machinery.

---

# 35. Immediate next engineering artifact

Before implementation begins, the team shall create one more file:

```text
TADKA-GHC-COMPATIBILITY-MATRIX.md
```

It shall contain:

```text
1. GHC 9.10.3 exact schema
2. GHC 9.12.4 exact schema
3. GHC 9.14.1 exact schema
4. real emitted examples
5. normalized representation for each example
6. Tadka translation result
7. source/span calculations
8. code mapping
9. loss classification
10. expected rendered observations
```

That artifact is the final bridge between this implementation specification and production code.

Until that matrix exists and is reviewed, the project is **not implementation-frozen**.

---

# Appendix A — Relationship to Vision v9.0

This implementation specification does not replace the Vision.

The Vision remains authoritative for:

- product goals;
- semantic laws;
- compatibility meaning;
- information-loss policy;
- security principles;
- formal proof obligations.

This document adds:

- concrete implementation boundaries;
- type-state plan;
- package/module responsibilities;
- implementation phases;
- testing execution;
- review gates;
- release certification.

Where an apparent conflict exists, the Vision wins and this document must be revised.

---

# Appendix B — Gold-standard engineering principle

The implementation shall read like a proof of the specification.

In particular:

```text
validation establishes invariant V
normalization establishes canonical form N
translation maps N to T under the faithfulness law
Tadka then owns presentation and rendering
```

The code should make that chain evident.

The goal is not merely:

```text
"a program that passes today's tests"
```

but:

```text
"a small total program whose types, structure, and tests make the
correctness argument difficult to violate"
```

That is the engineering standard for Tadka-GHC.
