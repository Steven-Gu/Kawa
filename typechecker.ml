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
      begin
      let type' = type_expr e' tenv in
      match unop with
      |Opp -> begin 
        match type' with 
        |TInt -> TInt
        | _ -> failwith "type error"
      end
      |Not ->begin 
        match type' with 
        |TBool -> TBool
        | _ -> failwith "type error"
      end
    end
    | Binop(binop, e1, e2) -> 
      begin
        let type1 = type_expr e1 tenv in
        let type2 = type_expr e2 tenv in
      match binop with
      |Add | Sub | Mul | Div | Rem -> begin
        match type1,type2 with
        | TInt, TInt -> TInt
        | _,_ -> failwith "type error"
      end
      |Lt  | Le  | Gt | Ge -> begin
        match type1,type2 with
        | TBool,TBool -> TBool
        | _,_ -> failwith "type error"
      end
      |Eq | Neq -> begin
        if type1 = type2 then TBool
        else failwith "type error"
      end
      |And | Or -> begin
        match type1,type2 with
        | TBool,TBool -> TBool
        | _,_ -> failwith "type error"
      end
    
    end
    | Get m -> type_mem_access m tenv
    | This -> TClass
    | New c -> TClass c
    | NewCstr _ -> TInt
    | MethCall _ -> TInt
    | _ -> failwith "case not implemented in type_expr"

  and type_mem_access m tenv = match m with
    | _ -> failwith "case not implemented in type_mem_access"
  in

  let rec check_instr i ret tenv = match i with
    | Print e -> check e TInt tenv
    | _ -> failwith "case not implemented in check_instr"
  and check_seq s ret tenv =
    List.iter (fun i -> check_instr i ret tenv) s
  in

  check_seq p.main TVoid tenv
