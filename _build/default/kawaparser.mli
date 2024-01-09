
(* The type of tokens. *)

type token = 
  | WHILE
  | VOID
  | VAR
  | TRUE
  | THIS
  | SEMI
  | RPAR
  | RETURN
  | REM
  | PRINT
  | PLUS
  | OR
  | OPP
  | NOT
  | NEW
  | NEQ
  | MUL
  | MINUS
  | METHOD
  | MAIN
  | LT
  | LPAR
  | LEQ
  | INT_TYPE
  | INT of (int)
  | IF
  | IDENT of (string)
  | GT
  | GEQ
  | FALSE
  | EXTENDS
  | EQUAL
  | EOF
  | END
  | ELSE
  | DOT
  | DIV
  | COMMA
  | CLASS
  | BOOL_TYPE
  | BEGIN
  | ATTR
  | ASSIGN
  | AND

(* This exception is raised by the monolithic API functions. *)

exception Error

(* The monolithic API. *)

val program: (Lexing.lexbuf -> token) -> Lexing.lexbuf -> (Kawa.program)