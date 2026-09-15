# Tadka-GHC

## Vision, Architecture and Gold-Standard Engineering Specification

**Status:** Normative architecture, semantic specification, and formal
engineering specification\
**Version:** 9.0\
**Parent project:** Tadka\
**Target integration:** GHC diagnostics → Tadka\
**Engineering authority:** The Haskell Engineering Standard

------------------------------------------------------------------------

# 1. Non-Negotiable Product Priorities

These requirements are **P0 requirements**. They outrank implementation
convenience, minimum line count, premature generalization, and
performance optimizations that do not preserve them. A design that
violates any one of them is not an acceptable Tadka-GHC design.

## 1.1 Seamless compatibility with GHC

> **Tadka-GHC must work seamlessly with GHC.**

GHC remains the semantic authority. Tadka-GHC must consume GHC's
supported structured diagnostic interface faithfully across every GHC
version explicitly supported by the release. Compatibility means more
than compiling against a GHC version: actual diagnostics produced by
that compiler must decode, normalize, convert, and render correctly.

There must be no silent loss, corruption, reinterpretation, or invention
of diagnostic information that Tadka can faithfully represent. GHC
version changes must be detected and handled deliberately rather than
accidentally.

## 1.2 Seamless compatibility with Tadka

> **Tadka-GHC must work seamlessly with Tadka.**

Tadka is the diagnostic authority and presentation layer. Tadka-GHC must
use Tadka's existing public concepts and semantics rather than creating
a competing diagnostic model, renderer, source model, span model,
severity model, or configuration system.

For every GHC diagnostic property that has a faithful representation in
Tadka, Tadka-GHC must preserve it. The result must behave like a native
Tadka diagnostic: it must pass through the same rendering,
configuration, source/context, related-diagnostic, code, help, and
degradation semantics that other Tadka diagnostics use.

Tadka-GHC must not require changes to Tadka merely to work around an
adapter design flaw. If Tadka genuinely lacks a capability required for
faithful GHC representation, that becomes an explicit architectural
decision: first determine whether the capability is genuinely generic
and therefore belongs in Tadka; otherwise keep it in Tadka-GHC.

## 1.3 Apple-like consumer experience

> **The product experience must have the seamlessness of Apple consumer
> products: the right thing should happen automatically, the common path
> should require almost no thought, and the system should remain
> predictable without exposing unnecessary complexity.**

This is a **consumer-experience standard**, not a statement about Apple
developer tooling. The reference point is the experience of using a
well-designed Apple consumer product: installation and setup are
straightforward, defaults are sensible, the system guides the user
correctly, and ordinary use does not require the user to understand the
machinery underneath.

The common path must feel obvious: install the integration, build the
project, and receive excellent Tadka diagnostics. A developer should not
need to understand GHC's JSON schema, source-span representation,
decoder internals, or Tadka's internal architecture merely to use the
integration.

The integration must prefer:

-   zero or near-zero configuration for the common case;
-   one obvious installation path;
-   sensible defaults;
-   automatic handling of ordinary GHC diagnostics;
-   deterministic behaviour;
-   useful failures when something genuinely cannot be supported;
-   no duplicated configuration between GHC and Tadka unless
    unavoidable;
-   documentation that makes the first successful result easy to
    achieve.

**Seamless does not mean magical or opaque.** When a boundary genuinely
cannot be crossed, the system must report exactly what is unsupported
and why, rather than silently degrading or producing a misleading
diagnostic.

## 1.4 The three-way compatibility contract

These are one product requirement, not three independent goals:

``` text
GHC
 │
 │ faithful structured diagnostics
 ▼
Tadka-GHC
 │
 │ faithful translation
 ▼
Tadka
 │
 │ native Tadka semantics and rendering
 ▼
Developer
```

A feature is not complete if it works technically but is awkward to
configure; nor if it looks beautiful but loses GHC information; nor if
it preserves GHC information but bypasses Tadka semantics.

## 1.5 What "100% compatibility" means

For a declared compatibility matrix, **100% compatibility is the
acceptance target**:

1.  Every supported GHC version must have its supported structured
    diagnostic cases covered by the compatibility matrix and must
    consume every case in that declared semantic subset correctly.
2.  Every GHC diagnostic property that Tadka can represent must survive
    translation without semantic loss.
3.  Every translated diagnostic must behave as a normal Tadka diagnostic
    through Tadka's existing APIs and renderers.
4.  Unsupported or genuinely unrepresentable information must be handled
    explicitly and deterministically; it must never be silently guessed.
5.  Every supported combination must be verified by automated tests,
    including actual GHC end-to-end tests.
6.  Compatibility must be re-established for every Tadka or GHC release
    that can affect the contract.

The phrase **100% compatibility** therefore means **complete, tested
semantic compatibility for every diagnostic semantic case within the
explicitly declared GHC/Tadka/schema support matrix**, subject only to
explicitly declared representability boundaries. It does not mean
compatibility with arbitrary future GHC output or with diagnostic
information that Tadka cannot faithfully represent.

### Formal semantic compatibility contract

The central correctness relation shall be defined before implementation.
This subsection previews that relation informally; the binding, formal
definition is given below in "Formal semantic specification," §4
(Translation law).

``` text
n = a normalized GHC diagnostic, n ∈ N
t = the Tadka diagnostic produced from n

FaithfulSemantics(n,t)
```

`FaithfulSemantics` is an implementation-independent semantic relation.
It is defined by the formal semantic law below and does not depend on
whether `translate` happened to return `Right(t)`.

For every contract observation `q` that is representable for `n`:

``` text
Representable(⟦n⟧N,q)
    ⇒
obsG(⟦n⟧N,q) = obsT(⟦t⟧T,q)
```

The formal semantic specification is authoritative. The implementation
function is correct only if:

``` text
translate(n) = Right(t)
    ⇒
FaithfulSemantics(n,t)
```

The translation shall therefore be specified as a total, deterministic
function over the declared normalized GHC domain:

``` text
translate : N → Either TranslationError T
```

with these obligations:

-   every representable GHC semantic property has a specified
    destination in Tadka;
-   every mapping has explicitly defined semantics;
-   no GHC property is silently assigned a different meaning;
-   no information is fabricated;
-   information without a faithful Tadka representation follows the
    explicit information-loss policy;
-   the mapping is deterministic;
-   the preservation relation is exercised by properties, golden
    fixtures and actual-GHC integration tests.

The formal specification, not the implementation, is the authority.
Tests provide evidence that the implementation satisfies the
specification; they do not replace the specification or a correctness
argument.

### Formal semantic specification

This section is normative. The symbols and laws defined here are the
mathematical foundation for the correctness claims made elsewhere in
this document.

#### 1. Semantic domains

Let:

``` text
R       = raw GHC diagnostic input
P       = parsed GHC wire representation
V       = validated GHC diagnostic
N       = normalized GHC diagnostic
D_G     = GHC semantic diagnostic domain
D_T     = Tadka semantic diagnostic domain
C       = Tadka-observable semantic domain
T       = concrete Tadka Diagnostic
Q       = semantic observations relevant to Tadka
TranslationError = classified translation errors
```

The concrete stages are therefore:

``` text
Raw → Parsed → Validated → Normalized → Tadka
 R       P          V           N          T
```

A value may cross a stage boundary only through the function specified
for that boundary. No later stage may consume an earlier, weaker
representation merely because the underlying runtime representation
happens to be available.

The semantic domains and representations are deliberately distinct:

``` text
wire representation
        ↓
validated representation
        ↓
normalized representation
        ↓
semantic interpretation
```

The normalized representation is not itself the semantic domain. It is a
canonical representation whose interpretation is defined below.

#### 2. Semantic interpretation

Use separate interpretation functions for the distinct representation
domains:

``` text
⟦·⟧V : V → D_G
⟦·⟧N : N → D_G
⟦·⟧T : T → D_T
```

Validation establishes invariants without changing the represented GHC
meaning. Normalization changes representation without changing the
represented GHC meaning.

The normalization law is therefore:

``` text
∀v ∈ V:
    ⟦normalize(v)⟧N = ⟦v⟧V
```

The adapter does not attempt to reproduce all of `D_G` inside Tadka.

Instead, define a **partial semantic abstraction**:

``` text
abstract : D_G ⇀ C
```

and a canonical embedding of the Tadka-observable domain into Tadka
semantics:

``` text
embed : C → D_T
```

`abstract(d)` is defined exactly when the Tadka semantic domain can
faithfully represent every semantic observation of `d` that is within
the declared Tadka-GHC contract.

The pair:

``` text
D_G  ⇀  C  →  D_T
     abstract   embed
```

is the semantic bridge. `C` is not a second diagnostic framework; it is
the subdomain of Tadka semantics that Tadka-GHC is required to preserve.

`abstract` is a semantic abstraction, not a syntactic field copier. A
GHC field is not representable merely because it can be stored in
`Text`, `Doc`, metadata, or another convenient container.

The term "projection" may be used informally, but the normative
mathematical name is **partial semantic abstraction** because `abstract`
is not assumed to be a Cartesian projection.

#### 3. Semantic observations

A semantic observation is a query about a diagnostic property relevant
to the Tadka-GHC contract.

Define partial observation functions:

``` text
obsG : D_G × Q ⇀ Value
obsT : D_T × Q ⇀ Value
```

A property `q ∈ Q` is representable for a GHC semantic value `d` when:

``` text
obsG(d,q) is defined
```

and the Tadka semantic domain can faithfully expose the same
observation:

``` text
obsT(embed(abstract(d)),q) is defined
```

The representability relation is therefore:

``` text
Representable(d,q)
    ⇔
    abstract(d) is defined
    ∧
    obsG(d,q) is defined
    ∧
    obsT(embed(abstract(d)),q) is defined
```

The project shall maintain a finite, explicit contract vocabulary for
`Q` covering every semantic property that Tadka-GHC promises to
preserve. The vocabulary is not an invitation to enumerate arbitrary
internal GHC state.

#### 4. Translation law

Translation is:

``` text
translate : N → Either TranslationError T
```

where `TranslationError` is a classified, explicit error algebra.

For every successful translation:

``` text
translate(n) = Right(t)
    ⇒
embed(abstract(⟦n⟧N)) = ⟦t⟧T
```

This is the primary semantic faithfulness law.

Define semantic faithfulness independently of the implementation
function:

``` text
FaithfulSemantics(n,t)
    ⇔
    embed(abstract(⟦n⟧N)) = ⟦t⟧T
```

Then the implementation obligation is:

``` text
translate(n) = Right(t)
    ⇒
FaithfulSemantics(n,t)
```

This avoids defining correctness in terms of the success of the function
whose correctness is being verified.

`FaithfulSemantics` is never a visual comparison and never a comparison
of raw JSON fields.

#### 5. Observation-preservation theorem

For every successful translation:

``` text
translate(n) = Right(t)
```

and every contract observation `q ∈ Q` for which the GHC semantic value
is representable:

``` text
Representable(⟦n⟧N,q)
```

the observation is preserved:

``` text
obsG(⟦n⟧N,q)
    =
obsT(⟦t⟧T,q)
```

This is the precise form of the information-preservation requirement.

It replaces the invalid formulation in which an observation `q` was
treated as an element of the semantic value `abstract(⟦n⟧N)`. A semantic
value is not a set of properties; observations are separate queries over
semantic values.

#### 6. Semantic composition law

The complete pure semantic pipeline is:

``` text
R → P → V → N → Either TranslationError T
```

with:

``` text
decode     : R → Either DecodeError P
validate   : P → Either ValidationError V
normalize  : V → N
translate  : N → Either TranslationError T
```

The following composition law is required:

``` text
decode(r)    = Right(p)
validate(p)  = Right(v)
normalize(v) = n
translate(n) = Right(t)

        ⇒

embed(abstract(⟦n⟧N)) = ⟦t⟧T
```

Because `normalize` is total over `V`, a failure of normalization
represents an internal invariant violation rather than an ordinary
representability failure. The implementation must not silently convert
such a defect into an "unsupported diagnostic" result.

#### 7. Determinism

All pure semantic stages are deterministic: for equal explicit inputs
and equal declared configuration, repeated evaluation produces equal
results.

Determinism does not mean success. A total function such as:

``` text
translate : N → Either TranslationError T
```

is deterministic and total even though its result may be `Left`.

------------------------------------------------------------------------

### Semantic capability monotonicity

The representability abstraction is monotone only relative to an
explicitly defined capability order.

Let:

``` text
K₁ ≼cap K₂
```

mean that capability set `K₂` contains every semantic capability in
`K₁`.

Then adding capabilities must satisfy:

``` text
K₁ ≼cap K₂
∧
d ∈ dom(abstractK₁)

⇒

d ∈ dom(abstractK₂)
```

and, for every observation already representable under `K₁`, the meaning
must remain unchanged:

``` text
obsT(embed(abstractK₁(d)),q)
    =
obsT(embed(abstractK₂(d)),q)
```

for every `q` representable under `K₁`.

This is the precise meaning of "adding Tadka capabilities must not
change the meaning of already-supported diagnostics." No undefined order
relation over `D_G` or `C` is assumed.

------------------------------------------------------------------------

### Supported semantic domain

Define:

``` text
N_supported ⊆ N
```

as the explicitly declared normalized GHC diagnostic domain supported by
a particular Tadka-GHC release and compatibility cell.

The 100% compatibility claim is quantified over `N_supported`, not over
every possible future or private GHC diagnostic.

A supported input therefore has exactly one of:

``` text
Right(t)
```

for a faithful translation, or:

``` text
Left(e)
```

for an explicit, classified failure allowed by the contract.

There is no permitted third state in which supported semantic
information is silently dropped, guessed, or reinterpreted.

#### 7. Determinism

All pure semantic stages are deterministic: for any two calls with
syntactically identical arguments and identical declared configuration,
the results are identical, regardless of when, where, or how many times
the call is made:

