open Kawa

exception Error of string
let error s = raise (Error s)
let type_error ty_actual ty_expected =
  error (Printf.sprintf "expected %s, got %s"
           (typ_to_string ty_expected) (typ_to_string ty_actual))

module Env = struct
  module ClassMap = Map.Make(String)
  module TypeMap = Map.Make(String)

  type t = {
    classes: class_def ClassMap.t;
    types: typ TypeMap.t;
  }

  let empty = { classes = ClassMap.empty; types = TypeMap.empty }

  let add_class class_name class_def env =
    { env with classes = ClassMap.add class_name class_def env.classes }

  let add_type type_name typ env =
    { env with types = TypeMap.add type_name typ env.types }

  let find_class class_name env =
    try Some (ClassMap.find class_name env.classes) with Not_found -> None

  let find_type type_name env =
    try TypeMap.find type_name env.types with Not_found -> TVoid  (* Default to TVoid if not found *)
end
          
type tenv = Env.t

let add_env l tenv =
  List.fold_left
    (fun env (x, t) ->
       match t with
       | TClass _ -> Env.add_class x { class_name = x; attributes = []; methods = []; parent = None } env
       | _ -> Env.add_type x t env)
    tenv l

let typecheck_prog p =
  let tenv = add_env p.globals Env.empty in

  let rec check e typ tenv =
    let typ_e = type_expr e tenv in
    if typ_e <> typ then type_error typ_e typ

  and type_expr e tenv = match e with
    | Int _  -> TInt
    | Bool _ -> TBool
    | Unop (unop, e')  -> 
      let type' = type_expr e' tenv in
      begin
        match unop with
        | Opp -> if type' = TInt then TInt else type_error type' TInt
        | Not -> if type' = TBool then TBool else type_error type' TBool
      end
    | Binop(binop, e1, e2) -> 
      let type1 = type_expr e1 tenv in
      let type2 = type_expr e2 tenv in
      begin
        match binop with
        | Add | Sub | Mul | Div | Rem ->
          if type1 = TInt && type2 = TInt then TInt
          else type_error type1 TInt
        | Lt  | Le  | Gt | Ge ->
          if type1 = TBool && type2 = TBool then TBool
          else type_error type1 TBool
        | Eq | Neq ->
          if type1 = type2 then TBool
          else type_error type1 type2
        | And | Or ->
          if type1 = TBool && type2 = TBool then TBool
          else type_error type1 TBool
      end
    | Get m -> type_mem_access m tenv
    | This -> TClass "current_class"  (* Replace "current_class" with the actual class name *)
    | New c -> TClass c
    | NewCstr (class_name, _) -> TClass class_name
    | MethCall (obj, method_name, _) ->
      let obj_type = type_expr obj tenv in
      match obj_type with
      | TClass class_name ->
        (match Env.find_class class_name tenv with
         | Some class_def ->
          (try
            let methods = class_def.methods in
            let method_defs = List.filter (fun m -> m.method_name = method_name) methods in
            match method_defs with
            | [method_def] -> method_def.return
            | _ -> failwith ("Ambiguous method call: " ^ method_name ^ " in class " ^ class_name)
            with Not_found ->
              failwith ("Method not found: " ^ method_name ^ " in class " ^ class_name))
         | None -> failwith ("Class not found: " ^ class_name))
      | _ -> failwith "Invalid object type for method call"

  and type_mem_access m tenv = match m with
    | Var var_name -> 
      (try Env.find_type var_name tenv with Not_found -> failwith ("Variable not found: " ^ var_name))
    | Field (obj, field_name) ->
      let obj_type = type_expr obj tenv in
      let attr_type =
        match obj_type with
        | TClass class_name ->
          (match Env.find_class class_name tenv with
            | Some class_def -> List.assoc field_name class_def.attributes
            | None -> failwith ("Class not found: " ^ class_name))
        | _ -> failwith "Field access on non-class type"
      in
      attr_type
  in

  let rec check_instr i ret tenv = match i with
    | Print e -> check e TInt tenv
    | Set (name, e) -> check e (type_mem_access name tenv) tenv
    | If (e, seq1, seq2) -> begin 
        check e TBool tenv;
        check_seq seq1 ret tenv;
        check_seq seq2 ret tenv;
      end
    | While (e,seq)-> begin
        check e TBool tenv;
        check_seq seq ret tenv;
      end
    | Return e -> 
      let ret_type = type_expr e tenv in
      if ret_type <> ret then type_error ret_type ret
    | Expr e -> ignore(type_expr e tenv)

  and check_seq s ret tenv =
    List.iter (fun i -> check_instr i ret tenv) s
  in

  check_seq p.main TVoid tenv
