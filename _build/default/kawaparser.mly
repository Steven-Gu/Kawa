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
%token VAR ATTR METHOD CLASS NEW THIS EXTENDS
%token IF ELSE WHILE
%token VOID
%token RETURN
%token EOF
%token LBRACE RBRACE
%token ASSIGN PLUS MINUS MUL DIV REM EQUAL NEQ LT LEQ GT GEQ
%token OR AND DOT COMMA NOT
%left PLUS MINUS
%left MUL DIV REM

%start program
%type <Kawa.program> program
%type <Kawa.unop> uop
%type <Kawa.binop> bop
%type <Kawa.expr> expression
%type <Kawa.typ> typ
%type <Kawa.mem_access> mem
%type <Kawa.instr> instruction
%type <Kawa.seq> seq
%type <Kawa.class_def> class_def
%type <Kawa.expr list> exprs
//%type <Kawa.expr list> opt_exprs

%type <(string * Kawa.typ)> attr_decl
%type <(string * Kawa.typ) list> attr_decls
%type <Kawa.class_def list> classes
//%type <((string * Kawa.typ) list) * (Kawa.method_def list)> class_body
%type <Kawa.method_def> method_def
%type <Kawa.method_def list> method_defs
//%type <(string * Kawa.typ) list option> opt_attr_decls
//%type <Kawa.class_def list option> opt_classes
//%type <Kawa.method_def list option> opt_method_defs
//%type <(string * Kawa.typ) list option> opt_params
//%type <(string * Kawa.typ) list option> opt_var_decls
%type <(string * Kawa.typ) list> params
%type <(string * Kawa.typ)> var_decl
%type <(string * Kawa.typ) list> var_decls
%%


program:
| MAIN BEGIN globals = var_decls classes = classes main=seq END EOF
    { {classes=classes; globals=globals; main} }
;

var_decl:
| VAR typ=typ IDENT SEMI
  { ($3, typ) }
;

var_decls:
| var_decl
  { [$1] }
| var_decl var_decls
  { $1 :: $2 }
;

(*opt_var_decls:
| /* Empty */
  { [] }
| var_decls
  { var_decls }
;*)

typ:
| INT
  { TInt }
| BOOL
  { TBool }
| IDENT
  { TClass($1) }
| VOID
  { TVoid }
;

mem:
| IDENT
  { Var($1) }
| expression DOT IDENT
  { Field($1, $3) }
;


(*opt_classes:
| /* Empty */
  { [] }
| classes
  { classes }
;*)

classes:
| class_def
  { [$1] }
| class_def classes
  { $1 :: $2 }
;

instruction:
| PRINT LPAR e=expression RPAR SEMI { Print(e) }
| mem = mem ASSIGN e = expression SEMI { Set(mem, e) }
| IF LPAR cond = expression RPAR LBRACE true_branch = seq RBRACE
      ELSE LBRACE false_branch = seq RBRACE
    { If(cond, true_branch, false_branch) }
| WHILE LPAR cond = expression RPAR LBRACE body = seq RBRACE
    { While(cond, body) }
| RETURN e = expression SEMI { Return(e) }
| e = expression SEMI { Expr(e) }
;

expression:
| n=INT { Int(n) }
| TRUE {Bool(true)}
| FALSE {Bool(false)}
| THIS {This}
| m = mem {Get(m)}
| u = uop e=expression {Unop(u,e)}
| e1=expression op = bop e2=expression {Binop(op,e1,e2)}
| LPAR e = expression RPAR { e }
| NEW IDENT
  { New($2) }
| NEW IDENT LPAR exprs=exprs RPAR
  { NewCstr($2, exprs) }
| expr=expression DOT IDENT
  { MethCall(expr, $3, []) }
| expr=expression DOT IDENT LPAR exprs=exprs RPAR
  { MethCall(expr, $3, exprs) }
;

(*opt_exprs:
| /* Empty */
  { [] }
| exprs
  { exprs }
;*)

exprs:
| expr=expression
  { [expr] }
| expr=expression COMMA exprs=exprs
  { expr :: exprs }
;

uop:
| MINUS { Opp }
| NOT   { Not }
;

bop:
| PLUS { Add }
| MINUS { Sub }
| MUL{ Mul }
| DIV{ Div }
| EQUAL{ Eq }
| NEQ { Neq }
| LT { Lt }
| LEQ { Le }
| AND { And }
| OR { Or }
| GT { Gt }
| GEQ { Ge }
| REM{ Rem }
;

(*class_body:
| BEGIN attr_decls=attr_decls method_defs=method_defs END
  { { attrs = attr_decls; methods = method_defs } }
;

class_def:
| CLASS IDENT class_body
  { { class_name = $2; attributes = $3.attrs; methods = $3.methods; parent = None } }
| CLASS IDENT EXTENDS IDENT class_body
  { { class_name = $2; attributes = $5.attrs; methods = $5.methods; parent = Some $4 } }
;*)


(*opt_attr_decls:
| /* Empty */
  { [] }
| attr_decls
  { attr_decls }
;*)

class_def:
| CLASS IDENT BEGIN attr_decls=attr_decls method_defs=method_defs END
  { { class_name = $2; attributes = attr_decls; methods = method_defs; parent = None } }
| CLASS IDENT EXTENDS IDENT BEGIN attr_decls=attr_decls method_defs=method_defs END
  { { class_name = $2; attributes = attr_decls; methods = method_defs; parent = Some $4 } }
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

(*)opt_method_defs:
| /* Empty */
  { [] }
| method_defs
  { method_defs }
;*)

method_defs:
| method_def
  { [$1] }
| method_def method_defs
  { $1 :: $2 }
;

method_def:
| METHOD typ=typ IDENT LPAR params_opt=params RPAR BEGIN var_decls=var_decls seq=seq RETURN expr=expression SEMI END
  { { method_name = $3; return = typ; params = params_opt; locals = var_decls; code = seq @ [Return(expr)] } }
;

seq:
| /* Empty */
  { [] }
| instruction SEMI seq
  { $1 :: $3 }
;


params:
| typ=typ IDENT
  { [($2, typ)] }
| typ=typ IDENT COMMA params
  { ($2, typ) :: $4 }
;
