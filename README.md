## Routes

This library will help with adding typed routes to OCaml applications.

Users can create a list of routes, and handler function to work
on the extracted entities using the combinators provided by
the library. To perform URL matching one would just need to forward
the URL's path and query to the matcher.

The core library in the current state isn't tied to any particular library or framework.
It should be usable in the current state, but the idea would be to provide sub-libraries
with tighter integration with the remaining ecosystem. Future work would also include
working on client side routing for use with `js_of_ocaml` libraries
like [incr_dom](https://github.com/janestreet/incr_dom) or [ocaml-vdom](https://github.com/LexiFi/ocaml-vdom).

#### Example

```ocaml
# #require "routes";;
# type req = {target: string};;
type req = { target : string; }

# let idx (_ : req) () = "root";;
val idx : req -> unit -> string = <fun>

# let get_user (req : req) (id: int) () = Printf.sprintf "Received request from %s to fetch id: %d" req.target id
val get_user : req -> int -> unit -> string = <fun>

# let search_user (_req : req) (name: string) (city : string) () = "search for user";;
val search_user : req -> string -> string -> unit -> string = <fun>

# let routes =
  let open Routes in
  [ method' None (s "") ==> idx (* matches the index route "/" *)
  ; method' (Some `GET) (s "user" </> int) ==> get_user (* matches "/user/<int>" *)
  ; method' None (s "user" </> str </> str) ==> search_user (*  matches "/user/<str>/<str>" *)
  ]
val routes : (req, string) Routes.route list = [<abstr>; <abstr>; <abstr>]

# let req = { target = "/user/12" };;
val req : req = {target = "/user/12"}

# match Routes.match' ~req routes ~target:"/some/url" ~meth:`GET with None -> "No match" | Some r -> r;;
- : string = "No match"

# match Routes.match' ~req routes ~target:req.target ~meth:`GET with None -> "No match" | Some r -> r;;
- : string = "Received request from /user/12 to fetch id: 12"
```

`Routes` also provides a sprintf like function to generate formatted URLs. It uses
the same format description of a route that is used for routing.

```ocaml
# open Routes;;

# (sprintf (method' None (s "user" </> int </> bool))) 12 false ();;
- : string = "user/12/false"
```

## Installation

`routes` has not been published on OPAM yet. It can be pinned via opam
to use locally:

```
opam pin add routes git+https://github.com/anuragsoni/routes.git
```

## Related Work

The combinators are influenced by Rudi Grinberg's wonderful [blogpost](http://rgrinberg.com/posts/primitive-type-safe-routing/) about
type safe routing done via an EDSL using GADTs + an interpreted for the DSL.

Also thanks to Gabriel Radanne for feedback and for the [blog](https://drup.github.io/2016/08/02/difflists/) post showing the technique
used in printf like functions.