``` text
∀ r, r' with r ≡ r':  decode(r)     = decode(r')
∀ p, p' with p ≡ p':  validate(p)   = validate(p')
∀ v, v' with v ≡ v':  normalize(v)  = normalize(v')
∀ n, n' with n ≡ n':  translate(n)  = translate(n')
```

where `≡` denotes syntactic (structural) equality of the argument, not
mere reference identity.

No semantic result may depend on hash-table iteration order, locale,
terminal state, wall-clock time, ambient filesystem state, or other
hidden inputs.

If an operation genuinely depends on external state, that state must
appear explicitly in its input domain.

#### 8. Validation as a proof boundary

Validation establishes every invariant required by normalization.

The preferred invariant is:

``` text
v ∈ V
    ⇒
normalize(v) cannot fail for a semantic reason
```

Consequently, an error discovered after validation indicates an
implementation defect or a violated internal invariant, not an ordinary
malformed-input case.

This distinction must be reflected in the Haskell types rather than
hidden in exceptions.

#### 9. Semantic equivalence versus representation equality

The following are deliberately different:

``` text
representation equality
semantic equality
rendered-text equality
```

Two GHC schema representations may differ while denoting the same `D_G`.
Two Tadka values may render differently under configuration while
representing the same semantic diagnostic. Conversely, identical
rendered text does not prove semantic equivalence.

Correctness claims therefore use semantic interpretation, never rendered
text, as their primary relation.

#### 10. Formal correctness target

The implementation is correct when:

``` text
∀n ∈ N_supported:

    translate(n) = Right(t)
        ⇒ FaithfulSemantics(n,t)

    translate(n) = Left(e)
        ⇒ e is an explicitly permitted, classified failure
```

The allowed failure classes are defined by the error algebra and include
compatibility, representability, resource, stream, process, and internal
invariant failures.

There must be no third category of silent semantic degradation, silent
reinterpretation, or silent omission of representable information.

### Required type-state architecture

The implementation shall expose or internally enforce distinct type
states corresponding to the semantic stages:

``` haskell
newtype RawDiagnostic        = ...
newtype ParsedDiagnostic     = ...
newtype ValidatedDiagnostic  = ...
newtype NormalizedDiagnostic = ...
```

The exact representation is implementation-defined, but the typestate
invariants are normative:

``` text
Raw
  < Parsed
  < Validated
  < Normalized
```

where `<` means "strictly stronger established invariants", not an
ordering on runtime values.

No renderer, Tadka conversion, or semantic operation may accept a weaker
state merely to avoid an explicit validation boundary.

------------------------------------------------------------------------

# 2. Executive Vision

**Tadka-GHC should make Tadka the natural presentation layer for GHC
diagnostics without making Tadka itself a GHC-specific library.**

The desired developer experience is:

``` text
              Haskell project
                    │
                    ▼
                   GHC
                    │
          structured diagnostics
                    │
                    ▼
              Tadka-GHC
                    │
          faithful translation
                    │
                    ▼
                 Tadka
                    │
          ┌─────────┼─────────┐
          ▼         ▼         ▼
      graphical  narratable  JSON
```

The important division of responsibility is:

> **GHC understands the program and produces the diagnostic.\
> Tadka-GHC understands GHC's diagnostic representation and translates
> it.\
> Tadka understands how structured diagnostics are represented and
> rendered.**

Tadka-GHC must never pretend to be the compiler, type checker, parser,
semantic analyser, or explanation engine.

Its job is to make the information GHC already possesses available
through Tadka's existing diagnostic system.

------------------------------------------------------------------------

# 3. Governing Engineering Standard

The Haskell Engineering Standard is binding for this project.

Its precedence is:

1.  Correctness / totality
2.  Safety of representation
3.  Architectural clarity
4.  Performance
5.  Brevity

Therefore:

> **Tadka-GHC must never trade correctness, representation safety, or
> architectural clarity for fewer lines of code.**

The standard requires total functions, explicit failures,
unrepresentable illegal states where practical, pure core logic,
deliberate dependency boundaries, explicit module contracts,
deterministic builds, rigorous testing, and mechanical enforcement of
architectural claims.

These are not aspirations. They are acceptance criteria.

The Engineering Standard governs **how** the P0 product requirements are
achieved. It does not weaken them. If a technically elegant design fails
GHC compatibility, Tadka compatibility, or seamless developer
experience, it is rejected regardless of its simplicity.

The product priorities are therefore:

1.  **GHC compatibility --- P0**
2.  **Tadka compatibility --- P0**
3.  **Apple-like consumer experience --- P0**
4.  Correctness and totality --- mandatory engineering means for
    achieving 1--3
5.  Safety of representation
6.  Architectural clarity
7.  Performance
8.  Brevity

Correctness is not being deprioritized. It is the Engineering Standard's
mandatory method for delivering the first three priorities without
compromise.

The standard explicitly requires compiler enforcement such as
`-Wall -Wcompat -Werror` and incomplete-pattern checks, property tests
for stated invariants, benchmark evidence for performance-sensitive
paths, and recorded ADRs for deliberate deviations.

## 3.3 Algorithmic and mathematical implementation standard --- P0 engineering requirement

> **Tadka-GHC domain code shall be algorithmic, mathematically correct,
> and written so that the implementation reads as closely as practical
> to a mathematical proof.**

This is a first-class engineering requirement, not a stylistic
preference. The objective is not clever code or mathematical decoration.
The objective is code whose structure makes its correctness, invariants,
transformations, and failure cases evident.

For every non-trivial algorithm or domain transformation:

1.  **The mathematical object must be explicit.** The types and
    definitions shall make clear what is being represented.
2.  **Invariants shall be explicit.** Preconditions, postconditions,
    conservation properties, ordering properties, bounds, and other
    relevant invariants shall be identified and, where practical,
    encoded in types.
3.  **Transformations shall be precise.** A GHC representation
    transformed into an intermediate representation and then into Tadka
    must have explicitly defined semantics.
4.  **Functions shall be total over their declared domains.** Every
    failure mode that can genuinely occur shall be represented
    explicitly rather than hidden behind partial functions, exceptions,
    or undefined behaviour.
5.  **The implementation shall follow the algorithm, not obscure it.**
    Control flow, recursion, folds, pattern matches, and data structures
    should correspond directly to the stated mathematical operation.
6.  **Properties shall be tested as properties.** Where correctness can
    be stated universally, property-based tests shall establish those
    invariants rather than relying solely on examples.
7.  **Optimisation shall preserve the proof.** An optimised
    implementation is acceptable only when it has the same formally
    defined semantics as the straightforward algorithm and is justified
    by measurement where performance matters.
8.  **No heuristic substitution for correctness.** A convenient
    approximation, silent fallback, guessed span, invented diagnostic
    meaning, or lossy conversion is unacceptable merely because it
    produces plausible output.

### Code-reading criterion

A reviewer should be able to read the core algorithms and answer, from
the code and its local specification:

-   What is the input domain?
-   What is the output domain?
-   What invariant is established?
-   What transformation is performed?
-   Why does the transformation preserve the required semantics?
-   What happens for every invalid or unsupported case?

The desired standard is:

> **Core Tadka-GHC code should read like an executable mathematical
> proof written in Haskell.**

This requirement applies especially to parsing and validation, schema
interpretation, source and span conversion, diagnostic normalization,
severity and code mapping, preservation of related diagnostics,
ordering, aggregation, bounds checking, and any other logic that affects
semantic correctness.

It does not require incidental infrastructure such as Cabal metadata,
process plumbing, or ordinary serialization mechanics to be written in
theorem-like form. It requires the **domain logic and algorithms** to
meet the mathematical standard.

Code that passes tests but relies on unclear invariants, accidental
behaviour, partiality, ad-hoc transformations, or unverifiable
assumptions is not considered gold-standard code.

### Proof hierarchy

The project shall use the following hierarchy for correctness-critical
logic:

``` text
formal specification
        ↓
mathematical invariant / semantic law
        ↓
correctness argument or proof
        ↓
type-level enforcement where practical
        ↓
property-based testing
        ↓
golden / regression testing
        ↓
end-to-end testing
```

A property test is **evidence**, not a mathematical proof. It
demonstrates the invariant over generated examples and protects the
implementation against regression; it does not establish a universal
theorem by itself.

Where a correctness argument is tractable, the design documentation
shall state it. A coordinate conversion, for example, shall specify the
mathematical relationship between source coordinates and offsets and
then state the invariant that the implementation preserves.

The objective is not to burden trivial code with formalism. The
objective is that every non-trivial semantic algorithm has a correctness
story that can be inspected independently of the test suite.

------------------------------------------------------------------------

## 3.1 Mandatory development toolchain: Cabal

> **Development, building, testing, packaging, and release verification
> shall use Cabal.**

Cabal is the normative build and development system for Tadka-GHC. The
documented development workflow, CI, compatibility verification, package
construction, and release process shall all be reproducible through
Cabal.

Other tools may be used for genuinely ancillary tasks, but Tadka-GHC
must not require Stack, Nix, or another build system for normal
development or for establishing release correctness. A contributor
following the documented workflow must be able to build and verify the
project using Cabal.

The Cabal configuration shall make the supported GHC compatibility
matrix explicit.

## 3.2 Mandatory GHC compatibility matrix

Tadka-GHC deliberately targets the **GHC 9.10+ structured-diagnostic
interface generation**, because the project specifically depends on
GHC's `-fdiagnostics-as-json` structured diagnostic interface. This is a
statement about which GHC diagnostic interface generation the
architecture is built for, not a claim of compatibility with every GHC
9.10-or-later release: per §1.5, 100% compatibility is bounded to the
explicitly declared, closed compatibility matrix below, and a GHC 9.10+
release is not supported until it is added to that matrix through
deliberate verification (see the end of this section). Legacy diagnostic
transports such as `-ddump-json` are outside the product contract and
shall not be supported by the initial Tadka-GHC architecture.

The initial normative compatibility matrix is:

  GHC version   Requirement   Diagnostic interface
  ------------- ------------- -------------------------
  9.10.3        Mandatory     `-fdiagnostics-as-json`
  9.12.4        Mandatory     `-fdiagnostics-as-json`
  9.14.1        Mandatory     `-fdiagnostics-as-json`

Therefore:

> **Tadka-GHC shall support the declared, closed GHC compatibility
> matrix below, drawn from the GHC 9.10+ diagnostic interface
> generation, with every version in the declared matrix explicitly
> tested through `-fdiagnostics-as-json`.**

GHC 9.6 and 9.8 are explicitly outside the Tadka-GHC compatibility
contract. The existing `tadka:interop-ghc` span functionality is
unaffected by this decision.

Support means more than successful compilation. Each supported compiler
must pass the relevant complete test suite, including
structured-diagnostic decoding, semantic normalization, conversion into
Tadka, rendering, malformed-input handling, and actual GHC end-to-end
integration tests.

A future GHC version is not supported merely because the code happens to
compile against it. It becomes supported only after deliberate
compatibility verification and inclusion in the declared matrix.

# 4. The Existing Tadka Foundation

The Tadka repository is the implementation authority for the Tadka side
of this specification. Version 9.0 therefore stops treating the Tadka
API as a design assumption and records the concrete repository contract.

The baseline audited for this specification is:

``` text
Tadka package: 2.0.0.0
Repository:    Bombay-Boyz/tadka
Baseline:      bc750f8694df8424ed0a8c985bd7fa1754dc11ad
GHCs tested by Tadka itself:
               9.6.7, 9.8.4, 9.10.3, 9.12.4, 9.14.1
```

The supported public vocabulary includes:

- `Diagnostic`
- `SomeDiagnostic`
- `NamedSource`
- `Span`
- `ResolvedSpan`
- `LineCol`
- `Context`
- `Labeled`
- `LabelKind`
- `LabelState`
- `Severity`
- `DiagnosticCode`
- `DiagnosticId`
- `Url`
- related diagnostics
- diagnostic causes
- graphical, narratable and JSON renderers
- configuration

The public `Tadka` module is the sole supported entry point. Internal
modules remain implementation detail even though the package exposes
them for existing derivation/manual-instance discipline. Tadka-GHC must
target the supported public API unless an explicit, reviewed exception
is recorded.

## 4.1 Existing GHC span interop is retained

Tadka already contains the one-directional adapter:

``` text
tadka:interop-ghc
        │
        ▼
GHC SrcSpan → Tadka Span
```

Its concrete public conversion is:

```haskell
spanFromSrcSpan
    :: Text
    -> SrcSpan
    -> Either SrcSpanConvError Span
```

This is a **span adapter**, not a structured-diagnostic adapter. Tadka-GHC
must not replace or broaden this API merely to obtain access to GHC
structured diagnostics.

The existing implementation already establishes several important
semantic precedents:

1. unhelpful source spans are an explicit conversion failure;
2. start and end coordinates are validated independently;
3. a negative span is rejected explicitly;
4. GHC's one-based line/column coordinates are converted to Tadka's
   character-offset span representation using source text;
5. no partial list indexing is used by the conversion path.

The new structured-diagnostic adapter must preserve these principles, but
it must not assume that sharing implementation code is automatically the
right form of reuse. The contract to share is semantic; code sharing is
optional and must not distort either abstraction.

## 4.2 Existing Tadka type invariants are authoritative

The following repository invariants are directly relevant to Tadka-GHC:

```haskell
data Resolution = Unresolved | Resolved

data SpanF r where
  RawSpan      :: Offset -> Length -> SpanF 'Unresolved
  ResolvedSpan :: Offset -> Length -> LineCol -> LineCol -> SpanF 'Resolved

type Span         = SpanF 'Unresolved
type ResolvedSpan = SpanF 'Resolved
```

The constructors are not publicly exported. A resolved span can therefore
only be obtained through the resolution function, after checking it
against a concrete `NamedSource`. Tadka-GHC must use this invariant; it
must never construct an equivalent parallel resolved-span representation
inside the adapter.

