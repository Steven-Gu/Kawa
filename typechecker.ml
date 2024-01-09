open Kawa

exception Error of string
let error s = raise (Error s)

module Env = struct
  module ClassMap = Map.Make(String)
  module TypeMap = Map.Make(String)

  type t = {
    classes: class_def ClassMap.t;
    types: typ TypeMap.t;
    current_class: string option;
  }

  let empty = { classes = ClassMap.empty; types = TypeMap.empty; current_class = None }

  let add_class class_name class_def env =
    { env with classes = ClassMap.add class_name class_def env.classes }

  let add_type type_name typ env =
    { env with types = TypeMap.add type_name typ env.types }
  
  let set_current_class class_name env =
    { env with current_class = Some class_name }
  
  let get_current_class env =
    env.current_class
    
  let find_class class_name env =
    try Some (ClassMap.find class_name env.classes) with Not_found -> None

  let find_type type_name env =
    try TypeMap.find type_name env.types with Not_found -> TVoid 
end

type tenv = Env.t

let add_env l tenv =
  List.fold_left
    (fun env (x, t) ->Env.add_type x t env)
    tenv l

let get_class_def class_name tenv =
  match Env.find_class class_name tenv with
  | Some class_def -> class_def
  | None -> error ("Class not found: " ^ class_name)

let get_method_def class_def method_name =
  try
    let methods = class_def.methods in
    List.find (fun m -> m.method_name = method_name) methods
  with Not_found ->
    error ("Method not found: " ^ method_name ^ " in class " ^ class_def.class_name)

let rec check e typ tenv =
  let typ_e = type_expr e tenv in
  if typ_e <> typ && not (is_subtype tenv typ_e typ) then
    error (Printf.sprintf "Expected %s, got %s" (typ_to_string typ) (typ_to_string typ_e))

and is_subtype tenv sub super =
  match sub, super with
  | TClass sub_class, TClass super_class ->
    let sub_class_def = get_class_def sub_class tenv in
    if sub_class = super_class then true
    else
      (match sub_class_def.parent with
      | Some parent_class -> is_subtype tenv (TClass parent_class) super
      | None -> false)
  | _ -> false

and type_expr e tenv = match e with
  | Int _  -> TInt
  | Bool _ -> TBool
  | Unop (unop, e')  -> 
    let type' = type_expr e' tenv in
    begin
      match unop with
      | Opp -> if type' = TInt then TInt else error "Type mismatch in unary operation"
      | Not -> if type' = TBool then TBool else error "Type mismatch in unary operation"
    end
  | Binop(binop, e1, e2) -> 
    let type1 = type_expr e1 tenv in
    let type2 = type_expr e2 tenv in
    begin
      match binop with
      | Add | Sub | Mul | Div | Rem ->
        if type1 = TInt && type2 = TInt then TInt
        else error "Type mismatch in binary operation"
      | Lt  | Le  | Gt | Ge ->
        if type1 = TBool && type2 = TBool then TBool
        else error "Type mismatch in binary operation"
      | Eq | Neq ->
        if type1 = type2 then TBool
        else error "Type mismatch in binary operation"
      | And | Or ->
        if type1 = TBool && type2 = TBool then TBool
        else error "Type mismatch in binary operation"
    end
  | Get m -> type_mem_access m tenv
  | This ->
    (match Env.get_current_class tenv with
      | Some class_name -> TClass class_name
      | None -> error "Cannot use This outside of a class context")
  | New c -> 
    if Env.find_class c tenv = None then
      error ("Class not found: " ^ c)
    else
      TClass c
  | NewCstr (class_name, args) ->
    let class_def =
      try
        get_class_def class_name tenv
      with Not_found ->
        error ("Class not found: " ^ class_name)
    in
    let constructor_def =
      try
        get_method_def class_def "constructor"
      with Not_found ->
        error ("Constructor not found in class: " ^ class_name)
    in
    
    let check_constructor_param (param_name, param_type) arg_expr =
      let arg_type = type_expr arg_expr tenv in
      if arg_type <> param_type then
        error (Printf.sprintf "Constructor parameter %s expected type %s, got %s"
                 param_name (typ_to_string param_type) (typ_to_string arg_type))
    in
    
    let expected_params = constructor_def.params in
    if List.length args <> List.length expected_params then
      error (Printf.sprintf "Constructor %s expected %d arguments, got %d"
               class_name (List.length expected_params) (List.length args));
    
    List.iter2 check_constructor_param expected_params args;
    
    TClass class_name

  | MethCall (obj, method_name, args) ->
    let obj_type = type_expr obj tenv in
    (match obj_type with
      | TClass class_name ->
        let class_def = get_class_def class_name tenv in
        let method_def = get_method_def class_def method_name in
        let check_method_arg (param_name, param_type) arg_expr =
          let arg_type = type_expr arg_expr tenv in
          if arg_type <> param_type then
            error (Printf.sprintf "Method argument %s expected type %s, got %s"
                     param_name (typ_to_string param_type) (typ_to_string arg_type))
        in
        List.iter2 check_method_arg method_def.params args;
        method_def.return
      | _ -> error "Invalid object type for method call")

and type_mem_access m tenv = 
  match m with
  | Var var_name -> 
    (try Env.find_type var_name tenv with Not_found -> raise (Error ("Variable not found: " ^ var_name)))
  | Field (obj, field_name) ->
    let obj_type = type_expr obj tenv in
    let attr_type =
      match obj_type with
      | TClass class_name ->
        let class_def = get_class_def class_name tenv in
        (try List.assoc field_name class_def.attributes with Not_found ->
          (match class_def.parent with
          | None -> raise (Error ("Attribute not found: " ^ field_name ^ " in class " ^ class_name))
          | Some parent ->
            let parent_def = get_class_def parent tenv in
            (try List.assoc field_name parent_def.attributes with Not_found ->
              raise (Error ("Attribute not found: " ^ field_name ^ " in class " ^ class_name)))))
      | _ -> raise (Error "Field access on non-class type")
    in
    attr_type

and check_instr i ret tenv = match i with
  | Print e -> check e TInt tenv
  | Set (name, e) -> check e (type_mem_access name tenv) tenv
  | If (e, seq1, seq2) ->
    check e TBool tenv;
    check_seq seq1 ret tenv;
    check_seq seq2 ret tenv;
  | While (e, seq) ->
    check e TBool tenv;
    check_seq seq ret tenv;
  | Return e -> 
    let ret_type = type_expr e tenv in
    if ret_type <> ret then
      error (Printf.sprintf "Expected return type %s, got %s" (typ_to_string ret) (typ_to_string ret_type))
  | Expr e -> ignore(type_expr e tenv)

and check_seq s ret tenv =
  let has_return = ref false in
  List.iter (fun i -> 
    check_instr i ret tenv;
    match i with
    | Return _ -> has_return := true
    | _ -> ()
    ) s;
  if not !has_return && ret <> TVoid then
    error "Missing return statement in a function that expects a return value"

and check_class class_def tenv =
  let tenv' = Env.set_current_class class_def.class_name tenv in
  List.iter (fun m -> check_mdef m tenv') class_def.methods

and check_mdef method_def tenv =
  let tenv' = add_env method_def.params tenv in
  let tenv'' = add_env method_def.locals tenv' in
  check_seq method_def.code method_def.return tenv''

let typecheck_prog p =
  let tenv = List.fold_left (fun env c -> Env.add_class c.class_name c env) Env.empty p.classes in
  let tenv' = add_env p.globals tenv in
  List.iter (fun c -> check_class c tenv') p.classes;
  check_seq p.main TVoid tenv'

