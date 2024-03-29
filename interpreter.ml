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
let current_object = ref None

(* let rec string_of_expr = function
  | Int n -> Printf.sprintf "Int(%d)" n
  | Bool b -> Printf.sprintf "Bool(%b)" b
  | This -> "This"
  | Get m -> Printf.sprintf "Get(%s)" (string_of_mem_access m)
  | Unop (u, e) -> Printf.sprintf "Unop(%s, %s)" (string_of_unop u) (string_of_expr e)
  | Binop (b, e1, e2) ->
      Printf.sprintf "Binop(%s, %s, %s)" (string_of_binop b) (string_of_expr e1) (string_of_expr e2)
  | New cls -> Printf.sprintf "New(%s)" cls
  | NewCstr (cls, args) ->
      let args_str = String.concat ", " (List.map string_of_expr args) in
      Printf.sprintf "NewCstr(%s, [%s])" cls args_str
  | MethCall (obj, method_name, args) ->
      let obj_str = string_of_expr obj in
      let args_str = String.concat ", " (List.map string_of_expr args) in
      Printf.sprintf "MethCall(%s, %s, [%s])" obj_str method_name args_str

and string_of_unop = function
  | Opp -> "Opp"
  | Not -> "Not"

and string_of_binop = function
  | Add -> "Add"
  | Sub -> "Sub"
  | Mul -> "Mul"
  | Div -> "Div"
  | Rem -> "Rem"
  | Lt -> "Lt"
  | Le -> "Le"
  | Gt -> "Gt"
  | Ge -> "Ge"
  | Eq -> "Eq"
  | Neq -> "Neq"
  | And -> "And"
  | Or -> "Or"

and string_of_mem_access = function
  | Var v -> Printf.sprintf "Var(%s)" v
  | Field (e, field) -> Printf.sprintf "Field(%s, %s)" (string_of_expr e) field


let rec string_of_value = function
  | VInt n -> Printf.sprintf "VInt(%d)" n
  | VBool b -> Printf.sprintf "VBool(%s)" (string_of_bool b)
  | VObj obj -> Printf.sprintf "VObj(%s)" (string_of_obj obj)
  | Null -> "Null"

and string_of_obj obj =
  let buf = Buffer.create 50 in
  Buffer.add_string buf "{ ";
  Hashtbl.iter (fun key value ->
    Buffer.add_string buf (Printf.sprintf "%s: %s; " key (string_of_value value))
  ) obj.fields;
  Buffer.add_string buf " }";
  Buffer.contents buf

  let rec string_of_value v = match v with
  | VInt n -> Printf.sprintf "VInt(%d)" n
  | VBool b -> Printf.sprintf "VBool(%b)" b
  | VObj obj -> string_of_obj obj
  | Null -> "Null"

and string_of_obj o =
  let fields_str = Hashtbl.fold (fun key value acc ->
    Printf.sprintf "%s: %s; %s" key (string_of_value value) acc
  ) o.fields ""
  in Printf.sprintf "{ %s }" fields_str

let print_obj obj =
  Printf.printf "Object: %s\n" (string_of_obj obj)

let print_env env =
  Printf.printf "Environment:\n";
  Hashtbl.iter (fun key value ->
    Printf.printf "  %s -> %s\n" key (string_of_value value)
  ) env
 *)
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


  let rec eval_call (this: value) method_name (args: value list) =
    match this with
    | VObj obj ->
      current_object := Some this;
      let class_def = find_class_def obj.cls p.classes in
      let method_def = find_method_def method_name class_def.methods in
      let lenv = create_local_env method_def.params args in
      let result = (try
        eval_seq method_def.code lenv;
        Null
      with
      | Return v -> v
      | Error e -> raise (Error e))
      in
      current_object := None;
      (result,obj)
    | _ -> raise (Error "Method call on non-object type")
  
  and find_class_def cls_name classes =
    match List.find_opt (fun c -> c.class_name = cls_name) classes with
    | Some class_def -> class_def
    | None -> raise (Error ("Class not found: " ^ cls_name))
  
  and find_method_def method_name methods =
    match List.find_opt (fun m -> m.method_name = method_name) methods with
    | Some method_def -> method_def
    | None -> raise (Error ("Method not found: " ^ method_name))
  
  and create_local_env params args =
    let env = Hashtbl.create (List.length params) in
    List.iter2 (fun (param_name, _) arg ->
      Hashtbl.add env param_name arg
    ) params args;
    env

  and eval_seq s lenv =
    let rec evali e  = match eval e with
      | VInt n -> n
      | _ -> raise (Error "Expected integer value")
    and evalb e = match eval e with
      | VBool b -> b
      | _ -> raise (Error "Expected boolean value")
    and eval_mem_access m env lenv = match m with
    | Var var_name ->
      (match Hashtbl.find_opt lenv var_name with
      | Some value -> value
      | None ->
        (match Hashtbl.find_opt env var_name with
        | Some value -> value
        | None -> raise (Error ("Variable not found: " ^ var_name))))
    | Field (obj, field_name) ->
      let this = eval obj in
      (match this with
      | VObj o ->
        (match Hashtbl.find_opt o.fields field_name with
        | Some value -> value
        | None -> raise (Error ("Attribute not found: " ^ field_name)));
      | _ -> raise (Error "Field access on non-object type"))
    

    and eval (e: expr)  = match e with
      | Int n  -> VInt n
      | Bool b -> VBool b
      | Unop (unop, e') ->
        let v = eval e' in
        (match unop with
        | Opp -> (match v with VInt n -> VInt (-n) | _ -> raise (Error "Expected integer value"))
        | Not -> (match v with VBool b -> VBool (not b) | _ -> raise (Error "Expected boolean value")))
      | Binop (binop, e1, e2) ->
        let v1 = eval e1 in
        let v2 = eval e2 in
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

      | This ->
        (match !current_object with
        | Some obj -> obj 
        | None -> raise (Error "Use of 'this' outside of object context"))

      | New c -> VObj { cls = c; fields = Hashtbl.create 8 }

      | NewCstr (class_name, args) ->
        let obj = eval (New class_name) in
        let evaluated_args = List.map (fun arg -> eval arg) args in
        let result = snd (eval_call obj "constructor" evaluated_args) in
        VObj result

      | MethCall (obj, method_name, args) ->
        let this = eval obj in
        let evaluated_args = List.map (fun arg -> eval arg) args in
        let obj_val = fst (eval_call this method_name evaluated_args) in
        obj_val

    in
  
    let rec exec (i: instr)  = match i with
      | Print e -> Printf.printf "%d\n" (evali e)
      | Set (mem_access, e) ->
        let value = eval e in
        (match mem_access with
        | Var var_name -> Hashtbl.replace env var_name value
        | Field (obj, field_name) ->
          let this = eval obj in
          (match this with
          | VObj o -> 
            Hashtbl.replace o.fields field_name value;
          | _ -> raise (Error "Field access on non-object type")))
      | If (e, seq1, seq2) ->
        if evalb e then exec_seq seq1  else exec_seq seq2
      | While (e, seq) ->
        while evalb e do
          exec_seq seq 
        done
      | Return e ->
        raise (Return (eval e))
      | Expr e -> ignore (eval e)

    and exec_seq s =
      List.iter exec s
    in
    exec_seq s
  in
  
    eval_seq p.main (Hashtbl.create 1)