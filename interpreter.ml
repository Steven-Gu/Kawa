open Kawa

type value =
  | VInt  of int
  | VBool of bool
  | VObj  of obj
  | Null
and obj = {
  cls:    string;
  fields: (string, value) Hashtbl.t;
}

exception Error of string
exception Return of value

let exec_prog (p: program): unit =
  let env = Hashtbl.create 16 in
  List.iter (fun (x, _) -> Hashtbl.add env x Null) p.globals;
  List.iter (fun cls ->
    let obj = {
      cls = cls.class_name;
      fields = Hashtbl.create 8;
    } in
    Hashtbl.add env cls.class_name (VObj obj)
  ) p.classes;

  let rec eval_call f this args env lenv =
    match eval f env lenv with
    | VObj obj ->
      begin
        match Hashtbl.find_opt obj.fields "constructor" with
        | Some (VObj constr_obj) ->
          let constr_args = List.map (fun e -> eval e env lenv) args in
          ignore (eval_call (VObj constr_obj) this constr_args env lenv);
          VObj obj
        | _ -> VObj obj
      end
    | _ -> raise (Error "Cannot call method on non-object")

  and exec_seq s env lenv =
    let rec evali e env lenv = match eval e env lenv with
      | VInt n -> n
      | _ -> raise (Error "Expected integer value")
    and evalb e env lenv = match eval e env lenv with
      | VBool b -> b
      | _ -> raise (Error "Expected boolean value")
    and evalo e env lenv = match eval e env lenv with
      | VObj o -> o
      | _ -> raise (Error "Expected object value")

    and eval_mem_access m env lenv = match m with
      | Var var_name ->
        (match Hashtbl.find_opt env var_name with
        | Some value -> value
        | None -> raise (Error ("Variable not found: " ^ var_name)))
      | Field (obj, field_name) ->
        let this = eval obj env lenv in
        (match this with
        | VObj o ->
          (match Hashtbl.find_opt o.fields field_name with
          | Some value -> value
          | None -> raise (Error ("Attribute not found: " ^ field_name)))
        | _ -> raise (Error "Field access on non-object type"))

    and eval (e: expr) env lenv = match e with
      | Int n  -> VInt n
      | Bool b -> VBool b
      | Unop (unop, e') ->
        let v = eval e' env lenv in
        (match unop with
        | Opp -> (match v with VInt n -> VInt (-n) | _ -> raise (Error "Expected integer value"))
        | Not -> (match v with VBool b -> VBool (not b) | _ -> raise (Error "Expected boolean value")))
      | Binop (binop, e1, e2) ->
        let v1 = eval e1 env lenv in
        let v2 = eval e2 env lenv in
        (match binop with
        | Add -> (match v1, v2 with VInt n1, VInt n2 -> VInt (n1 + n2) | _ -> raise (Error "Expected integer values"))
        | Sub -> (match v1, v2 with VInt n1, VInt n2 -> VInt (n1 - n2) | _ -> raise (Error "Expected integer values"))
        | Mul -> (match v1, v2 with VInt n1, VInt n2 -> VInt (n1 * n2) | _ -> raise (Error "Expected integer values"))
        | Div -> (match v1, v2 with VInt n1, VInt n2 -> if n2 <> 0 then VInt (n1 / n2) else raise (Error "Division by zero") | _ -> raise (Error "Expected integer values"))
        | Rem -> (match v1, v2 with VInt n1, VInt n2 -> if n2 <> 0 then VInt (n1 mod n2) else raise (Error "Division by zero") | _ -> raise (Error "Expected integer values"))
        | Lt  -> (match v1, v2 with VInt n1, VInt n2 -> VBool (n1 < n2) | _ -> raise (Error "Expected integer values"))
        | Le  -> (match v1, v2 with VInt n1, VInt n2 -> VBool (n1 <= n2) | _ -> raise (Error "Expected integer values"))
        | Gt  -> (match v1, v2 with VInt n1, VInt n2 -> VBool (n1 > n2) | _ -> raise (Error "Expected integer values"))
        | Ge  -> (match v1, v2 with VInt n1, VInt n2 -> VBool (n1 >= n2) | _ -> raise (Error "Expected integer values"))
        | Eq  -> VBool (v1 = v2)
        | Neq -> VBool (v1 <> v2)
        | And -> (match v1, v2 with VBool b1, VBool b2 -> VBool (b1 && b2) | _ -> raise (Error "Expected boolean values"))
        | Or  -> (match v1, v2 with VBool b1, VBool b2 -> VBool (b1 || b2) | _ -> raise (Error "Expected boolean values")))

      | Get m -> eval_mem_access m env lenv

      | This -> (match lenv with Some obj -> obj | None -> raise (Error "Cannot use This outside of a method context"))

      | New c -> VObj { cls = c; fields = Hashtbl.create 8 }

      | NewCstr (class_name, args) ->
        let obj = eval (New class_name) env lenv in
        eval_call obj obj args env lenv

      | MethCall (obj, method_name, args) ->
        let this = eval obj env lenv in
        let obj_val = eval_call this this args env lenv in
        (match obj_val with
        | VObj o -> VObj o
        | _ -> raise (Error "Method call did not return an object"))

    in
  
    let rec exec (i: instr) env lenv = match i with
      | Print e -> Printf.printf "%d\n" (evali e env lenv)
      | Set (mem_access, e) ->
        let value = eval e env lenv in
        (match mem_access with
        | Var var_name -> Hashtbl.replace env var_name value
        | Field (obj, field_name) ->
          let this = eval obj env lenv in
          (match this with
          | VObj o -> Hashtbl.replace o.fields field_name value
          | _ -> raise (Error "Field access on non-object type")))
      | If (e, seq1, seq2) ->
        if evalb e env lenv then exec_seq seq1 env lenv else exec_seq seq2 env lenv
      | While (e, seq) ->
        while evalb e env lenv do
          exec_seq seq env lenv
        done
      | Return e ->
        raise (Return (eval e env lenv))
      | Expr e -> ignore (eval e env lenv)

    and exec_seq s env lenv =
      List.iter (fun i -> exec i env lenv) s
    in
  
    exec_seq p.main env None