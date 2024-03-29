%{

  open Lexing
  open Kawa

%}

%token <int> INT
%token <string> IDENT
%token INT_TYPE BOOL_TYPE
%token MAIN
%token LPAR RPAR BEGIN END SEMI
%token PRINT
%token TRUE FALSE
%token VAR ATTR METHOD CLASS NEW THIS EXTENDS DOT
%token IF ELSE WHILE
%token VOID
%token RETURN
%token EOF
%token ASSIGN EQUAL PLUS MINUS MUL DIV REM NEQ LT LEQ GT GEQ
%token OR AND COMMA NOT OPP


%nonassoc LT LEQ GT GEQ EQUAL NEQ
%left OR
%left AND
%left PLUS MINUS
%left MUL DIV REM
%left NOT OPP
%left DOT


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

%type <(string * Kawa.typ)> attr_decl
%type <(string * Kawa.typ) list> attr_decls
%type <Kawa.class_def list> classes
%type <Kawa.method_def> method_def
%type <Kawa.method_def list> method_defs
%type <(string * Kawa.typ) list> params
%type <(string * Kawa.typ)> var_decl
%type <(string * Kawa.typ) list> var_decls
%%


program:
|globals = var_decls classes = classes MAIN BEGIN main=seq END EOF
    { {classes=classes; globals=globals; main} }
;

var_decl:
| VAR typ=typ IDENT SEMI
  { ($3, typ) }
;

var_decls:
| /* Empty */
  { [] }
| var_decl var_decls
  { $1 :: $2 }
;

typ:
| INT_TYPE
  { TInt }
| BOOL_TYPE
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

classes:
| /* Empty */
  { [] }
| class_def classes
  { $1 :: $2 }
;

instruction:
| PRINT LPAR e=expression RPAR SEMI { Print(e) }
| mem = mem ASSIGN e = expression SEMI { Set(mem, e) }
| IF LPAR cond = expression RPAR BEGIN true_branch = seq END
      ELSE BEGIN false_branch = seq END
    { If(cond, true_branch, false_branch) }
| WHILE LPAR cond = expression RPAR BEGIN body = seq END
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
| expr=expression DOT IDENT LPAR exprs=exprs RPAR
  { MethCall(expr, $3, exprs) }
;

exprs:
| /* Empty */
  { [] }
| expr=expression
  { [expr] }
| expr=expression COMMA exprs=exprs
  { expr :: exprs }
;

%inline uop:
| OPP { Opp }
| NOT   { Not }
;

%inline bop:
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


class_def:
| CLASS IDENT BEGIN attr_decls=attr_decls method_defs=method_defs END
  { { class_name = $2; attributes = attr_decls; methods = method_defs; parent = None } }
| CLASS IDENT EXTENDS IDENT BEGIN attr_decls=attr_decls method_defs=method_defs END
  { { class_name = $2; attributes = attr_decls; methods = method_defs; parent = Some $4 } }
;

attr_decls:
| /* Empty */
  { [] }
| attr_decl attr_decls
  { $1 :: $2 }
;

attr_decl:
| ATTR typ=typ IDENT SEMI
  { ($3, typ) }
;


method_defs:
| /* Empty */
  { [] }
| method_def method_defs
  { $1 :: $2 }
;

method_def:
| METHOD return=typ method_name=IDENT LPAR params=params RPAR
    BEGIN locals=var_decls code=seq END
    { {method_name; code; params; locals; return} }
;


seq:
| /* Empty */
  { [] }
| instruction seq
  { $1 :: $2 }
;


params:
| /* Empty */
  { [] }
| typ=typ IDENT
  { [($2, typ)] }
| typ=typ IDENT COMMA params
  { ($2, typ) :: $4 }
;