`Diagnostic` is also an existing typeclass contract rather than a record
that Tadka-GHC may replace:

```haskell
class Diagnostic e where
  message         :: e -> Doc Ann
  context         :: e -> Context
  code            :: e -> Maybe DiagnosticCode
  severity        :: e -> Severity
  help            :: e -> Maybe (Doc Ann)
  url             :: e -> Maybe Url
  related         :: e -> [SomeDiagnostic]
  diagnosticId    :: e -> Maybe DiagnosticId
  diagnosticCause :: e -> Maybe SomeDiagnostic
```

Only `message` is mandatory; the remaining fields already have total
defaults. Tadka-GHC must produce a normal Tadka `Diagnostic` instance or
`SomeDiagnostic`, not a parallel diagnostic object graph.

## 4.3 Repository history is a correctness input

The audited repository history contains prior fixes for:

- silent label loss;
- missing related-diagnostic causes;
- GHC span misattribution;
- span-end overflow.

These are treated as discovered correctness constraints. The Tadka-GHC
implementation must not regress those semantics by introducing a second
location, label, related-diagnostic, or cause path.

# 5. Implementation Readiness Contract

Version 9.0 separates **design intent** from **implementation readiness**.
The adapter must not enter implementation-freeze merely because its module
diagram looks plausible. The following gates are mandatory.

## 5.1 Gate A — Tadka baseline

The Tadka dependency baseline must be pinned to an exact repository
revision and package version. Public APIs used by Tadka-GHC must be listed
explicitly. Any Tadka change required for GHC representation must be
justified as a generic Tadka capability rather than an adapter workaround.

## 5.2 Gate B — Exact external schema artifacts

For each initial GHC matrix cell, the repository must contain the exact
schema artifact used by the compiler release:

``` text
GHC 9.10.3 → pinned schema artifact
GHC 9.12.4 → pinned schema artifact
GHC 9.14.1 → pinned schema artifact
```

The 9.12.4 schema must not be inferred from the compiler version or from
9.10.x/9.14.x. The compiler version and schema version are independent
compatibility facts.

## 5.3 Gate C — Actual emitted fixtures

For each supported compiler, the repository must contain actual compiler
output for a fixture suite covering at least:

- ordinary error;
- ordinary warning;
- every distinct diagnostic reason required by the supported semantic domain;
- diagnostic code;
- primary span;
- secondary spans;
- multi-file diagnostics;
- related diagnostics;
- causes where emitted;
- hints/help;
- absent/unhelpful locations;
- malformed or boundary coordinates reachable from the schema;
- Unicode source text;
- multiple diagnostics in one process;
- non-diagnostic stderr surrounding structured output.

The fixture corpus is part of the compatibility contract, not merely a
test convenience.

## 5.4 Gate D — Code identity

Before translation is frozen, the project must decide whether Tadka's
current `DiagnosticCode` can represent the complete GHC diagnostic identity
required by the supported domain. The decision must be demonstrated with
actual GHC code values from every supported compatibility cell.

No implementation may silently serialize GHC identity into message text,
help text, URL fields, or invented Tadka code strings.

## 5.5 Gate E — Source acquisition

The integration contract must explicitly define how a diagnostic source id
is resolved to a `NamedSource`. The semantic core must receive a concrete
`SourceEnvironment`; it must not read files implicitly.

```haskell
newtype SourceEnvironment = SourceEnvironment
  (Map SourceId NamedSource)
```

The construction of this environment belongs to the integration boundary.
Source I/O is not part of decode, validate, or normalize. The pure
translation phase may consult the already-constructed environment; it may
not perform I/O itself.

## 5.6 Gate F — Representability and information loss

For every GHC field in the declared schema subset, the compatibility matrix
must state one and only one of:

``` text
preserved exactly
preserved semantically
explicitly represented elsewhere in Tadka
explicitly degraded according to policy
explicitly unsupported with classified failure
```

There is no implicit "best effort" category.

## 5.7 Gate G — Worked end-to-end proof example

At least one real diagnostic from each supported GHC major must be traced
through:

``` text
actual GHC output
 → wire value
 → validation result
 → normalized value
 → Tadka construction
 → rendered result
```

The trace must be concrete enough that an independent reviewer can inspect
every semantic decision.

Only after Gates A–G are closed may the implementation architecture be
considered frozen.


# 5. Architectural North Star

The architecture must preserve this dependency direction:

``` text
                     ┌────────────────────┐
                     │       TADKA        │
                     │                    │
                     │ Diagnostic         │
                     │ Source / Span      │
                     │ Context / Labels   │
                     │ Renderers          │
                     │ Configuration      │
                     └─────────▲──────────┘
                               │
                               │ depends on
                               │
                     ┌─────────┴──────────┐
                     │    TADKA-GHC       │
                     │                    │
                     │ GHC schema         │
                     │ decoding           │
                     │ normalization      │
                     │ GHC → Tadka map    │
                     └─────────▲──────────┘
                               │
                               │ consumes
                               │
                     ┌─────────┴──────────┐
                     │        GHC         │
                     │                    │
                     │ structured         │
                     │ diagnostics        │
                     └────────────────────┘
```

Never introduce the reverse dependency:

``` text
Tadka core → GHC
```

GHC integration is an adapter concern.

------------------------------------------------------------------------

# 6. One Canonical Intermediate Representation

The Haskell Engineering Standard requires one canonical intermediate
representation whenever multiple external formats converge on shared logic.

For Tadka-GHC the canonical path is:

``` text
JSON Lines
   │
   ▼
RawDiagnosticLine
   │ decode
   ▼
Versioned wire value
   │ validate
   ▼
ValidatedGhcDiagnostic
   │ normalize
   ▼
NormalizedGhcDiagnostic
   │ translate
   ▼
Tadka Diagnostic
```

There is exactly one semantic normalization path. There must not be a
second JSON-to-Tadka shortcut, a renderer-specific decoder, or a CLI-specific
semantic interpretation.

## 6.1 Concrete core type boundary

The implementation specification requires the following type-state
boundaries. Names may be adjusted during implementation only when the
semantic distinction remains identical.

```haskell
newtype RawDiagnosticLine = RawDiagnosticLine ByteString

newtype ValidatedGhcDiagnostic = ValidatedGhcDiagnostic
  { unValidatedGhcDiagnostic :: GhcWireDiagnostic
  }

data NormalizedGhcDiagnostic = NormalizedGhcDiagnostic
  { ngSeverity    :: !GhcSeverity
  , ngReason      :: !GhcDiagnosticReason
  , ngMessage     :: !Text
  , ngCode        :: !(Maybe GhcCodeIdentity)
  , ngLocations   :: ![NormalizedLocation]
  , ngHelp        :: ![NormalizedHelp]
  , ngRelated     :: ![NormalizedRelated]
  , ngCause       :: !(Maybe NormalizedCause)
  , ngUrl         :: !(Maybe Text)
  }

newtype GhcSeverity = GhcSeverity Text

newtype GhcDiagnosticReason = GhcDiagnosticReason Text

The text payloads above are semantic values, not arbitrary strings: validation
must admit only values defined by the exact pinned schema/compatibility
contract. If that contract defines a closed finite vocabulary, the production
implementation should use closed algebraic data types for those values rather
than retain the open `Text` representation. Unknown producer values must
never be silently collapsed into a known value.

data GhcCodeIdentity = GhcCodeIdentity
  { ghcCodeNamespace :: !Text
  , ghcCodeNumber    :: !Integer
  }

data GhcPosition = GhcPosition
  { ghcLine   :: !Integer
  , ghcColumn :: !Integer
  }

data GhcSpan = GhcSpan
  { ghcSpanSource :: !SourceId
  , ghcSpanStart  :: !GhcPosition
  , ghcSpanEnd    :: !GhcPosition
  }

data NormalizedLocation = NormalizedLocation
  { nlSourceId :: !SourceId
  , nlSpan     :: !GhcSpan
  , nlKind     :: !LocationKind
  , nlLabel    :: !(Maybe Text)
  }

newtype SourceId = SourceId Text

data LocationKind = Primary | Secondary

newtype NormalizedHelp = NormalizedHelp Text
newtype NormalizedRelated = NormalizedRelated NormalizedGhcDiagnostic
newtype NormalizedCause   = NormalizedCause NormalizedGhcDiagnostic
```

These are semantic boundary types, not a second public diagnostic framework.
The normalized representation is intentionally independent of Tadka's
renderer/document types: it contains GHC meaning as data and leaves
Tadka-specific presentation construction to translation.
In particular:

- `ValidatedGhcDiagnostic` still contains GHC semantics; it is not yet
  Tadka semantics.
- `NormalizedGhcDiagnostic` contains exactly the GHC semantics needed by
  the declared supported domain.
- source identifiers, GHC spans, and GHC code identity remain explicitly
  represented until translation; they are not smuggled through rendered strings.
- Tadka `Context`, `Span`, `ResolvedSpan`, `Severity`, `DiagnosticCode`,
  `Doc`, `Url`, and `SomeDiagnostic` remain Tadka-owned concepts and are
  created only in the translation phase.

The exact `GhcWireDiagnostic` definition is schema-version-specific and may
not be frozen until the exact JSON Schema artifacts are pinned. That is a
deliberate external-schema dependency, not permission to leave the semantic
type boundary unspecified.

## 6.2 Canonical pure API

The pure semantic core shall expose this shape:

```haskell
decode
  :: SchemaVersion
  -> RawDiagnosticLine
  -> Either DecodeError VersionedGhcDiagnostic

validate
  :: VersionedGhcDiagnostic
  -> Either ValidationError ValidatedGhcDiagnostic

normalize
  :: ValidatedGhcDiagnostic
  -> Either NormalizationError NormalizedGhcDiagnostic

translate
  :: SourceEnvironment
  -> NormalizedGhcDiagnostic
  -> Either TranslationError SomeDiagnostic

adapt
  :: SchemaVersion
  -> SourceEnvironment
  -> RawDiagnosticLine
  -> Either AdapterError SomeDiagnostic
adapt schema sources line = do
  wire       <- first DecodeFailure (decode schema line)
  validated  <- first ValidationFailure (validate wire)
  normalized <- first NormalizationFailure (normalize validated)
  first TranslationFailure (translate sources normalized)
```

`adapt` is total with respect to its declared input domain. Totality does not
imply successful translation: an explicit `Left` is the correct result for
malformed input, unsupported schema content, unavailable source text,
unrepresentable GHC semantics, resource limits, or other declared failures.

The process/stream layer must not be able to bypass `adapt`.

## 6.3 Pure error algebra

The semantic phases use distinct error types. They must not collapse all
failures into one unstructured textual exception.

```haskell
data PureAdapterError
  = DecodeFailure       DecodeError
  | ValidationFailure   ValidationError
  | NormalizationFailure NormalizationError
  | TranslationFailure  TranslationError

data DecodeError =
    MalformedJson
  | UnsupportedSchemaVersion SchemaVersion
  | LineTooLarge

data ValidationError
  = MissingRequiredField !Text
  | InvalidFieldValue !Text
  | InvalidStructure !Text
  | UnsupportedSemanticVariant !Text

data NormalizationError
  = ContradictoryDiagnostic !Text
  | UnrepresentableStructure !Text

data TranslationError
  = SourceUnavailable !SourceId
  | LocationFailure !SourceId !Text
  | DiagnosticCodeFailure !GhcCodeIdentity
  | TadkaConstructionFailure !Text
  | UnrepresentableDiagnostic !Text

data SchemaVersion = SchemaVersion !Text

type AdapterError = PureAdapterError
```

The exact constructors for schema-specific validation may be refined from
the pinned artifacts, but the phase distinction is normative. In particular,
a malformed JSON document is never reported as a translation failure and a
Tadka representability failure is never misreported as a JSON decoding
error.

Integration errors are a separate algebra and are not admitted into the
pure semantic functions:

```haskell
data IntegrationError
  = StreamFailure !StreamError
  | ProcessFailure !ProcessError
  | ResourceFailure !ResourceError

data StreamError
  = InvalidJsonLineFraming
  | UnexpectedStreamTermination

data ProcessError
  = ProcessStartFailure !Text
  | ProcessProtocolFailure !Text
  | GHCNonZeroExit !Int

data ResourceError
  = InputLimitExceeded
  | DiagnosticCountExceeded
  | OutputLimitExceeded
```

The precise integration constructors must be aligned with the process and
resource laws already defined later in this specification; the critical
requirement is that OS/process/stream failures remain outside the pure
translation algebra.

# 7. Zero-Configuration Goal

The defining product requirement is:

> **A Haskell developer should be able to obtain Tadka-quality
> presentation of GHC diagnostics without manually defining a Tadka
> `Diagnostic` instance for every GHC error.**

The integration should make the common case effectively:

``` text
install
  ↓
build
  ↓
GHC diagnostic
  ↓
Tadka rendering
```

The developer should not have to understand:

-   GHC's diagnostic JSON schema;
-   `SrcSpan` conversion;
-   severity translation;
-   GHC diagnostic codes;
-   related diagnostic structure;
-   Tadka context construction

merely to obtain a useful report.

------------------------------------------------------------------------

# 8. The Machine-Readable Boundary

The preferred input is GHC's structured diagnostic interface rather than
human-readable terminal output.

Conceptually:

``` text
GHC
 │
 │ -fdiagnostics-as-json
 ▼
JSON / JSON-Lines
 │
 ▼
Tadka-GHC decoder
```

Human-readable GHC output must not be the primary protocol.

This prevents the adapter from becoming coupled to:

-   terminal indentation;
-   whitespace;
-   colour;
-   line wrapping;
-   punctuation;
-   prose wording;
-   visual layout.

GHC's structured representation is the source of truth.

The protocol choice is grounded in GHC's documented interface:
`-fdiagnostics-as-json` emits standardized diagnostic JSON directly to
`stderr` using JSON Lines, with the structure described by a JSON
Schema. GHC documents `-ddump-json` as deprecated in favour of
`-fdiagnostics-as-json`. These facts are treated as external protocol
premises and must be pinned to the exact documentation/schema versions
used by each supported compatibility cell.

