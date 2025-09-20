# Kawa — A Minimal Java-like Language (OCaml)

Kawa is a small, Java-inspired language implemented in OCaml.  
It includes:
- **Lexer** (`kawalexer.mll`) and **parser** (`kawaparser.mly`) built with ocamllex & menhir
- **Static type checker** (`typechecker.ml`) with simple class/subtyping checks
- **Interpreter** (`interpreter.ml`) supporting classes, fields, methods, and inheritance
- **Tests** (`tests/`)

## Features
- Classes, fields, and methods
- Method calls with type checking (incl. basic subtyping)
- Constructors (return constructed object)
- Separation of **global** vs **temporary** (call-scoped) environments

## Notable implementation points
- Resolved a **shift/reduce** conflict by simplifying `method_def` (no special `return` token in the rule).
- Explicit handling of `this` via a global reference.
- Subtyping handled with `is_subtype` during method call checking.

## Build & Run
```sh
opam install dune menhir ocamlfind   # if needed
dune build
dune exec ./kawa.exe -- < program.kawa
