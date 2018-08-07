open Ast

(* [(AlreadyConsumed i)] represents that an array access was performed
   using an index [i] that has already been consumed. *)
exception AlreadyConsumed of int
exception NoBinding

(* [gamma] is a type for a typing context that binds IDs to types. *)
type gamma

(* [delta] is a type for a mapping between alias IDs and types. *)
type delta

val empty_gamma : gamma
val empty_delta : delta

(* [add_binding id t g] is a new gamma [g'] with type_node [t] bound to [id]. *)
val add_binding : id -> type_node -> gamma -> gamma

(* [add_alias_binding id t d] is a new delta [d'] with type_node [t] bound to [id]. *)
val add_alias_binding : id -> type_node -> delta -> delta

(* [get_binding id g] is [Some t] that's bound to [id] in gamma [g],
   if such a binding exists; else, it's [None]. *)
val get_binding : id -> gamma -> type_node

(* [get_alias_binding id d] is [Some t] that's bound to [id] in delta [d],
   if such a binding exists; else, it's [None]. *)
val get_alias_binding : id -> delta -> type_node

(* [remove_binding id g] is [g'] where [g'] is [g] but without a binding to
   [id]; if [id] is not bound in [g], [g]=[g']. *)
val rem_binding : id -> gamma -> gamma

(* [consume_aa id n g] is [g'] where [g'] is a gamma with the
   index [n] of array with id [id] is consumed. Raises [AlreadyConsumed] if
   the [n] is already consumed. *)
val consume_aa : id -> int -> gamma -> gamma

(* [consume_aa_lst id [i..k] g] is [g'] where [g'] is a gamma with
   the indices i..k of array [id] consumed. Raises [AlreadyConsumed] if
   an element in [i..k] is already consumed. *)
val consume_aa_lst : id -> int list -> gamma -> gamma