### Structured-diagnostic coverage boundary

The compatibility claim applies to diagnostics that GHC 9.10+ emits
through the supported structured diagnostic interface. It does not imply
that every byte written to `stderr` by GHC, a linker, a preprocessor, a
plugin, or another external tool is a Tadka diagnostic.

Non-diagnostic stderr remains data owned by the process edge. It must be
forwarded according to the integration contract and must never be parsed
heuristically as a Tadka diagnostic merely because it resembles compiler
prose.

------------------------------------------------------------------------

# 9. Schema Versioning Is a First-Class Concern

GHC diagnostic schemas evolve.

Therefore schema version must be treated as a domain concept.

The design should permit:

``` text
schema version A ──┐
schema version B ──┼──→ normalized diagnostic
schema version C ──┘
```

Rules:

-   Every supported schema version has explicit decoding behaviour.
-   Unsupported major versions fail explicitly.
-   Compatible schema additions are handled according to their
    compatibility semantics.
-   Version-specific logic is isolated.
-   Schema upgrades require fixtures and tests.
-   No decoder should silently reinterpret an unknown schema as a known
    schema.
-   Unknown optional fields in a known compatible schema may be ignored
    as transport metadata, but they must not be assigned invented
    semantics.
-   A newly introduced required semantic field requires an explicit
    compatibility decision before the schema is considered supported.

A future GHC schema change should normally require changes to Tadka-GHC,
not Tadka core.

### Schema compatibility algebra

Schema versions are not merely integers. Compatibility is a relation
over semantic languages and semantic decoders.

For a schema `S`, define:

``` text
Dom(S) = { r | decodeS(r) succeeds }
```

For two schemas, define a declared compatibility language:

``` text
K ⊆ Dom(S1) ∩ Dom(S2)
```

Then:

``` text
CompatibleOn(S1,S2,K)
    ⇔
    K ⊆ Dom(S1)
    ∧
    K ⊆ Dom(S2)
    ∧
    ∀r ∈ K:
        ⟦decodeS1(r)⟧V
        =
        ⟦decodeS2(r)⟧V
```

The common language `K` must itself be non-empty for a compatibility
claim unless the project explicitly declares that the two schema
versions have no shared supported records. Compatibility may never be
established merely by vacuous truth over an empty intersection.

For a **full compatibility claim**, the declared supported languages
must be equal:

``` text
Dom_supported(S1) = Dom_supported(S2)
```

and semantic interpretation must agree on that domain.

For a **schema extension**, define the schema-extension relation:

``` text
S1 ≼schema S2
```

when every record accepted by the supported language of `S2` has a
semantics- preserving projection into the supported language of `S1`:

``` text
∀r ∈ Dom_supported(S2):
    projectS1(r) is defined
    ∧
    ⟦decodeS1(projectS1(r))⟧V
      =
    ⟦decodeS2(r)⟧V
```

This is the normative meaning of `KnownCompatibleExtension`.

The implementation shall distinguish at the semantic boundary:

``` text
KnownSupportedSchema
KnownCompatibleExtension
UnknownSchema
KnownSchemaWithUnsupportedRequiredSemantics
```

Unknown optional fields may be ignored only when the producer schema
contract establishes that they carry no semantics required by the
declared supported diagnostic subset.

An unknown field must never be assigned meaning merely because its name
looks similar to an existing Tadka field.

An unknown required semantic field is a compatibility failure.

The decoder must not infer schema identity solely from the compiler
version. The schema identity carried by the protocol is authoritative
where available; the compiler version is supporting compatibility
metadata. The schema identity carried by the protocol is authoritative
where available; the compiler version is supporting compatibility
metadata.

### Rendered output is not the semantic source

Where a GHC schema provides a pre-rendered diagnostic representation,
that representation is **not the canonical semantic input to
Tadka-GHC**.

The semantic path is:

``` text
GHC structured diagnostic
        ↓
Tadka-GHC semantic translation
        ↓
Tadka diagnostic
        ↓
Tadka renderer
```

not:

``` text
GHC rendered text
        ↓
Tadka
```

A rendered GHC field may be retained as reference data if required by
the schema, but Tadka-GHC must not parse human-oriented rendered output
to reconstruct semantics that GHC already exposes structurally.

------------------------------------------------------------------------

# 10. GHC Version Compatibility

GHC version compatibility must be explicit and mechanically tested.

The project should maintain a matrix such as:

``` text
Tadka-GHC release
       │
       ├── supported GHC versions
       │
       └── supported diagnostic schema versions
```

Compatibility is not established merely because the source happens to
compile.

It requires:

``` text
compile
+
decode actual GHC output
+
translate
+
render
```

for every supported compiler.

A GHC release that changes diagnostic representation must produce an
intentional compatibility decision:

-   supported;
-   temporarily unsupported;
-   supported through a new decoder;
-   or requiring a new Tadka capability.

That decision should be recorded.

### Compatibility coverage boundary

"100% compatibility" applies to the declared **structured diagnostic
semantic domain**, not to arbitrary bytes that GHC may emit to `stderr`.

The boundary is:

``` text
supported GHC structured diagnostics
              │
              ▼
        Tadka-GHC contract
```

Other compiler output may exist on the same operating-system stream,
including logs, dumps, progress output, or future producer-owned
records. Such output is not silently reinterpreted as a Tadka
diagnostic.

Where the integration must preserve non-diagnostic stderr, it remains
opaque process output unless a separate, explicitly specified protocol
covers it.

### Four-dimensional compatibility matrix

Compatibility is defined over four version axes:

``` text
Tadka-GHC version
        ×
Tadka version
        ×
GHC version
        ×
GHC diagnostic schema version
```

A release is supported only for declared cells in this matrix.

The initial **structured-diagnostic** compiler cells are exactly:

``` text
GHC 9.10.3
GHC 9.12.4
GHC 9.14.1
```

This does not reduce Tadka's own compiler compatibility. The current Tadka
package separately tests GHC 9.6.7 and 9.8.4 as well. Those compiler cells
are outside the initial Tadka-GHC structured-diagnostic contract unless and
until the corresponding structured-diagnostic protocol contract is added.

The diagnostic transport itself (e.g. `-fdiagnostics-as-json` versus a
future successor protocol) is a candidate fifth axis in principle, but
it is deliberately not one of the four declared above: all cells in the
initial matrix use the same transport, `-fdiagnostics-as-json`, so this
candidate axis is fixed/degenerate for the initial release rather than
varying. Should a future release need to support more than one
diagnostic transport simultaneously, the matrix must be revised to add
it as an explicit fifth axis rather than handled implicitly. Schema
version remains one of the four declared axes because the JSON schema
can evolve independently of the compiler version even while the
transport stays the same.

For every supported cell, CI must verify:

``` text
compile
  +
actual GHC execution
  +
structured diagnostic emission
  +
schema decoding
  +
semantic normalization
  +
Tadka conversion
  +
Tadka rendering
  +
failure behaviour
```

------------------------------------------------------------------------

# 10.1 Mandatory GHC-to-Tadka Semantic Mapping

### Diagnostic-code representability gate

Before implementation begins, the project must establish from actual
supported compiler fixtures that Tadka's public `DiagnosticCode`
abstraction can faithfully represent the GHC code identity required by
the contract:

``` text
GhcCodeIdentity = ProducerNamespace × ProducerCode
```

If the current Tadka API cannot preserve both producer provenance and
numeric identity, Tadka-GHC must not encode that information into an
unrelated field, string convention, URL, message, or fabricated code
merely to satisfy the interface.

The only gold-standard outcomes are:

``` text
existing Tadka representation is sufficient
```

or:

``` text
a deliberate, generic Tadka capability is added
```

or:

``` text
the GHC code capability is explicitly declared unrepresentable
and follows the information-loss policy
```

The third case must be a conscious compatibility decision, not an
accidental implementation limitation.

Before implementation, the project shall maintain a normative mapping
table covering every supported GHC diagnostic field and semantic
concept.

  ----------------------------------------------------------------------------
  GHC concept             Tadka destination   Preservation    If not
                                              rule            representable
  ----------------------- ------------------- --------------- ----------------
  message                 `message`           Preserve        explicit
                                              semantic        architectural
                                              meaning         decision

  effective severity      `severity`          Preserve        explicit
                                              effective       unsupported case
                                              diagnostic      
                                              severity        

  diagnostic              preserved in the    Never collapse  explicit loss
  reason/classification   GHC semantic bridge it into         decision
                          where required      effective       
                                              severity unless 
                                              the equivalence 
                                              is specified    

  code                    `DiagnosticCode`    Preserve        explicit
                          where valid         identity and    preservation
                                              namespace       strategy

  span                    `Context` / `Span`  Preserve exact  degradation or
                                              coordinate      typed failure
                                              semantics       

  hints                   `help` when         Preserve        do not map
                          equivalent          epistemic       
                                              strength        

  related diagnostics     `related`           Preserve        explicit
                                              relationship    unsupported case
                                              semantics       

  cause                   `diagnosticCause`   Never infer     do not map
                          only when justified causality       

  URL                     `url` when          Preserve        do not fabricate
                          equivalent          supplied value  

  rendered                not canonical       Never parse as  reference-only
                                              semantic input  if needed
  ----------------------------------------------------------------------------

This table is a design artifact and a release artifact. Any GHC schema
or Tadka API change affecting it requires review and corresponding
tests.

# 11. Source Location Semantics

GHC source locations are semantic data, not presentation hints.
Source-location conversion is therefore a correctness-critical
mathematical transformation.

The specification must distinguish:

``` text
SourceIdentity
SourceContent
Position
Span
SourceRegion
```

These objects must not be conflated.

## 11.1 Coordinate domain

For the supported GHC structured diagnostic protocol, the implementation
shall use the coordinate semantics defined by GHC for that protocol. The
exact coordinate convention for each supported schema version must be
captured in the versioned schema contract and tested against actual
compiler output.

A coordinate domain is written abstractly as:

``` text
Position = (line, column)
```

with explicit domains for `line` and `column`, explicit origin
conventions, and explicit endpoint semantics.

No implementation may use an undocumented conversion such as:

``` text
column = character index
column = byte offset
column = grapheme index
column = terminal display width
```

unless that equivalence is established by the protocol contract.

## 11.2 Source interpretation

For a source `S`, define:

``` text
offsetS : Position → Either LocationError Offset
```

over the positions representable in `S`.

For a span:

``` text
Span = (start, end)
```

define:

``` text
regionS : Span → Either LocationError SourceRegion
```

The exact endpoint convention must be normative. If the GHC protocol
uses half-open ranges, the mathematical model shall say so explicitly;
if a different convention is used by a particular schema, that schema's
decoder must establish the corresponding normalized representation.

## 11.3 Conversion invariant

The conversion function is typed as:

``` text
resolve : SourceEnvironment → GhcSpan → Either LocationError TadkaSpan
```

For:

``` text
g ∈ GhcSpan
resolve(S,g) = Right(t)
```

the normative preservation law is:

``` text
regionGHC(S,g)
    =
regionTadka(S,t)
```

where equality is equality of the selected source region under the
applicable source-coordinate metric, endpoint convention, and source
identity.

This is the primary semantic preservation theorem for span conversion.

A stronger extensionality property shall also be tested over the
representable domain. For any two GHC spans that denote the same source
region:

``` text
resolve(S,g1) = Right(t1)
resolve(S,g2) = Right(t2)
regionGHC(S,g1) = regionGHC(S,g2)
    ⇒
regionTadka(S,t1) = regionTadka(S,t2)
```

There is no well-typed form of this law in which `resolve(S,g)` itself
is passed to `regionTadka`, because `resolve` returns an `Either`. The
successful `Right(t)` binding is part of the contract.

`resolve` is the sole normative name for this operation. No separate
`translateSpan` function is introduced by this specification.

## 11.4 Source identity

A path is not source identity.

The source environment must distinguish:

``` text
SourceIdentifier
SourceContent
SourceProvenance
```

A source file used for rendering must not be silently assumed to be
identical to the source consumed by GHC merely because both have the
same pathname.

Where the integration can establish identity, that identity shall be
recorded. Where it cannot, the source shall be treated as unverified.

Conceptually:

``` text
VerifiedSource
UnverifiedSource
UnavailableSource
```

may be distinct internal states if required by the implementation.

The adapter must never use unverified source content to silently alter
the meaning of a GHC span.

## 11.5 Required boundary cases

The specification and tests must cover:

-   empty files;
-   offset/position origin;
-   first character;
-   end-of-line;
-   end-of-file;
-   zero-length spans;
-   multiline spans;
-   CRLF;
-   LF;
-   Unicode;
-   tabs;
-   combining characters;
-   wide characters;
-   invalid coordinates;
-   out-of-range coordinates;
-   generated source names;
-   virtual sources;
-   unavailable source;
-   unhelpful/absent GHC locations.

The test oracle is the mathematical region-preservation law, not visual
similarity of a rendered caret.

## 11.6 No invented locations

If a GHC location cannot be represented faithfully:

``` text
cannot represent
      ↓
typed failure or explicit degradation
```

never:

``` text
guess
  ↓
plausible-looking span
```

A renderer must never be allowed to influence source-location semantics.

# 12. Source Text

A GHC location and a Tadka source snippet are related but distinct
concerns.

Tadka-GHC must clearly distinguish:

``` text
GHC told us where the diagnostic is
```

from:

``` text
we have the source text required to display that location
```

The adapter must not silently assume that source text is always
available.

Possible source acquisition belongs at an explicit boundary:

``` text
GHC diagnostic
      +
source repository / filesystem / supplied source
      ↓
Tadka source context
```

The policy for acquiring source must be explicit.

Source identity is part of correctness. A filesystem path alone is not
proof that the bytes/text now available are the source against which GHC
produced the diagnostic. The integration shall either:

