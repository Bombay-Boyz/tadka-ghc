# Phase 1 — Tadka Dependency and Compatibility Baseline

## Objective

Establish the exact Tadka source dependency used by Tadka-GHC and verify
the public semantic and GHC interop boundaries against that source.

## Pinned Tadka source

Repository:

    https://github.com/Bombay-Boyz/tadka.git

Commit:

    bc750f8694df8424ed0a8c985bd7fa1754dc11ad

Package version:

    2.0.0.0

## Required boundary

Tadka-GHC may depend on:

- the public `Tadka` API;
- the existing `tadka:interop-ghc` adapter where appropriate.

Tadka-GHC must not duplicate or replace Tadka's existing `SrcSpan -> Span`
conversion merely for convenience.

## Exit conditions

- Cabal resolves the pinned Tadka commit.
- `tadka` version `2.0.0.0` is used.
- `Tadka` imports successfully.
- `Tadka.Interop.GHC` imports successfully.
- The existing `spanFromSrcSpan` boundary type-checks from Tadka-GHC.
- `cabal check` is clean.
- `cabal build` is clean.
- `cabal test` is clean.
- No semantic adapter implementation has been introduced.
