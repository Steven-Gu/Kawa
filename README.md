# Kawa — A Minimal Java-like Language (OCaml)

Kawa is a small, Java-inspired language implemented in **OCaml** as part of a compilation project.  
It features a lexer, parser, type checker, and interpreter.

## Features
- **Lexer & Parser**: built with `ocamllex` and `menhir`
- **Static type checker**: checks classes, fields, methods, and subtyping
- **Interpreter**: executes classes with inheritance, method calls, and constructors
- **Environments**:
  - Global environment for classes and fields
  - Temporary (call-scoped) environment for method execution
- **Subtyping**: verified via `is_subtype` during method calls

## Build & Run
```sh
opam install dune menhir
dune build
dune exec ./kawa.exe -- tests/example.kawa
```
## Authors
- Tianwen Gu
- Hongfei Zhang