1.  obtain the source from a trusted build boundary; or
2.  establish an explicit source-identity invariant; or
3.  leave the location unresolved/degraded.

It must never resolve a span against merely convenient but potentially
different source text.

If a source cannot be obtained, Tadka's existing stale/degraded context
mechanisms should be used where appropriate rather than fabricating
source content.

### Source environment contract

Source acquisition is an effectful concern and therefore belongs outside
the pure semantic core.

Conceptually:

``` text
SourceEnvironment
    ├── resolve source identity
    ├── acquire source content
    └── establish provenance / verification state
```

The pure core consumes an explicit source value or an explicit absence
of one. It must never reach into the filesystem implicitly.

The source environment must make the following states distinguishable:

``` text
SourceVerified
SourceUnverified
SourceUnavailable
```

A verified source is one for which the integration has established the
identity relationship required by the source-location contract. An
unverified source may be rendered only under an explicit policy that
does not allow it to redefine the semantic location supplied by GHC.

------------------------------------------------------------------------

## 12.1 Concrete source-environment contract

Source acquisition is an integration concern. The pure semantic core
receives sources that have already been loaded and validated:

```haskell
newtype SourceEnvironment = SourceEnvironment
  (Map SourceId NamedSource)
```

The pure translator may query this environment but may not:

- open files;
- follow symlinks;
- consult the current working directory;
- invoke GHC;
- infer a source file from a message string;
- mutate source contents.

The environment is therefore a complete input to source-aware semantic
translation. Missing source identity and missing source content remain
explicit outcomes governed by the information-loss/location policy.

# Source-content independence and coordinate semantics

Source-content acquisition and source-location semantics are separate
concerns.

A diagnostic's semantic source location is determined by the GHC
diagnostic record. Source content is auxiliary data used by Tadka for
rendering context.

Therefore:

``` text
source-content acquisition may fail
    ≠
source-location conversion may fail
```

In particular:

``` text
SourceVerified
SourceUnverified
SourceUnavailable
```

must never change the normalized GHC coordinates.

The invariant is:

``` text
same diagnostic coordinates
+
different source-content availability
=
same semantic source location
```

A renderer may omit source excerpts when content is unavailable or
unverifiable, but it must not move, widen, narrow, or otherwise redefine
the diagnostic span to match whatever source content happens to be
available.

## Source-coordinate metric

The implementation shall define the exact GHC coordinate metric used by
each supported JSON protocol cell before implementing span conversion. A
column is not assumed to mean a Unicode scalar index, grapheme index,
byte offset, or terminal display width merely because one of those
metrics is convenient.

For every supported schema cell, the contract shall specify:

``` text
line domain
column domain
line origin
column origin
endpoint convention
encoding/measurement metric
```

The conversion function must be proven against that metric rather than
inferred from rendered text.

## Span representation

A source span is an abstract pair of endpoints:

``` text
Span = (start, end)
```

No endpoint convention is assumed by this document.

For each supported GHC/schema compatibility cell, the source-coordinate
contract must explicitly declare:

-   line domain and origin;
-   column domain and origin;
-   coordinate measurement metric;
-   endpoint convention on each coordinate axis;
-   encoding assumptions, where relevant;
-   the semantic source-region interpretation induced by those rules.

The normalized Tadka span representation must be derived from that
declared cell contract. A half-open convention such as:

``` text
[start, end)
```

may be used only where the exact supported GHC schema and coordinate
semantics establish it. It is not the document-wide default.

Zero-length spans are valid only when the applicable source-coordinate
contract defines the corresponding start and end as the same semantic
source position.

The normative preservation law is stated only through the typed success
case in §11.3 and §45.6. No equation may pass an `Either` value directly
to `regionTadka`.

For multiline and Unicode source, equality is semantic equality of
source regions under the applicable coordinate metric and endpoint
rules, not equality of raw line/column integers after an arbitrary
conversion.

------------------------------------------------------------------------

# 13. Severity and Diagnostic Reason

GHC diagnostic reason and effective severity are distinct semantic
dimensions and must remain distinct throughout the GHC semantic bridge.

Conceptually:

``` text
DiagnosticReason
       +
GHC diagnostic configuration / resolution
       ↓
EffectiveSeverity
```

The normalized representation must therefore preserve the distinct
concepts when they are present in the GHC protocol.

Tadka's `Severity` is a presentation/diagnostic semantic destination. It
must not be used as a lossy container for GHC's diagnostic reason.

The normative mapping is:

``` text
GHC effective severity
        ↓
Tadka Severity
```

while:

``` text
GHC diagnostic reason
        ↓
preserved in normalized GHC semantics
```

unless and until the Tadka model provides a semantically equivalent
destination.

The mapping must be:

-   explicit;
-   total over the supported GHC severity vocabulary;
-   deterministic;
-   documented;
-   property-tested;
-   regression-tested.

Structured severity information takes precedence over parsing
human-readable message text.

No string heuristic may determine severity when GHC has already supplied
that information structurally.

The adapter must also preserve the distinction between an intrinsic
compiler failure and a warning whose effective treatment is changed by
compiler configuration. In particular, warning promotion must not be
reconstructed by guessing from rendered text.

The three concepts below are distinct and must never be collapsed:

``` text
DiagnosticReason
DiagnosticSeverity
CompilerTermination
```

In particular:

``` text
DiagnosticSeverity ≠ CompilerTermination
```

A diagnostic may have effective severity `Error` while the process
outcome is determined independently by GHC's compilation state and
termination semantics. The adapter must not infer process success or
failure from an individual diagnostic's severity, nor infer diagnostic
severity from the compiler exit code.

GHC's diagnostic model explicitly distinguishes diagnostic reason from
severity; warning reasons can be associated with error severity under
configuration such as `-Werror`. citeturn1search0

# 14. Diagnostic Codes

GHC diagnostic codes are namespaced numeric identities. Tadka-GHC must
preserve producer provenance rather than converting a producer-owned
code into an apparently Tadka-owned identifier.

The semantic code type is:

``` text
NamespacedTadkaCode
    = ProducerNamespace × ProducerCode
```

The canonical GHC mapping is conceptually:

``` text
M : GhcCode → NamespacedTadkaCode

M(g) = (GHC, g)
```

For a set of GHC codes, use image notation explicitly:

``` text
M[GhcCode] = { M(g) | g ∈ GhcCode }
```

Therefore:

``` text
g1 ≠ g2
    ⇒
M(g1) ≠ M(g2)
```

and GHC-owned codes cannot collide semantically with native Tadka-owned
codes because their producer namespaces are distinct.

A string prefix or integer transformation is only an implementation
technique; it is not the semantic definition of the namespace.

The mapping must preserve the original GHC numeric identity and producer
namespace wherever Tadka's public representation permits it.

### Library versus integration executable

Tadka-GHC consists conceptually of two layers:

``` text
Tadka-GHC Core
    = pure GHC representation → Tadka translation library

Tadka-GHC Integration
    = GHC process → structured diagnostics → Core → presentation
```

The core is the stable semantic API. The process integration is an
effectful adapter and may evolve independently provided it preserves the
core contracts.

If both are shipped in one package, the module/export boundaries must
still preserve this distinction. If they are split into packages, the
dependency must remain one-directional:

``` text
integration executable → tadka-ghc-core → tadka
```

never:

``` text
tadka → tadka-ghc-core
```

# 15. Messages

GHC's diagnostic message is semantic input.

Tadka-GHC should preserve it faithfully.

It may adapt the representation from GHC's structured message model into
Tadka's `Doc Ann` representation, but it must not alter meaning.

It must not:

-   invent explanations;
-   infer a cause;
-   rewrite a compiler assertion as a fact not supplied by GHC;
-   turn a suggestion into a guaranteed fix;
-   embellish a diagnostic to make Tadka appear more capable.

The design principle is:

> **Preserve information; do not manufacture information.**

------------------------------------------------------------------------

# 16. Hints and Help

Where GHC provides structured hints or suggestions, Tadka-GHC may map
them to Tadka's `help` field when the semantic correspondence is exact.

The adapter must preserve the epistemic strength of the original
information.

For example:

``` text
GHC suggestion
```

must not become:

``` text
Tadka guarantees this is the correct fix
```

The adapter changes representation, not certainty.

------------------------------------------------------------------------

# 16.1 Information-Loss Policy

"Preserve information" does not mean that every internal GHC datum has a
Tadka equivalent.

The normative policy is:

  ---------------------------------------------------------------------
  GHC semantic                      Faithful Tadka Required action
  information                      representation? 
  -------------------- --------------------------- --------------------
  Message                                      Yes Preserve

  Severity/reason         Yes, where semantics map Preserve
                                           exactly 

  Source location          Yes, when representable Preserve

  Diagnostic code        Yes, subject to namespace Preserve
                                            policy 

  Hint                      Yes, when semantically Preserve
                              equivalent to `help` 

  Related diagnostic        Yes, when relationship Preserve
                                   semantics match 

  Cause                    Only when GHC semantics Preserve only then
                               establish causality 

  URL                       Yes, when semantically Preserve
                                        equivalent 

  Producer metadata                             No Do not reinterpret
  with no Tadka                                    
  equivalent                                       

  Exact rendered GHC                 Not canonical Never parse as
  presentation                                     semantics

  Unsupported future                       Unknown Explicit
  schema semantics                                 compatibility
                                                   failure
  ---------------------------------------------------------------------

The adapter shall never silently:

-   drop semantic information that Tadka could represent;
-   reinterpret one Tadka field as another merely to avoid an error;
-   turn producer metadata into a fabricated Tadka field;
-   manufacture a code, cause, help text, URL or source span.

If an important GHC capability cannot be represented faithfully, the
project must decide explicitly whether it is:

``` text
GHC capability
      ↓
Can Tadka represent it faithfully?
      │
   ┌──┴──┐
  yes    no
   │      │
   ▼      ▼
map    architectural review
          │
       ┌──┴──────────────┐
       ▼                 ▼
generic Tadka        Tadka-GHC-only
capability           representation
```

If neither is acceptable, the capability remains explicitly unsupported
rather than being approximated.

------------------------------------------------------------------------

# 17. Primary, Secondary and Related Information

Tadka already distinguishes:

-   primary labels;
-   secondary labels;
-   related diagnostics;
-   underlying causes.

Tadka-GHC must preserve GHC's distinctions wherever the source
representation supplies them.

Do not flatten all locations into one list merely because the renderer
can display a list.

Do not confuse:

``` text
related diagnostic
```

with:

``` text
underlying cause
```

unless GHC's semantics explicitly support that mapping.

The Tadka representation should communicate what GHC actually knows.

------------------------------------------------------------------------

# 18. Multiple Diagnostics

A compilation may produce multiple diagnostics.

Tadka-GHC must therefore model a diagnostic stream/collection, not a
single-error assumption.

The architecture must preserve:

-   diagnostic order where meaningful;
-   individual severity;
-   individual source information;
-   individual codes;
-   individual hints;
-   relationships.

The adapter must not assume:

``` text
one build → one error
```

------------------------------------------------------------------------

# 19. Trust Boundary

GHC diagnostic input is external data.

The decoder boundary must be:

``` text
UNTRUSTED
JSON
  │
  ▼
parse
  │
  ▼
validate
  │
  ▼
normalize
  │
  ▼
TRUSTED DOMAIN VALUE
  │
  ▼
Tadka
```

No unchecked JSON field should become a trusted Tadka value.

The decoder must not use:

-   `read` as a general interchange mechanism;
-   unchecked numeric conversions;
-   partial pattern matching;
-   `fromJust`;
-   unsafe indexing;
-   exceptions as the expected malformed-input path.

------------------------------------------------------------------------

# 20. Error Algebra

Errors must correspond to real, reachable pipeline boundaries.

The formal semantic translation function and the whole adapter pipeline
use different error domains.

The pure translation stage is:

``` text
translate : N → Either TranslationError T
```

where `TranslationError` contains only failures that can arise while
converting an already-normalized `N` into a Tadka diagnostic. It
therefore does not contain decode, validation, stream, process, or
pre-normalization failures.

If translation itself performs GHC-to-Tadka source-location resolution,
a location-conversion failure belongs to `TranslationError` (for
example, through a dedicated `LocationTranslationFailure LocationError`
constructor). By contrast, failure to acquire or read source content at
the process edge remains a pipeline-level `SourceFailure SourceError`.
These are distinct failure boundaries and must not be conflated.

The whole adapter pipeline exposes the larger operational algebra:

``` text
AdapterError
  = DecodeFailure DecodeError
  | SchemaCompatibilityFailure CompatibilityError
  | ValidationFailure ValidationError
  | TranslationFailure TranslationError
  | SourceFailure SourceError
  | RepresentabilityFailure RepresentabilityError
  | ResourceFailure ResourceError
  | StreamFailure StreamError
  | ProcessFailure ProcessError
  | InternalInvariantViolation InternalError
```

Thus the relationship is explicit:

``` text
TranslationFailure : TranslationError → AdapterError
```

There is no claim that `TranslationError = AdapterError`.

The exact Haskell constructors may be grouped differently, but the
semantic distinctions and this embedding relationship are normative.

In particular:

``` text
unsupported semantic feature
    ≠
unsupported schema
    ≠
resource exhaustion
    ≠
stream framing failure
    ≠
internal invariant violation
```

An `InternalInvariantViolation` indicates a defect in Tadka-GHC or a
violated internal proof obligation. It must never be reported as though
the GHC diagnostic itself were unsupported.

Resource exhaustion is an operational failure of the adapter, not
evidence that the diagnostic is semantically unrepresentable.

The error algebra is closed. A constructor exists only when the
implementation has a real, specified path that can produce it. Do not
create a catch-all:

``` haskell
OtherError Text
```

merely to avoid making the error algebra precise.

