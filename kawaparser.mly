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
%token LBRACE RBRACE
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
opt_var_decls:
| /* Empty */
  { [] }
| var_decls
  { var_decls }
;

var_decls:
| var_decl
  { [$1] }
| var_decl var_decls
  { $1 :: $2 }
;

var_decl:
| VAR typ=typ IDENT SEMI
  { ($3, typ) }
;

typ:
| INT
  { TInt }
| BOOL
  { TBool }
| IDENT
  { TClass($1) }
| VOID
  { TVoid }

instruction:
| PRINT LPAR e=expression RPAR SEMI { Print(e) }
| mem = mem EQ e = expr SEMI { Assign(mem, e) }
| IF LPAR cond = expr RPAR LBRACE true_branch = list(instr) RBRACE
      ELSE LBRACE false_branch = list(instr) RBRACE
    { If(cond, true_branch, false_branch) }
| WHILE LPAR cond = expr RPAR LBRACE body = list(instr) RBRACE
    { While(cond, body) }
| RETURN e = expr SEMI { Return(e) }
| e = expr SEMI { Expr(e) }
;

expression:
| n=INT { n }
| TRUE {Bool(true)}
| FALSE {Bool(false)}
| THIS {This}
| mem {mem}
| u = uop e=expr {e %prec u}
| e1=expr op = bop e2=expr {bop(op,e1,e2)}
| LPAREN e = expr RPAREN { e }
| NEW IDENT
  { New($2) }
| NEW IDENT LPAR exprs=opt_exprs RPAR
  { NewCstr($2, exprs) }
| expr=expr DOT IDENT
  { MethCall(expr, $3, []) }
| expr=expr DOT IDENT LPAR exprs=opt_exprs RPAR
  { MethCall(expr, $3, exprs) }
;

opt_exprs:
| /* Empty */
  { [] }
| exprs
  { exprs }
;

exprs:
| expr=expr
  { [expr] }
| expr=expr COMMA exprs
  { expr :: exprs }
;

uop:
| MINUS { - }
| NOT   { ! }
;

bop:
| PLUS { Plus }
| MINUS { Minus }
| MUL{ Mul }
| DIV{ Div }
| EQUAL{ Eq }
| NEQ { Neq }
| LT { Lt }
| LEQ { Le }
| AND { And }
| OR { Or }
| GT { Gt }
| GEQ { Geq }
| REM{ Rem }
;

class_def:
| CLASS IDENT class_body
  { { class_name = $2; attributes = $3.attrs; methods = $3.methods; parent = None } }
| CLASS IDENT EXTENDS IDENT class_body
  { { class_name = $2; attributes = $4.attrs; methods = $4.methods; parent = Some $3 } }
;

class_body:
| BEGIN attr_decls=opt_attr_decls method_defs=opt_method_defs END
  { { attrs = attr_decls; methods = method_defs } }
;

opt_attr_decls:
| /* Empty */
  { [] }
| attr_decls
  { attr_decls }
;

attr_decls:
| attr_decl
  { [$1] }
| attr_decl attr_decls
  { $1 :: $2 }
;

attr_decl:
| ATTR typ=typ IDENT SEMI
  { ($3, typ) }
;

opt_method_defs:
| /* Empty */
  { [] }
| method_defs
  { method_defs }
;

method_defs:
| method_def
  { [$1] }
| method_def method_defs
  { $1 :: $2 }
;

method_def:
| METHOD typ=typ IDENT LPAR params_opt=opt_params RPAR BEGIN var_decls=opt_var_decls seq=seq RETURN expr=expr SEMI END
  { { method_name = $3; return = typ; params = params_opt; locals = var_decls; code = seq @ [Return(expr)] } }
;

opt_params:
| /* Empty */
  { [] }
| params
  { params }
;

params:
| typ=typ IDENT
  { [($2, typ)] }
| typ=typ IDENT COMMA params
  { ($2, typ) :: $4 }
;
