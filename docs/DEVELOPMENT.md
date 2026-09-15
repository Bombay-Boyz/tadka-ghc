# Development

## Engineering standard

The implementation is required to satisfy the Tadka-GHC specification.

In particular:

- Tadka's existing names and abstractions are authoritative.
- Production functions are total.
- Invalid states are excluded through types and smart constructors where
  those mechanisms establish meaningful invariants.
- ADTs and GADTs are preferred where they express closed domains or
  indexed invariants.
- Error domains remain separated.
- Semantic transformations remain pure.
- Tests include exhaustive finite-domain verification, property testing,
  golden tests, adversarial cases, regression cases, and real-GHC
  integration tests where applicable.

No semantic contract is inferred merely for implementation convenience.