The error algebra must also distinguish **semantic failure** from
**operational failure**. A semantically valid diagnostic may fail to
translate because the adapter has exhausted an explicit resource bound;
that does not make the diagnostic semantically unsupported.

------------------------------------------------------------------------

# 21. Totality

Totality is a semantic requirement, not a grep rule.

Production code reachable from the public adapter API must not use partial
operations whose failure would escape the declared `Either`/`Maybe`/typed
state boundary. This includes, at minimum, `head`, `tail`, `last`, `init`,
`!!`, `fromJust`, `undefined`, `error`, and unchecked pattern matches.

An internal operation justified by a proven local invariant is not made
acceptable merely by comment. The preferred order is:

``` text
1. represent the invariant in the type system;
2. otherwise eliminate the partial operation algorithmically;
3. otherwise make the invariant explicit and exhaustively test it;
4. only then permit a narrowly scoped internal assumption, never at a
   public semantic boundary.
```

Test helpers may use controlled failure to report an unexpected test result,
but such helpers are not evidence that production semantic code is total.

Every externally reachable conversion function must be total.

The project must prohibit partial functions including:

``` haskell
head
tail
last
init
fromJust
(!!)
error
undefined
```

and incomplete pattern matches.

The compiler must enforce the standard through the project's warning
configuration.

The invariant is:

``` text
Malformed GHC input
       ↓
Either controlled error
or
valid diagnostic
```

Never:

``` text
Malformed GHC input
       ↓
process crash
```

------------------------------------------------------------------------

# 22. Type-Driven Design

The Haskell type system should encode the strongest useful invariants.

Appropriate uses include:

-   newtypes for GHC-specific identifiers;
-   distinct types for schema versions;
-   validated source locations;
-   validated diagnostic representations;
-   explicit severity;
-   explicit source availability;
-   typed conversion errors.

Do not introduce GADTs, DataKinds, phantom types, or existential
wrappers merely because they are sophisticated Haskell techniques.

The governing rule is:

> **Use the least powerful mechanism that fully establishes the
> invariant.**

Escalation must be justified.

------------------------------------------------------------------------

# 23. Pure Core

The core translation should be pure.

The ideal architecture is:

``` text
                 IO boundary
                     │
                     ▼
             bytes / JSON text
                     │
                     ▼
              pure decoding
                     │
                     ▼
             pure validation
                     │
                     ▼
             pure normalization
                     │
                     ▼
             pure Tadka mapping
                     │
                     ▼
              Tadka rendering
```

Process execution, filesystem access and streaming belong at the edges.

The core should be testable without invoking GHC or a filesystem.

------------------------------------------------------------------------

# 24. Module Architecture

The project should be organized by domain responsibility, not generic
technical buckets.

A likely architecture is:

``` text
Tadka.GHC
Tadka.GHC.Error
Tadka.GHC.Schema
Tadka.GHC.Decode
Tadka.GHC.Normalize
Tadka.GHC.Convert
Tadka.GHC.Source
```

and, if a CLI is eventually justified:

``` text
Tadka.GHC.CLI
```

The exact module names should be decided before implementation, but the
boundaries must reflect responsibility.

Avoid:

``` text
Utils
Helpers
Common
Misc
```

as dumping grounds.

Every module should have one reason to change.

------------------------------------------------------------------------

# 24.1 Concrete package/module architecture

The first implementation should preserve the following package split:

``` text
tadka
├── core public Tadka API
└── interop-ghc
    └── existing SrcSpan → Span adapter

tadka-ghc
├── Tadka.GHC.Schema
├── Tadka.GHC.Decode
├── Tadka.GHC.Validate
├── Tadka.GHC.Normalize
├── Tadka.GHC.Translate
├── Tadka.GHC.Source
├── Tadka.GHC.Stream
└── Tadka.GHC.Process        -- integration boundary only
```

The final module names may be simplified, but responsibilities must remain
separate. In particular:

- schema modules know wire structure;
- decode modules know JSON syntax and framing;
- validation modules establish wire-level invariants;
- normalization establishes the canonical semantic representation;
- translation is the only pure boundary into Tadka semantics;
- source modules define source-environment construction/lookup contracts;
- stream modules frame JSON Lines;
- process modules own GHC invocation and operating-system effects.

No semantic interpretation belongs in the process layer. No process logic
belongs in the pure translator.

# 25. Dependency Direction

The dependency graph must be acyclic:

``` text
Schema
  ↓
Decode
  ↓
Normalize
  ↓
Convert
  ↓
Tadka
```

No lower-level module may import a higher-level integration module
merely for convenience.

The core normalization logic must not import CLI code.

The Tadka core must never import Tadka-GHC.

------------------------------------------------------------------------

# 26. Extension Axis

The Haskell Engineering Standard requires the extension mechanism to be
deliberately chosen.

For GHC schemas, the supported vocabulary is effectively closed and
compiler-owned:

``` text
closed / exhaustive representation
```

This is preferable because a newly introduced schema constructor should
produce compile-time pressure at every place requiring review.

For genuinely open extension points, use an appropriate
record-of-functions/Handle or typeclass boundary.

Do not mix closed and open approaches accidentally.

------------------------------------------------------------------------

# 27. No Speculative Generalization

Do not build a generic:

``` text
UniversalCompilerDiagnosticAdapter
```

unless a real requirement exists.

Do not design:

``` text
N compiler backends
M schema families
K plugin systems
```

before those extension axes actually exist.

The first implementation should solve:

> GHC structured diagnostics → Tadka.

Future generalization must be earned by real requirements.

------------------------------------------------------------------------

# 28. Integration and CLI Architecture

The pure adapter and process orchestration are separate
responsibilities, but the product architecture must define how the
seamless common path is achieved.

The normative architecture is:

``` text
                         Cabal / build workflow
                                  │
                                  ▼
                                 GHC
                                  │
                     -fdiagnostics-as-json
                                  │
                                  ▼
                         JSON Lines stream
                                  │
                                  ▼
                         Tadka-GHC edge
                    ┌─────────────┴─────────────┐
                    │ process / stream handling │
                    │ exit-status preservation  │
                    └─────────────┬─────────────┘
                                  │
                                  ▼
                         Tadka-GHC core
                    decode → validate → normalize
                                  │
                                  ▼
                              translate
                                  │
                                  ▼
                           Tadka Diagnostic
                                  │
                                  ▼
                           Tadka renderer
```

The exact user-facing command or Cabal integration mechanism shall be
selected during implementation design, but it must satisfy this
architecture. Human-readable GHC stderr scraping must not be the primary
protocol. The integration mechanism must be transparent to compilation:
it shall preserve GHC arguments, working directory, relevant
environment, standard-input semantics, compiler exit status, and signal
termination semantics.

If a CLI is provided:

``` text
tadka-ghc-cli
    process creation
    stream handling
    GHC invocation
    diagnostic forwarding
    exit-status preservation

tadka-ghc-core
    decoding
    validation
    normalization
    GHC → Tadka semantic conversion
```

The core remains pure.

### Formal process and exit-status model

The process edge must distinguish process lifecycle, compiler
termination, adapter processing, and integration outcome.

Define:

``` text
CompilerTermination
  = CompilerExited ExitCode
  | CompilerSignalled Signal

CompilerProcess
  = CompilerStarted CompilerTermination
  | CompilerStartFailed ProcessError
```

Define adapter outcome separately:

``` text
AdapterResult
  = AdapterSucceeded
  | AdapterFailed AdapterError
```

The integration result is:

``` text
IntegrationResult
  = IntegrationSucceeded
  | IntegrationCompilerFailed CompilerProcess
  | IntegrationAdapterFailed AdapterFailureContext
```

where:

``` text
AdapterFailureContext
  = AdapterFailedBeforeCompilerTermination AdapterError CompilerProcess
  | AdapterFailedAfterCompilerTermination AdapterError CompilerTermination
```

The exact concrete Haskell representation may be simplified, but the
semantics must preserve the following facts:

1.  A compiler start failure means no compiler process existed and
    therefore no compiler diagnostic stream existed.
2.  A compiler termination is distinct from an adapter failure.
3.  If both compiler and adapter failures occur, both facts remain
    available to the caller.
4.  Adapter failure must never be mistaken for compiler success.
5.  Compiler failure must never be erased merely because some
    diagnostics were successfully decoded.
6.  Compiler success must never be inferred merely because at least one
    diagnostic was decoded.

The conceptual composition is therefore:

``` text
process start
    │
    ├── start failure
    │
    └── running compiler
            │
            ├── exited
            └── signalled
```

with adapter processing occurring concurrently with the running process.

The external process exit code chosen for an adapter failure is an
implementation/product decision. It must be stable, documented, and
independent of arbitrary GHC exit codes. The original compiler
termination, when available, must remain observable in the structured
integration result.

This model deliberately avoids constructing impossible Cartesian-product
cases such as pairing an adapter stream result with a compiler that
never started.

### Formal stream/event model

GHC documents `-fdiagnostics-as-json` as emitting diagnostic messages to
`stderr` in JSON Lines form, with one diagnostic JSON object per line,
and documents the structure using a JSON Schema.
citeturn0search0turn0search1

Tadka-GHC must nevertheless distinguish the **GHC structured diagnostic
protocol** from the broader operating-system stderr byte stream.

The protocol model is:

``` text
Physical stderr bytes
        ↓
record framing
        ↓
Structured diagnostic records
        ↓
decode → validate → normalize
```

The conceptual event type is:

``` text
StreamEvent
  = DiagnosticRecord RawDiagnostic
  | NonDiagnosticStderr ByteString
  | MalformedRecord RecordError
  | EndOfStream
```

However, these constructors are not interchangeable. Their
classification must be determined by an explicit framing policy:

``` text
StructuredRecord
    = a line identified by the supported GHC diagnostic framing contract

NonDiagnosticStderr
    = bytes that are outside the structured diagnostic protocol

MalformedRecord
    = bytes that occupy a position required by the structured protocol
      but cannot be decoded as a valid record
```

Tadka-GHC must not classify an arbitrary non-JSON stderr line as a
malformed diagnostic merely because JSON decoding fails. Conversely, it
must not silently treat a malformed structured record as opaque stderr.

For each supported GHC/schema cell, the implementation shall document
and test the framing discriminator used to make this distinction.

The stream processor therefore computes:

``` text
consume : StreamEvent → StreamState → Either AdapterError StreamState
```

with explicit policies for:

-   record boundaries;
-   malformed records;
-   truncated final records;
-   non-diagnostic stderr;
-   diagnostic ordering;
-   flushing;
-   process termination;
-   bounded buffering.

A valid diagnostic received before a later malformed record remains
valid and must not be mutated retroactively.

A malformed record is not an implementation accident. The supported
protocol cell must specify whether it terminates the adapter session or
produces a controlled stream error. The default gold-standard policy is:

``` text
malformed structured record
    →
controlled adapter failure
```

rather than silently continuing with a semantically incomplete
diagnostic stream.

A process termination before a complete record is received is
represented as a truncated-record failure only if the incomplete bytes
were inside a record whose framing had already begun; otherwise it is
ordinary process termination.

### Transparent GHC invocation contract

The wrapper must preserve compilation semantics while intentionally
changing the diagnostic transport required for Tadka-GHC.

For an invocation:

``` text
I = (argv, environment, cwd, stdin, stdout, stderr)
```

the wrapped invocation `W(I)` must preserve the semantics of:

``` text
argv
environment
cwd
stdin
stdout
compiler termination
```

subject only to the explicitly required addition of the structured
diagnostic transport option and the documented routing of diagnostic
output.

The wrapper must not:

-   rewrite user compiler options;
-   change optimisation settings;
-   change warning policy;
-   change package visibility;
-   change source search paths;
-   execute diagnostic content;
-   reinterpret compiler arguments as shell commands.

The integration must use direct process invocation rather than shell
interpolation for externally supplied arguments.

### Parallel builds

Cabal may execute multiple GHC invocations concurrently.

Tadka-GHC therefore treats each compiler process as an independent
session:

``` text
GHC process A → session A → diagnostics A
GHC process B → session B → diagnostics B
GHC process C → session C → diagnostics C
```

No session may share mutable diagnostic state with another session.

Ordering is defined at the strongest level available:

1.  preserve order within one GHC process;
2.  preserve diagnostic order within each structured stream;
3.  do not invent a global ordering across concurrent compiler processes
    unless the build system supplies one.

Aggregation across processes must therefore be explicitly represented as
a build-level concern rather than inferred by timestamp or arrival
order.

# 29. Security

Tadka-GHC may process compiler output in CI, editor, build-server and
automated environments.

Diagnostic content must therefore be treated strictly as data.

The implementation must guarantee:

-   diagnostic text is never interpreted as shell syntax;
-   diagnostic paths are never executed;
-   diagnostic URLs are never followed automatically;
-   diagnostic content cannot select arbitrary filesystem operations;
-   untrusted diagnostic content cannot bypass resource bounds;
-   terminal-control data is handled according to Tadka's rendering
    safety policy.

Tadka-GHC cannot determine whether every diagnostic value is
confidential. It therefore treats compiler-supplied paths, URLs and
message text as untrusted data and does not claim to sanitize secrets
that GHC itself may emit.

### Resource-Bound Contract

Externally controlled quantities require explicit bounds or bounded
processing strategies:

-   JSON nesting depth;
-   diagnostic count;
-   individual message size;
-   number and size of hints;
-   related-diagnostic depth;
-   cause depth;
-   source size used for rendering;
-   source context lines;
-   buffered JSON bytes;
-   total retained diagnostic state.

The mechanism may be streaming, depth/size limits, rejection, or another
formally specified policy. It must never rely on accidental memory
exhaustion behaviour.

Resource exhaustion is a controlled adapter failure, not successful
partial translation. The adapter must never silently truncate
diagnostics, messages, relationships, or source context and then report
a semantically complete result.

------------------------------------------------------------------------

# 30. Performance

Performance is subordinate to correctness and architecture, but must be
engineered deliberately.

