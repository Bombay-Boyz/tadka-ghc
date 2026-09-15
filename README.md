# Tadka-GHC

**Tadka-GHC** is a Haskell adapter that translates GHC's structured diagnostics into [Tadka](https://github.com/Bombay-Boyz/tadka)'s diagnostic model.

The project is designed around a strict separation between:

1. decoding the GHC diagnostic protocol,
2. validating the decoded representation,
3. normalizing GHC semantics,
4. acquiring and validating source context,
5. translating the normalized representation into Tadka,
6. and integrating with GHC processes and diagnostic streams.

The semantic core is intended to remain pure and total. Process execution, streaming, and other environmental concerns are kept outside that core.

## Status

The repository is currently in **Phase 0 — Repository and Build Foundation**.

At this stage:

* the Cabal package is established;
* the package builds with GHC 9.14.1;
* the test-suite boundary is established;
* repository and package metadata are validated;
* semantic implementation has not yet begun.

The implementation follows the project's Vision and Implementation Specification. Semantic APIs are introduced only after the corresponding protocol and compatibility contracts have been established.

## Design principles

Tadka-GHC follows these engineering principles:

* **Totality:** production semantic functions must not use partial operations.
* **Strong types:** types should encode meaningful invariants and closed domains.
* **Pure semantics:** decoding, validation, normalization, and translation are deterministic transformations.
* **Explicit errors:** failures are represented by domain-specific error types rather than hidden exceptions.
* **No accidental information loss:** every translation decision must be explicit and testable.
* **Independent verification:** important semantic laws are tested against independently constructed expectations.
* **Real compiler evidence:** protocol behaviour is verified against actual supported GHC versions.
* **Adversarial testing:** malformed, boundary, contradictory, and unusually large inputs are first-class test cases.
* **Small semantic core:** process and operating-system integration must not contaminate the pure translation layer.

## Architecture

The intended semantic pipeline is:

```text
GHC diagnostic JSON Lines
        |
        v
     Decode
        |
        v
    Validate
        |
        v
    Normalize
        |
        v
     Source
        |
        v
    Translate
        |
        v
      Tadka
```

Process and stream integration surround this pure semantic pipeline rather than becoming part of it.

## Development

The project uses:

* GHC
* Cabal
* Tadka
* Hedgehog for property-based testing
* golden and fixture-based testing
* actual-GHC integration testing

Build the project with:

```bash
cabal build
```

Run the test suite with:

```bash
cabal test
```

Validate package metadata with:

```bash
cabal check
```

Check repository whitespace and patch errors with:

```bash
git diff --check
```

## Compatibility

The initial structured-diagnostic implementation targets:

* GHC 9.10.3
* GHC 9.12.4
* GHC 9.14.1

Each compiler version must be validated against its exact structured-diagnostic protocol/schema rather than inferred from another compiler release.

Compatibility claims are made only after the corresponding compiler and protocol evidence has been tested.

## Repository documentation

The repository's authoritative engineering documents are maintained alongside the implementation:

* `tadka-ghc-vision-v9.md` — project vision and architectural contract
* `tadka-ghc-implementation-spec-v1.md` — implementation specification
* `docs/DEVELOPMENT.md` — development and engineering rules
* `docs/PHASE-0.md` — Phase 0 completion criteria

## License

Tadka-GHC is distributed under the **Mozilla Public License 2.0 (MPL-2.0)**.
