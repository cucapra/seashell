open Ast

exception TypeError of string

let flip f x y = f y x

type context = ((id * int option), type_node) Hashtbl.t

let empty_context = Hashtbl.create 100

let type_of_id = flip Hashtbl.find

let rec string_of_type = function
  | TBool -> "bool"
  | TInt _ -> "int"
  | TArray (t, _) -> (string_of_type t) ^ " array"
  | TIndex _ -> failwith "Undefined"

let string_of_binop = function
  | BopEq    -> "="
  | BopNeq   -> "!="
  | BopGeq   -> ">="
  | BopLeq   -> "<="
  | BopLt    -> "<"
  | BopGt    -> ">"
  | BopPlus  -> "+"
  | BopMinus -> "-"
  | BopTimes -> "*"
  | BopOr    -> "||"
  | BopAnd   -> "&&"

let bop_type = function
  | BopEq    -> TBool
  | BopNeq   -> TBool
  | BopGeq   -> TBool
  | BopLeq   -> TBool
  | BopLt    -> TBool
  | BopGt    -> TBool
  | BopPlus  -> TInt None
  | BopMinus -> TInt None
  | BopTimes -> TInt None
  | BopAnd   -> TBool
  | BopOr    -> TBool

let is_int = function
  | TInt _ -> true
  | _ -> false

let is_bool = (=) TBool

let legal_op t1 t2 = function
  | BopEq    -> is_int t1 && is_int t2
  | BopNeq   -> is_int t1 && is_int t2
  | BopGeq   -> is_int t1 && is_int t2
  | BopLeq   -> is_int t1 && is_int t2
  | BopLt    -> is_int t1 && is_int t2
  | BopGt    -> is_int t1 && is_int t2
  | BopPlus  -> is_int t1 && is_int t2
  | BopMinus -> is_int t1 && is_int t2
  | BopTimes -> is_int t1 && is_int t2
  | BopAnd   -> is_bool t1 && is_bool t2
  | BopOr    -> is_bool t1 && is_bool t2

let rec check_expr exp context =
  match exp with
  | EInt (i, s)                       -> check_int i s context
  | EBool _                           -> TBool, context
  | EVar x                            -> Hashtbl.find context (x, None), context
  | EBinop (binop, e1, e2)            -> check_binop binop e1 e2 context
  | EArray _                          -> raise (TypeError "Can't refer to array literal")
  | EArrayExplAccess (id, idx1, idx2) -> check_aa_expl id idx1 idx2 context
  | EIndex _
  | EArrayImplAccess _ -> failwith "Implement implicit access"

and check_int i s ctx = (if s then TInt (Some i) else TInt (None)), ctx

and check_binop binop e1 e2 c =
  check_expr e1 c  |> fun (t1, c1) ->
  check_expr e2 c1 |> fun (t2, c2) ->
  if legal_op t1 t2 binop then bop_type binop, c2
  else raise (TypeError 
    ("Illegal operation: can't apply operator '" ^
     (string_of_binop binop) ^ 
     "' to " ^ 
     (string_of_type t1) ^ 
     " and " ^ 
     (string_of_type t2)))

and check_array_access_implicit id idx context =
  failwith "Implement implicit loop"

and check_aa_expl id idx1 idx2 c =
  check_expr idx1 c       |> fun (idx1_t, c1) ->
  check_expr idx2 c1      |> fun (idx2_t, c2) ->
  match idx1_t, idx2_t with
  | TInt (None), _ -> raise (TypeError "Bank accessor must be static")
  | TInt (Some i), TInt _ ->
    if Hashtbl.mem c2 (id, Some i) then
      TInt (None), (Hashtbl.remove c2 (id, Some i); c2)
    else raise (TypeError ("Illegal bank access: " ^ (string_of_int i)))
  | _ -> raise (TypeError "Bank accessor must be static") 

let array_elem_error arr_id arr_t elem_t =
  ("Array " ^ arr_id ^ "is of type " ^ (string_of_type arr_t) ^ 
  "; tried to add element of type " ^ (string_of_type elem_t))

let arr_idx_type_error =
  "Tried to index into array with non-integer index"

let arr_type_error =
  "Tried to index into non-array"

let rec check_cmd cmd context =
  match cmd with
  | CSeq (c1, c2)              -> check_seq c1 c2 context
  | CIf (cond, cmd)            -> check_if cond cmd context
  | CFor (x, r1, r2, body)     -> check_for x r1 r2 body context
  | CAssignment (x, e1)        -> check_assignment x e1 context
  | CReassign (target, exp)    -> check_reassign target exp context
  | CForImpl (x, r1, r2, body) -> check_for_impl x r1 r2 body context

and check_seq c1 c2 context =
  check_cmd c1 context
  |> fun context' -> check_cmd c2 context'

and check_if cond cmd context =
  match check_expr cond context with
  | TBool, c -> check_cmd cmd c
  | _ -> raise (TypeError "Non-boolean conditional")
  
and add_array_banks bf id bank_num context t i =
  if i=bank_num then context
  else 
    (Hashtbl.add context (id, Some i) (TArray (t, bf)); 
     (add_array_banks bf id bank_num context t (i+1)))

and check_for id r1 r2 body c =
  check_expr r1 c       |> fun (r1_type, c1) ->
  check_expr r2 c1      |> fun (r2_type, c2) ->
  match r1_type, r2_type with
  | TInt _, TInt _ -> 
    Hashtbl.add c2 (id, None) (TInt None); check_cmd body c2
  | _ -> raise (TypeError "Range start/end must be integers")

and check_assignment id exp context =
  match exp with
  | EArray (t, b, _) -> 
    Hashtbl.add context (id, None) (TArray (t, b)); 
    add_array_banks b id b context t 0
  | other_exp -> 
    check_expr other_exp context |> fun (t, c) ->
    Hashtbl.add c (id, None) t; c

and check_reassign target exp context =
  match target, exp with
  | EArrayExplAccess (id, idx1, idx2), expr ->
    begin
    check_array_access_explicit id idx1 idx2 context |> fun (t_arr, c) ->
    check_expr exp c                                 |> fun (t_exp, c') ->
    match t_arr, t_exp with
    | TInt _, TInt _ -> c'
    | t1, t2 -> if t1=t2 then c' else raise (TypeError "Tried to populate array with incorrect type")
    end
  | EArrayImplAccess (id, idx), expr ->
    check_array_access_implicit id idx context       |> fun (t_arr, c) ->
    check_expr exp c                                 |> fun (t_exp, c') ->
    begin
    match t_arr, t_exp with
    | TInt _, TInt _ -> c'
    | t1, t2 -> if t1=t2 then c' else raise (TypeError "Tried to populate array with incorrect type")
    end
  | EVar id, expr -> context
  | _ -> raise (TypeError "Used reassign operator on illegal types")

and check_for_impl id idx1 idx2 body context =
  failwith "Implement index for loop"