Benchmark:

-   JSON decoding;
-   normalization;
-   GHC-to-Tadka conversion;
-   large diagnostic streams;
-   large diagnostic messages;
-   many source spans;
-   memory consumption.

Prefer incremental processing where GHC's diagnostic stream permits it.

Do not load the entire build output into memory simply because that is
the easiest first implementation if a streaming design is required by
real workloads.

Do not add strictness annotations because they "feel safer." Profile
first, as required by the engineering standard.

------------------------------------------------------------------------

# 31. Known Haskell Space-Leak Risks

The implementation must explicitly guard against:

-   lazy accumulation of large diagnostic streams;
-   repeated `(++)` over large collections;
-   retaining a complete input buffer because a small fragment remains
    referenced;
-   unbounded lazy I/O;
-   unnecessary intermediate copies of large `Text`/`ByteString` values.

Large-input tests and benchmarks must accompany decisions about
accumulation and strictness.

------------------------------------------------------------------------

# 32. Testing Philosophy

Testing is architecture.

For Tadka-GHC, compatibility testing is also product verification. The
suite must prove the three P0 contracts rather than merely proving that
individual functions work.

A release is not compatible merely because it builds. The minimum
release gate is:

``` text
actual GHC
    ↓
structured diagnostics
    ↓
Tadka-GHC
    ↓
Tadka
    ↓
actual Tadka renderer
    ↓
verified expected semantics
```

This gate must run across the declared GHC/Tadka compatibility matrix.

The test pyramid should be:

``` text
                 End-to-end GHC
                       ▲
                 Integration
                       ▲
                    Golden
                       ▲
                  Properties
                       ▲
                     Unit
                       ▲
                    Types
```

Each level establishes a different class of guarantee.

------------------------------------------------------------------------

# 33. Unit Tests

Test pure components independently:

-   schema version decoding;
-   field decoding;
-   severity mapping;
-   code mapping;
-   source-location conversion;
-   message conversion;
-   hint conversion;
-   related-diagnostic mapping;
-   validation;
-   malformed input.

The core tests should not require spawning GHC.

------------------------------------------------------------------------

# 34. Property Tests

### Independent translation oracle

The property suite must include an implementation-independent semantic
oracle for the normalized domain. Properties must not merely compare a
function against a second function that shares the same normalization or
helper implementation.

For finite closed domains, exhaustive enumeration is preferred over random
generation. For infinite or combinatorial domains, Hedgehog properties and
shrinking are required.

At minimum, properties shall cover:

``` text
normalize preserves semantic interpretation
translation preserves every representable observation
span conversion preserves endpoint semantics
code identity is stable
order is preserved
related/cause structure is preserved
no label silently disappears
adaptation is deterministic
unsupported states return classified failure
```


Every important invariant should have a property test in the same change
that introduces it.

Examples:

``` text
valid normalized diagnostics always contain valid Tadka values
```

``` text
normalization is deterministic
```

``` text
conversion is deterministic
```

``` text
invalid coordinates never produce a misleading valid span
```

``` text
arbitrary malformed input cannot crash the decoder
```

The Haskell Engineering Standard explicitly requires stated invariants
to have corresponding property tests.

Property tests are subordinate to the semantic specification. They
provide systematic evidence over generated domains but do not substitute
for the correctness argument of a non-trivial algorithm.

For every correctness-critical transformation, the test suite should
identify:

``` text
specification
    ↓
invariant
    ↓
property
    ↓
fixture / golden evidence
    ↓
actual-GHC evidence
```

------------------------------------------------------------------------

# 35. Golden Tests

Golden tests should use real representative GHC diagnostics.

Required categories should include:

-   parser errors;
-   type errors;
-   warnings;
-   diagnostics with codes;
-   diagnostics with hints;
-   diagnostics with source locations;
-   multiple source locations;
-   multiple diagnostics;
-   Unicode source;
-   tabs;
-   multiline spans;
-   unavailable source;
-   degraded source;
-   JSON output.

The golden test should exercise:

``` text
GHC representation
      ↓
Tadka-GHC
      ↓
Tadka renderer
```

not merely snapshot a handcrafted Tadka value.

------------------------------------------------------------------------

# 36. End-to-End Tests

The highest-value test is:

``` text
actual source file
      ↓
actual GHC
      ↓
-fdiagnostics-as-json
      ↓
Tadka-GHC
      ↓
Tadka
      ↓
actual renderer
```

These tests must be run across the supported GHC matrix.

At least one end-to-end fixture should be deliberately designed for each
important GHC diagnostic category.

------------------------------------------------------------------------

# 37. Adversarial Testing

The decoder must be tested against:

-   truncated JSON;
-   malformed JSON;
-   missing required fields;
-   unexpected field types;
-   unknown fields;
-   unsupported schema versions;
-   invalid locations;
-   negative coordinates where impossible;
-   enormous numeric values;
-   empty messages;
-   very long messages;
-   unusual Unicode;
-   incomplete JSON-Lines records;
-   valid records followed by malformed records;
-   mixed structured and non-structured stderr;
-   large diagnostic streams;
-   resource-limit exhaustion attempts.

The test oracle is not merely "doesn't crash."

It is:

``` text
input
  ↓
specific valid result
or
specific controlled error
```

------------------------------------------------------------------------

# 38. Prior-Art Review

Before implementing schema parsing or compiler integration, inspect
comparable tooling and its known failure modes.

The Haskell Engineering Standard requires prior-art bug classes to be
identified and pre-empted rather than rediscovered.

For Tadka-GHC, the review should specifically look for:

-   schema compatibility failures;
-   location off-by-one errors;
-   malformed diagnostic handling;
-   streaming failures;
-   large-output memory problems;
-   Unicode/location conversion bugs;
-   compiler-version regressions.

Applicable findings become named regression tests.

------------------------------------------------------------------------

# 39. Compiler and CI Enforcement

The project must inherit the Haskell Engineering Standard's enforcement
model.

The baseline compiler flags include:

``` text
-Wall
-Wcompat
-Werror
-Wincomplete-uni-patterns
-Wincomplete-record-updates
-Wmissing-export-lists
-Wunused-imports
-Wunused-top-binds
-Wunused-local-binds
-Wunused-matches
-Wredundant-constraints
-Wpartial-fields
-Widentities
```

Formatting and linting must be enforced.

The exact toolchain may be:

``` text
ormolu / fourmolu
hlint
weeder
```

as appropriate for the repository.

No dead code or empty implementation stubs may enter the project.

------------------------------------------------------------------------

# 40. Build Reproducibility

Development and CI builds must be reproducible.

Dependency resolution should be pinned using the repository's chosen
Cabal locking mechanism.

The same commit should not silently acquire materially different
dependency graphs merely because it was built at a later date.

The GHC compatibility matrix must be explicit.

------------------------------------------------------------------------

# 41. PVP and Release Discipline

Tadka-GHC must follow the Haskell Package Versioning Policy.

Public API changes require deliberate versioning.

GHC compatibility changes must not be hidden as incidental
implementation changes.

A release should state:

``` text
Tadka-GHC version
Tadka version compatibility
GHC compatibility
diagnostic schema compatibility
```

If the package is eventually separated from Tadka's existing interop
component, the migration path must preserve the existing
`Tadka.Interop.GHC` functionality or provide a deliberate compatibility
story.

------------------------------------------------------------------------

# 42. Tadka Core Change Policy

A GHC requirement belongs in Tadka core only if the concept is genuinely
diagnostic-generic.

Use this test:

> **Would this capability still make sense if GHC did not exist?**

If no:

``` text
Tadka-GHC
```

If yes:

``` text
possibly Tadka core
```

subject to architectural review.

This rule prevents GHC-specific concepts from contaminating the
diagnostic engine.

------------------------------------------------------------------------

# 43. Perfect Match With Tadka

The integration must use Tadka's actual public abstractions rather than
recreate them.

The final conversion should construct ordinary Tadka values and allow
Tadka to handle:

-   source context;
-   labels;
-   spans;
-   severity;
-   codes;
-   help;
-   URLs;
-   related diagnostics;
-   causes;
-   renderer selection;
-   graphical layout;
-   narratable output;
-   JSON output;
-   configuration.

There must be exactly one semantic-to-rendered path per Tadka renderer:

``` text
Tadka semantic diagnostic
        ↓
Tadka renderer
```

Tadka may legitimately have multiple renderers (for example graphical,
narratable, and JSON). What Tadka-GHC must never implement is an
independent GHC-specific renderer for the same semantic diagnostic:

``` text
GHC diagnostic → GHC renderer
```

The adapter stops at the Tadka semantic representation.

------------------------------------------------------------------------

# 44. What Tadka-GHC Must Never Claim

Tadka-GHC must not imply that Tadka itself:

-   performs type checking;
-   understands GHC's type system;
-   determines whether code is semantically correct;
-   diagnoses the program independently;
-   generates compiler fixes;
-   knows the meaning of every GHC diagnostic beyond the structured
    information supplied;
-   replaces GHC.

The README and documentation must preserve the same discipline.

------------------------------------------------------------------------

# 45. Formal Proof Obligations

The following obligations are normative and are part of the Definition
of Done.

## 45.1 Decode soundness

For every successful decode:

``` text
decode(r) = Right(p)
    ⇒
p is a well-formed representation of r
```

No successful parser result may contain an unchecked value that violates
the declared parsed-domain invariants.

## 45.2 Validation soundness

For every successful validation:

``` text
validate(p) = Right(v)
    ⇒
v satisfies every invariant required by normalization.
```

## 45.3 Normalization preservation

``` text
∀v ∈ V:

    ⟦normalize(v)⟧N
        =
    ⟦v⟧V
```

Normalization is therefore a semantics-preserving change of
representation.

## 45.4 Translation faithfulness

``` text
translate(n) = Right(t)
    ⇒
FaithfulSemantics(n,t)
```

where:

``` text
FaithfulSemantics(n,t)
    ⇔
    embed(abstract(⟦n⟧N)) = ⟦t⟧T
```

## 45.5 Observation preservation

For every contract observation `q ∈ Q`:

``` text
translate(n) = Right(t)
∧ Representable(⟦n⟧N,q)

⇒

obsG(⟦n⟧N,q)
    =
obsT(⟦t⟧T,q)
```

This is the formal information-preservation obligation. It does not
require all GHC-internal semantics to have a Tadka representation.

## 45.6 Span preservation

For every supported source environment `S` and GHC span `g`, if:

``` text
resolve(S,g) = Right(t)
```

then:

``` text
regionGHC(S,g)
    =
regionTadka(S,t)
```

Equality is equality of semantic source regions under the coordinate
metric, endpoint convention, encoding assumptions, and source identity
declared for the applicable compatibility cell. This is the same
canonical span-preservation law defined in §11.3; §45.6 is its formal
proof obligation, not a second formulation of the conversion API.

## 45.7 Code identity

For supported GHC codes:

``` text
g1 ≠ g2
    ⇒
M(g1) ≠ M(g2)
```

and:

``` text
M[GhcCode] ∩ NativeTadkaCodeNamespace = ∅
```

at the semantic namespace level.

## 45.8 Determinism

All pure semantic transformations are deterministic for equal explicit
inputs and equal declared configuration.

## 45.9 No silent semantic third state

Every supported input must result in exactly one of:

``` text
successful faithful translation
explicit controlled failure
```

There is no permitted third outcome in which semantic information is
silently lost or reinterpreted.

## 45.10 Property tests versus proofs

Property tests provide executable evidence for these laws. They do not
replace the laws or their correctness arguments.

Where a law depends on an external GHC contract, the project must
combine:

``` text
formal law
+
actual GHC fixtures
+
property tests
+
end-to-end tests
```

# 46. Definition of Done

Tadka-GHC is ready for a serious release only when all of the following
are true:

### Architecture

-   [ ] Tadka core remains independent of Tadka-GHC.
-   [ ] One canonical normalized representation exists.
-   [ ] GHC-specific schema logic is isolated.
-   [ ] Pure core / effectful edge separation is maintained.
-   [ ] Module responsibilities are explicit.
-   [ ] Export lists define safe public boundaries.

### Formal semantics

-   [ ] Semantic domains and separate interpretation functions are
    defined.
-   [ ] Representability is defined as a partial semantic abstraction.
-   [ ] Normalization is proven semantics-preserving.
-   [ ] Translation faithfulness is stated as a semantic law.
-   [ ] Validation establishes all invariants required by normalization.
-   [ ] No silent semantic third state exists.
-   [ ] Source coordinate domains and endpoint semantics are normative.
-   [ ] Source-region preservation is verified under the declared
    coordinate metric.
-   [ ] Schema compatibility is defined semantically over declared
    record languages.
-   [ ] Code namespace injection and provenance are verified.
-   [ ] Process lifecycle, compiler termination, adapter failure, and
    integration outcomes are specified algebraically.

### Correctness

-   [ ] GHC 9.10.3, 9.12.4 and 9.14.1 are explicitly supported through
    `-fdiagnostics-as-json`.
-   [ ] Supported schemas are explicitly defined.
-   [ ] Unknown optional fields have a defined compatibility policy.
-   [ ] `FaithfulSemantics(n,t)` is defined independently of
    `translate`.
-   [ ] Observation preservation is formally defined over an explicit
    observation vocabulary.
-   [ ] Source coordinate metric, domains, and endpoint semantics are
    formally defined.
-   [ ] Source coordinates are verified.
-   [ ] Endpoint semantics are verified.
-   [ ] Severity mapping is deterministic.
-   [ ] Codes are faithfully represented.
-   [ ] Hints preserve their original meaning.
-   [ ] Related diagnostics are not confused with causes.
-   [ ] Multiple diagnostics are supported.
-   [ ] Parallel GHC invocations have defined isolation and ordering
    semantics.
-   [ ] GHC invocation transparency and exit-status semantics are
    verified.
-   [ ] No information is silently fabricated.

### Safety

