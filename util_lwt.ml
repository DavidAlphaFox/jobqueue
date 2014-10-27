open Lwt

let bind2 a b func =
  a >>= fun a' ->
  b >>= fun b' ->
  func a' b'

let bind3 a b c func =
  a >>= fun a' ->
  b >>= fun b' ->
  c >>= fun c' ->
  func a' b' c'

let bind4 a b c d func =
  a >>= fun a' ->
  b >>= fun b' ->
  c >>= fun c' ->
  d >>= fun d' ->
  func a' b' c' d'

let bind5 a b c d e func =
  a >>= fun a' ->
  b >>= fun b' ->
  c >>= fun c' ->
  d >>= fun d' ->
  e >>= fun e' ->
  func a' b' c' d' e'

let join2 a b =
  bind2 a b (fun a b -> return (a, b))

let join3 a b c =
  bind3 a b c (fun a b c -> return (a, b, c))

let join4 a b c d =
  bind4 a b c d (fun a b c d -> return (a, b, c, d))

let join5 a b c d e =
  bind5 a b c d e (fun a b c d e -> return (a, b, c, d, e))

let rec find_map_left l f =
  match l with
  | [] -> return None
  | x :: tl ->
      f x >>= function
      | None -> find_map_left tl f
      | Some y as result -> return result

let find_map_right l f =
  find_map_left (List.rev l) f

let filter_map_p l f =
  Lwt_list.map_p f l >>= fun l ->
  return (BatList.filter_map (fun o -> o) l)

let map_default default opt f =
  match opt with
  | None -> return default
  | Some x -> f x


let rec iter_stream chunk_size stream f =
  Lwt_stream.nget chunk_size stream >>= function
  | [] -> return ()
  | l ->
      Lwt_list.iter_p f l >>= fun () ->
      iter_stream chunk_size stream f

let gethostbyname hostname =
  catch
    (fun () ->
       Lwt_unix.gethostbyname hostname
    )
    (function
      | Not_found ->
          failwith ("Cannot resolve host " ^ hostname)
      | e ->
          raise e
    )
