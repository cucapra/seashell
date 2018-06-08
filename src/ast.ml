type id = string

type type_node =
  | TInt
  | TBool
  | TArray of type_node

type binop =
  | BopEq
  | BopNeq
  | BopGeq
  | BopLeq
  | BopLt
  | BopGt
  | BopPlus
  | BopMinus
  | BopTimes
  | BopAnd
  | BopOr

type expression =
  | EInt of int
  | EVar of id
  | EBool of bool
  | EBinop of binop * expression * expression
  | EArray of type_node * expression array
  | EArrayAccess of id * expression

type value =
  | VInt of int
  | VBool of bool
  | VRange of int * int
  | VArray of value array
  
type command =
  | CAssignment of id * expression
  | CFor of id * expression * expression * command
  | CArrayUpdate of id * expression * expression
  | CIf of expression * command
  | CSeq of command * command
