open Kawa

exception Error of string
let error s = raise (Error s)
let type_error ty_actual ty_expected =
  error (Printf.sprintf "expected %s, got %s"
           (typ_to_string ty_expected) (typ_to_string ty_actual))

module Env = Map.Make(String)
type tenv = typ Env.t

let add_env l tenv =
  List.fold_left (fun env (x, t) -> Env.add x t env) tenv l

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
    (* Implement logic to find the return type of the method in obj_type *)
      match obj_type with
      | TClass class_name -> TObject class_name  (* Assuming the method returns an instance of the class *)
      | _ -> failwith "Invalid object type for method call"
    | _ -> failwith "case not implemented in type_expr"

  and type_mem_access m tenv = match m with
    | Var var_name -> 
      (try Env.find var_name tenv with Not_found -> failwith ("Variable not found: " ^ var_name))
    | Field (obj, field_name) ->
      let obj_type = type_expr obj tenv in
      (* Implement logic to find the type of the attribute in obj_type *)
      TBool  (* Replace with the actual type *)

  in

  let rec check_instr i ret tenv = match i with
    | Print e -> ignore (check e TInt tenv)
    | _ -> failwith "case not implemented in check_instr"
  and check_seq s ret tenv =
    List.iter (fun i -> check_instr i ret tenv) s
  in

  check_seq p.main TVoid tenv
