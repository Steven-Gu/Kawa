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
| n=INT { Int(n) }
| TRUE {Boolean(true)}
| FALSE {Boolean(false)}
| THIS {Expression(this)}
| mem { }
| uop e=expr {  }
| e1=expr bop e2=expr {  }
| LPAREN expr RPAREN {  }
| NEW IDENT { /* New object */ }
| NEW IDENT LPAREN opt_exprs RPAREN { /* New object with parameters */ }
| expr DOT IDENT LPAREN opt_exprs RPAREN { /* Method call */ }
;

uop:
| MINUS { }
| NOT   { }
;

bop:
| PLUS { }
| MINUS { }
| MUL{ }
| DIV{ }
| EQUAL{ }
| NEQ {}
| LT {}
| LEQ {}
| AND {}
| OR {}
