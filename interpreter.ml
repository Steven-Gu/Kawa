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
  
  let rec eval_call f this args =
    try
    let method_def = List.find (fun m -> m.method_name = f) methods in
    let local_env = Hashtbl.create 16 in

    (* Initialize parameters *)
    List.iter2 (fun (param_type, param_name) arg_value ->
      Hashtbl.add local_env param_name arg_value
    ) method_def.params args;

    (* Initialize local variables *)
    List.iter (fun (var_type, var_name) ->
      Hashtbl.add local_env var_name (default_value var_type)
    ) method_def.locals;

    (* Execute method instructions *)
    let rec exec_instrs instrs = match instrs with
      | [] -> failwith "No return statement"
      | i::is -> match i with
        | Return e -> eval e local_env
        | _ -> exec_instr i local_env; exec_instrs is
    in

    exec_instrs method_def.code
    with Not_found ->
        failwith("Method not found: " ^ f)

  and exec_seq s lenv =
    let rec evali e = match eval e with
      | VInt n -> n
      | _ -> assert false
    and evalb e = match eval e with
      | VBool b -> b
      | _ -> assert false
    and evalo e = match eval e with
      | VObj o -> o
      | _ -> assert false
        
    and eval (e: expr): value = match e with
      | Int n  -> VInt n
      | Bool b -> VBool b
      | Var x  -> Hashtbl.find lenv x
      | BinOp (e1, op, e2) ->
          let v1 = eval e1 and v2 = eval e2 in
          (* Implement binary operation logic based on op *)
          failwith "Binary operation not implemented"
      | If (cond, then_br, else_br) ->
          if evalb cond then exec_seq then_br lenv
          else exec_seq else_br lenv
      | Call (f, args) ->
          let arg_vals = List.map eval args in
          eval_call f Null arg_vals
      | _ -> failwith "case not implemented in eval"
    in
  
    let rec exec (i: instr): unit = match i with
      | Print e -> Printf.printf "%d\n" (evali e)
      | Assign (x, e) -> Hashtbl.replace lenv x (eval e)
      | IfInstr (cond, then_br, else_br) ->
          if evalb cond then exec_seq then_br lenv
          else exec_seq else_br lenv
      | While (cond, body) ->
          while evalb cond do exec_seq body lenv done
      | Return e -> raise (Return (eval e))
      | _ -> failwith "case not implemented in exec"

    and exec_seq s = 
      List.iter exec s
    in

    exec_seq s
  in
  
  exec_seq p.main (Hashtbl.create 1)
