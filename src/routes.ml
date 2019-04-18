type s = Rstring.t

module Method = struct
  type t =
    [ `GET
    | `HEAD
    | `POST
    | `PUT
    | `DELETE
    | `CONNECT
    | `OPTIONS
    | `TRACE
    | `Other of string
    ]

  let to_string = function
    | `GET -> "GET"
    | `HEAD -> "HEAD"
    | `POST -> "POST"
    | `PUT -> "PUT"
    | `DELETE -> "DELETE"
    | `CONNECT -> "CONNECT"
    | `OPTIONS -> "OPTIONS"
    | `TRACE -> "TRACE"
    | `Other s -> s
  ;;
end

type ('a, 'b) path =
  | End : (unit -> 'a, 'a) path
  | S : string * ('a, 'b) path -> ('a, 'b) path
  | Int : ('a, 'b) path -> (int -> 'a, 'b) path
  | Int32 : ('a, 'b) path -> (int32 -> 'a, 'b) path
  | Int64 : ('a, 'b) path -> (int64 -> 'a, 'b) path
  | Bool : ('a, 'b) path -> (bool -> 'a, 'b) path
  | Str : ('a, 'b) path -> (string -> 'a, 'b) path

type ('req, 'b) route =
  | Route : Method.t option * ('a, 'b) path * ('req -> 'a) -> ('req, 'b) route

type ('a, 'b) resource = Method.t option * ('a, 'b) path

let route (m, r) handler = Route (m, r, handler)
let ( ==> ) = route

(* Based on https://drup.github.io/2016/08/02/difflists/ *)
let rec print_params : type a b. (string -> b) -> (a, b) path -> a =
 fun k -> function
  | End -> fun () -> k ""
  | S (const, fmt) -> print_params (fun s -> k @@ String.concat "" [ const; s ]) fmt
  | Str fmt ->
    let f s = print_params (fun str -> k @@ String.concat "" [ s; str ]) fmt in
    f
  | Int fmt ->
    let f s =
      print_params (fun str -> k @@ String.concat "" [ string_of_int s; str ]) fmt
    in
    f
  | Int32 fmt ->
    let f s =
      print_params (fun str -> k @@ String.concat "" [ Int32.to_string s; str ]) fmt
    in
    f
  | Int64 fmt ->
    let f s =
      print_params (fun str -> k @@ String.concat "" [ Int64.to_string s; str ]) fmt
    in
    f
  | Bool fmt ->
    let f s =
      print_params (fun str -> k @@ String.concat "" [ string_of_bool s; str ]) fmt
    in
    f
;;

let rec pp_path : type a b. Format.formatter -> (a, b) path -> unit =
 fun fmt -> function
  | End -> Format.fprintf fmt ""
  | S (x, rest) ->
    Format.fprintf fmt "%s" x;
    pp_path fmt rest
  | Int rest ->
    Format.fprintf fmt "<int>";
    pp_path fmt rest
  | Int32 rest ->
    Format.fprintf fmt "<int32>";
    pp_path fmt rest
  | Int64 rest ->
    Format.fprintf fmt "<int64>";
    pp_path fmt rest
  | Bool rest ->
    Format.fprintf fmt "<bool>";
    pp_path fmt rest
  | Str rest ->
    Format.fprintf fmt "<string>";
    pp_path fmt rest
;;

let pp_hum : type a b. Format.formatter -> Method.t option * (a, b) path -> unit =
 fun fmt -> function
  | m, r ->
    (match m with
    | None -> pp_path fmt r
    | Some m' ->
      Format.fprintf fmt "Method: %s " (Method.to_string m');
      pp_path fmt r)
;;

let sprintf (_, fmt) = print_params (fun x -> x) fmt

let parse_route fmt handler target =
  let rec match_target : type a b. (a, b) path -> a -> s -> (unit -> b) option =
   fun t f s ->
    match t with
    | End -> if Rstring.is_empty s then Some f else None
    | S (x, fmt) ->
      (match Parse.drop_prefix x s with
      | None -> None
      | Some (_, rest) -> match_target fmt f rest)
    | Int fmt ->
      (match (Parse.filter_map ~f:Rstring.to_int Parse.take_token) s with
      | None -> None
      | Some (i, rest') -> match_target fmt (f i) rest')
    | Int32 fmt ->
      (match (Parse.filter_map ~f:Rstring.to_int32 Parse.take_token) s with
      | None -> None
      | Some (i, rest') -> match_target fmt (f i) rest')
    | Int64 fmt ->
      (match (Parse.filter_map ~f:Rstring.to_int64 Parse.take_token) s with
      | None -> None
      | Some (i, rest') -> match_target fmt (f i) rest')
    | Str fmt ->
      (match Parse.take_token s with
      | None -> None
      | Some (w, rest') -> match_target fmt (f w) rest')
    | Bool fmt ->
      (match (Parse.filter_map ~f:Rstring.to_bool Parse.take_token) s with
      | None -> None
      | Some (b, rest') -> match_target fmt (f b) rest')
  in
  match_target fmt handler target
;;

let match' paths ~target ~meth ~req =
  if String.length target = 0
  then None
  else (
    let target' = Rstring.of_string target in
    let target', _ = Rstring.take_while ~f:(fun x -> x <> '?') target' in
    let target' =
      match Rstring.get target' 0 with
      | '/' -> Rstring.tail target'
      | _ -> target'
    in
    (* eventually we should pre-preprocess the list of routes to get more optimized matching.
       We really should have something better than matching one route at a time.
    *)
    let method_matched m' = function
      | None -> true
      | Some m'' -> m' = m''
    in
    let rec route' = function
      | [] -> None
      | Route (m, r, h) :: ps ->
        if method_matched meth m
        then (
          match parse_route r (h req) target' with
          | None -> route' ps
          | Some f -> Some (f ()))
        else route' ps
    in
    route' paths)
;;

(* Public api to construct paths *)
let int r = Int r
let int32 r = Int32 r
let int64 r = Int64 r
let str r = Str r
let bool r = Bool r
let s w r = S (w, r)
let slash m1 m2 r = m1 @@ s "/" @@ m2 r
let ( </> ) = slash

(* Public api to construct Routes *)
let method' meth r = meth, r End