-   [ ] No partial functions.
-   [ ] No unchecked external data becomes trusted domain data.
-   [ ] Malformed input produces controlled errors.
-   [ ] Resource limits have explicit failure semantics and cannot
    silently truncate semantic content.
-   [ ] Diagnostic content is never executed as commands.

### Verification

-   [ ] Unit tests pass.
-   [ ] Property tests pass.
-   [ ] Golden tests pass.
-   [ ] Adversarial tests pass.
-   [ ] End-to-end tests use actual GHC.
-   [ ] Tests run against every supported GHC version.
-   [ ] Prior-art failure modes have been reviewed.
-   [ ] Relevant known bug classes have regression tests.
-   [ ] Performance-sensitive paths have benchmarks.

### Engineering

-   [ ] Compiler warnings are clean.
-   [ ] Linting is clean.
-   [ ] Formatting is enforced.
-   [ ] No dead code exists.
-   [ ] Dependencies are justified.
-   [ ] Builds are reproducible.
-   [ ] Any deviation from the engineering standard has an ADR.

------------------------------------------------------------------------

# 47. Long-Term Ecosystem Vision

Tadka-GHC should establish the pattern for the Tadka ecosystem:

``` text
       GHC ───────────────┐
       Megaparsec ────────┼──→ Tadka adapters ──→ Tadka Diagnostic
       Attoparsec ────────┘                              │
                                                        ▼
                                               ┌────────┼────────┐
                                               ▼        ▼        ▼
                                           graphical narratable  JSON
```

The ecosystem principle is:

> **Automatic where the producer already exposes structured diagnostic
> information; explicit where semantic information must be supplied by
> the producer.**

GHC is the strongest case for automatic integration because GHC already
owns the complete semantic context of its diagnostics.

------------------------------------------------------------------------

# 48. Final Architectural Principle

The project can be reduced to one rule:

> **Do not make Tadka understand GHC. Make Tadka-GHC understand GHC and
> give Tadka exactly the diagnostic information Tadka already knows how
> to represent and render.**

That gives the system a clean division of responsibility:

``` text
GHC
  = semantic authority

Tadka-GHC
  = translation authority

Tadka
  = diagnostic representation + presentation authority
```

And the desired user experience becomes:

``` text
                 Haskell developer
                        │
                        ▼
                      Build
                        │
                        ▼
                       GHC
                        │
                        ▼
                  Tadka-GHC
                        │
                        ▼
                      Tadka
                        │
              ┌─────────┼─────────┐
              ▼         ▼         ▼
          graphical  narratable  JSON
```

**Small core. Thin adapter. Strong types. Total functions. Explicit
failure. Faithful translation. Real GHC verification. No invented
semantics.**

That is the engineering standard and the vision for Tadka-GHC.

------------------------------------------------------------------------

# Appendix A. Formal Semantic Contract Summary

This appendix provides the compact mathematical contract used by the
normative sections above.

``` text
V  = validated GHC representations
N  = normalized GHC representations
D_G = GHC semantic domain
D_T = Tadka semantic domain
C  = Tadka-observable semantic domain
T  = Tadka Diagnostic
```

Interpretation:

``` text
⟦·⟧V : V → D_G
⟦·⟧N : N → D_G
⟦·⟧T : T → D_T
```

Normalization:

``` text
normalize : V → N

∀v ∈ V:
    ⟦normalize(v)⟧N = ⟦v⟧V
```

Representability abstraction:

``` text
abstract : D_G ⇀ C
embed    : C → D_T
```

Translation:

``` text
translate : N → Either TranslationError T
```

Faithfulness:

``` text
FaithfulSemantics(n,t)
    ⇔
    embed(abstract(⟦n⟧N)) = ⟦t⟧T
```

Translation obligation:

``` text
translate(n) = Right(t)
    ⇒
FaithfulSemantics(n,t)
```

Observation preservation:

``` text
obsG : D_G × Q ⇀ Value
obsT : D_T × Q ⇀ Value

translate(n) = Right(t)
∧ Representable(⟦n⟧N,q)

⇒

obsG(⟦n⟧N,q)
=
obsT(⟦t⟧T,q)
```

Supported domain:

``` text
N_supported ⊆ N
```

Every supported input has exactly one outcome:

``` text
Right(t)
```

or:

``` text
Left(e)
```

where `e` is an explicitly classified error permitted by the
compatibility, representability, resource, stream, process, or invariant
policy.

There is no silent semantic third state.

------------------------------------------------------------------------

# Appendix B. External Protocol Premises

The following external facts are protocol premises rather than Tadka-GHC
implementation claims:

1.  GHC documents `-fdiagnostics-as-json` as emitting standardized
    diagnostic JSON directly to `stderr`.
2.  GHC documents the format as JSON Lines, with one diagnostic JSON
    object per line.
3.  GHC documents the structure using a JSON Schema.
4.  GHC documents `-ddump-json` as deprecated in favour of
    `-fdiagnostics-as-json`.
5.  GHC's diagnostic code infrastructure uses namespaced numeric
    diagnostic identifiers and explicitly treats code uniqueness as a
    maintained invariant.

For the currently declared compatibility cells, the release artifacts
identify the JSON schema generation used by each compiler. GHC 9.10.x
documents schema 1.0, while the 9.14.1 compiler source identifies schema
1.1; the exact 9.12.4 artifact must likewise be pinned in the
repository's compatibility fixtures rather than inferred from compiler
version alone. The compatibility matrix therefore records both compiler
version and schema version, even when multiple compiler releases share
the same schema generation. citeturn0search7turn1search0

These premises must be verified against the exact GHC release
documentation and schema artifacts used by each compatibility cell
during implementation.

Primary references:

-   GHC User Guide --- Using GHC:
    https://ghc.gitlab.haskell.org/ghc/doc/users_guide/using.html
-   GHC User Guide --- Debugging the compiler:
    https://ghc.gitlab.haskell.org/ghc/doc/users_guide/debugging.html
-   GHC diagnostic code API, one reference per compatibility-matrix cell
    (§3.2), not an unreleased development snapshot:
    -   GHC 9.10.3:
        https://hackage-content.haskell.org/package/ghc-9.10.3/docs/GHC-Types-Error-Codes.html
    -   GHC 9.12.4:
        https://hackage-content.haskell.org/package/ghc-9.12.4/docs/GHC-Types-Error-Codes.html
    -   GHC 9.14.1:
        https://hackage-content.haskell.org/package/ghc-9.14.1/docs/GHC-Types-Error-Codes.html
-   GHC diagnostic API, one reference per compatibility-matrix cell:
    -   GHC 9.10.3:
        https://hackage-content.haskell.org/package/ghc-9.10.3/docs/GHC-Types-Error.html
    -   GHC 9.12.4:
        https://hackage-content.haskell.org/package/ghc-9.12.4/docs/GHC-Types-Error.html
    -   GHC 9.14.1:
        https://hackage-content.haskell.org/package/ghc-9.14.1/docs/GHC-Types-Error.html

Each link must point at the exact pinned release for its matrix cell,
never at an `-inplace`, snapshot, or otherwise unreleased/unstable
build; when a new GHC release is added to the compatibility matrix, its
corresponding reference must be added here at the same time. These
references are not substitutes for pinning the actual schema and
compiler fixtures used in CI.

------------------------------------------------------------------------

# Appendix C. Version 7.0 Corrections

Version 7.0 incorporated the formal review corrections listed below.
Version 9.0 supersedes those formulations where this document makes
further corrections.

The principal Version 7.0 corrections were:

1.  The semantic abstraction is now a partial abstraction rather than an
    overloaded mathematical projection.
2.  GHC and Tadka interpretation functions have separate domains and
    names.
3.  `FaithfulSemantics` is independent of the implementation function
    `translate`.
4.  Information preservation is expressed using explicit semantic
    observations rather than treating semantic values as sets of
    properties.
5.  Schema compatibility is defined over declared record languages and
    cannot be satisfied vacuously by an empty intersection.
6.  Schema extension compatibility is defined by a semantics-preserving
    projection.
7.  Supported diagnostics are explicitly represented by `N_supported`.
8.  Totality is explicitly distinguished from guaranteed success.
9.  Compiler process lifecycle is separated from compiler termination
    and adapter failure.
10. Structured stderr framing is made an explicit protocol contract
    rather than an implicit JSON-decoding heuristic.
11. Source-content acquisition is separated from semantic source
    locations.
12. Source coordinate metrics and half-open span semantics are made
    normative.
13. Diagnostic reason, diagnostic severity, and compiler termination are
    explicitly distinct.
14. GHC diagnostic code identity is modeled as producer namespace plus
    producer code.
15. Resource exhaustion, representability failure, compatibility
    failure, and internal invariant violations are distinguished.
16. The rendering requirement is clarified to permit Tadka's multiple
    native renderers while prohibiting a GHC-specific rendering path.
17. The ecosystem dependency diagram now reflects the actual one-way
    adapter architecture.
18. The mathematical correctness section is now a correctness-assurance
    hierarchy rather than an assertion that tests constitute proofs.

These Version 7.0 changes remain normative except where Version 8.0
makes a more precise correction. The current document is governed by
Version 8.0.

------------------------------------------------------------------------

# Appendix D. Version 8.0 Corrections (Historical)

Version 8.0 is a precision-correction release. It does not redesign the
architecture; it removes notation, typing, duplication, and
specification ambiguities identified in formal review.

1.  **Span law typing**
    -   `resolve` has one normative type:
        `SourceEnvironment → GhcSpan → Either LocationError TadkaSpan`.
    -   Every span-preservation law is stated only for
        `resolve(S,g) = Right(t)`.
    -   The ill-typed direct-`Either` span formulation is removed.
    -   No second span-translation name is introduced for the same
        operation.
2.  **Translation-error reconciliation**
    -   The formal translation error domain is `TranslationError`.
    -   `translate : N → Either TranslationError T`.
    -   `AdapterError` is the pipeline-level error domain.
    -   `TranslationError` enters `AdapterError` only through
        `TranslationFailure TranslationError`.
    -   Decode, validation, stream, process, resource, and invariant
        failures are therefore not misrepresented as translation
        failures.
3.  **Schema-compatibility deduplication**
    -   The repeated schema-state algebra and optional-field policy are
        reduced to one canonical statement.
4.  **Library/integration deduplication**
    -   The duplicated "Library versus integration executable"
        subsection is reduced to one authoritative occurrence.
5.  **Formal-obligation numbering**
    -   "Property tests versus proofs" is now §45.10.
6.  **Version metadata**
    -   The document header is now Version 8.0.
    -   Version 7.0 is retained as historical correction context rather
        than presented as the current document version.
7.  **Endpoint convention**
    -   No span endpoint convention is assumed globally.
    -   Half-open notation is permitted only when established by the
        exact supported GHC/schema coordinate contract.
    -   Coordinate semantics are declared per compatibility cell and per
        axis where necessary.
8.  **Architecture completeness**
    -   The normative Tadka-GHC architecture now explicitly contains
        `decode → validate → normalize → translate → Tadka Diagnostic`.
    -   `translate` remains distinct from normalization.
9.  **Code-image notation**
    -   `M[GhcCode]` is defined as the image of the mapping `M`,
        removing the function-application/set-intersection ambiguity.
10. **Order-symbol separation**
    -   `≼schema` denotes schema extension.
    -   `≼cap` denotes capability inclusion.
    -   The two relations operate on different domains and are
        intentionally distinct.
11. **Current-version rule**
    -   Where Version 7.0 and Version 8.0 formulations differ, Version
        8.0 is authoritative.

------------------------------------------------------------------------

# Appendix E. Version 9.0 Corrections

Version 9.0 is a repository-grounded correction release. It incorporates
the audit of the Tadka repository and removes design assumptions that were
not justified by the implementation.

1. **Tadka API is now concrete.** The specification records the actual
   public `Diagnostic`, `Context`, `Span`, source, severity, code, related,
   cause, renderer, and configuration abstractions instead of describing
   them as placeholders to be inspected later.

2. **Existing GHC span interop is retained.** `tadka:interop-ghc` remains a
   focused `SrcSpan → Span` adapter. Tadka-GHC is a higher semantic layer,
   not a replacement implementation.

3. **One semantic path is mandatory.** All structured diagnostic inputs
   converge on `decode → validate → normalize → translate`. No renderer or
   process path may interpret GHC diagnostics independently.

4. **Concrete type-state boundaries are normative.** The specification now
   requires named pure boundaries for raw input, validated diagnostics,
   normalized diagnostics, source environments, code identity, locations,
   and classified adapter failures.

5. **Exact external schemas are implementation gates.** The specification
   no longer allows schema details to remain implied by compiler version.
   Every compatibility cell must pin the actual schema artifact.

6. **The 9.12.4 schema must be pinned independently.** It may not be
   inferred from the 9.10.x or 9.14.x schema generation.

7. **Tadka and Tadka-GHC compiler matrices are distinct.** Tadka's broader
   GHC build matrix does not silently expand Tadka-GHC's structured-diagnostic
   compatibility matrix.

8. **Source acquisition is explicitly outside the pure semantic core.**
   The translator receives a `SourceEnvironment` and performs no filesystem
   or process I/O.

9. **Code identity is a pre-implementation gate.** GHC's namespace/number
   identity must be shown to fit Tadka's `DiagnosticCode` semantics using
   actual supported compiler fixtures before the mapping is frozen.

10. **Totality is invariant-driven.** The specification distinguishes
    externally reachable partial semantic operations from controlled test
    helpers and justified internal invariants.

11. **Repository history is treated as a correctness constraint.** Prior
    fixes for label loss, related/cause loss, GHC span misattribution, and
    span overflow are explicitly protected by the adapter contract and test
    matrix.

12. **Implementation readiness is gated.** Exact Tadka baseline, exact GHC
    schemas, real compiler fixtures, code identity, source acquisition,
    representability policy, and worked end-to-end examples must be closed
    before architecture freeze.
