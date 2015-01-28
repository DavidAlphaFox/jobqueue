(*
   Same as Util_time, but:
   - use 1-second precision
   - serialize to/from decimal integers representing the number of seconds
     since January 1, 1970, as returned by Unix.time().

   The main advantage of this representation over RFC-3339 (Util_time)
   is that the serialized representation can be used as stable keys.
*)

type t

val equal : t -> t -> bool
val compare : t -> t -> int

val to_string : t -> string
val of_string : string -> t

val of_float : float -> t
val to_float : t -> float

val wrap : float -> t
val unwrap : t -> float

val to_time : t -> Util_time.t
val of_time : Util_time.t -> t

val now : unit -> t

val add : t -> float -> t
val sub : t -> float -> t
  (* Add or subtract seconds *)