%{

  open Lexing
  open Kawa

%}

%token <int> INT
%token <string> IDENT
%token <bool> BOOL
%token MAIN
%token LPAR RPAR BEGIN END SEMI
%token PRINT
%token TRUE FALSE
%token VAR ATTR METHOD CLASS NEW THIS
%token IF ELSE WHILE
%token VOID
%token RETURN
%token EOF
%left PlUS MINUS
%left MUL DIV REM

%start program
%type <Kawa.program> program
%type <Uop> uop
%type <Bop> bop

%%

program:
| MAIN BEGIN main=list(instruction) END EOF
    { {classes=[]; globals=[]; main} }
;

instruction:
| PRINT LPAR e=expression RPAR SEMI { Print(e) }
;

expression:
| n=INT { n }
| TRUE = bool {true}
| FALSE = bool {false}
| THIS {this}
| mem {mem}
| u = uop e=expr {e %prec u}
| e1=expr op = bop e2=expr {bop(op,e1,e2)}
| LPAREN e = expr RPAREN { e }
| NEW IDENT { /* New object */ }
| NEW IDENT LPAREN opt_exprs RPAREN { /* New object with parameters */ }
| expr DOT IDENT LPAREN opt_exprs RPAREN { /* Method call */ }
;

uop:
| MINUS { - }
| NOT   { ! }
;

bop:
| PLUS { + }
| MINUS { - }
| MUL{ * }
| DIV{ / }
| EQUAL{ == }
| NEQ { != }
| LT { < }
| LEQ { > }
| AND { && }
| OR { || }
| REM{%}
;

