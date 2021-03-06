(*
   Test suite for the Jobqueue module/library.
*)

open Printf
open Lwt

(* Tests *)

let sleep t = ignore (Unix.select [] [] [] t)

let test_pid () =
  let q = Jobqueue.create () in
  let parent_pid = Unix.getpid () in
  Lwt_main.run (
    Jobqueue.submit q (fun () ->
      Unix.getpid ()
    )
    >>= function
    | `Value child_pid ->
        assert (Unix.getpid () = parent_pid);
        assert (child_pid <> parent_pid);
        return ()
    | _ ->
        assert false
  )

let test_order () =
  let main () =
    let q = Jobqueue.create ~max_running:2 () in
    let order =
      let n = ref 0 in
      fun () -> incr n; !n
    in
    let job1 () = sleep 0.2 in
    let job2 () = sleep 0.5 in
    let job3 () = sleep 0.1 in
    let job4 () = sleep 0.1 in
    let submit job =
      Jobqueue.submit q job >>= function
      | `Value () ->
          return (order ())
      | _ ->
          assert false
    in
    (* Submit the jobs in this specific order. *)
    let x1 = submit job1 in
    let x2 = submit job2 in
    (* Queue is now full, job3 will have to wait. *)
    let x3 = submit job3 in
    (* job4 should start after job3. *)
    let x4 = submit job4 in
    Lwt_list.map_p (fun x -> x) [x1; x2; x3; x4]
  in
  let result = Lwt_main.run (main ()) in
  (* Check order of arrival. Jobs 3 and 4 should both finish before job 2. *)
  assert (result = [1; 4; 2; 3])

let test_timeout () =
  let main () =
    let q = Jobqueue.create ~max_running:5 () in
    let job () = sleep 0.11 in
    Jobqueue.submit ~timeout:0.1 q job >>= function
    | `Timeout -> return ()
    | `Value _ -> assert false
    | `User_exception _ -> assert false
    | `Error s ->
        eprintf "Error: %s\n%!" s;
        assert false
  in
  Lwt_main.run (main ())

let test_values () =
  let main () =
    let q = Jobqueue.create ~max_running:5 () in
    let job () =
      Array.init 3 (fun i -> i)
    in
    Jobqueue.submit ~timeout:0.1 q job >>= function
    | `Value [| 0; 1; 2 |] -> return ()
    | `Value _ -> assert false
    | `Timeout -> assert false
    | `User_exception _ -> assert false
    | `Error _ -> assert false
  in
  Lwt_main.run (main ())

let test_exceptions () =
  let main () =
    let q = Jobqueue.create ~max_running:5 () in
    let job () = failwith "this is a test" in
    Jobqueue.submit ~timeout:1. q job >>= function
    | `User_exception _ -> return ()
    | `Value _ -> assert false
    | `Timeout -> assert false
    | `Error _ -> assert false
  in
  Lwt_main.run (main ())

let test_map () =
  let main () =
    let q = Jobqueue.create ~max_running:2 () in
    Jobqueue.map q [0; 1; 2; 3; 4; 5] (fun x -> x * x) >>= fun l ->
    return (List.map Jobqueue.value_exn l)
  in
  assert (Lwt_main.run (main ())
          = [0; 1; 4; 9; 16; 25])

(*
   Go over the default limit of 1024 file descriptors per process to
   check we're not leaking any.
*)
let test_many_jobs () =
  let num_todo = 2000 in
  let main () =
    let q = Jobqueue.create ~max_running:4 () in
    let inputs = Array.(to_list (init num_todo (fun i -> i))) in
    Jobqueue.map q inputs (fun i ->
      printf "I am job %i, process %i.\n%!" i (Unix.getpid ())
    ) >>= fun l ->
    ignore (List.map Jobqueue.value_exn l);
    return ()
  in
  Lwt_main.run (main ())

(*
   Avoid having too many items into the queue at the same time.
*)
let test_throttling () =
  let input_list = [1; 2; 3; 4; 5; 6; 7; 8; 9; 10] in
  let inputs = Lwt_stream.of_list input_list in
  let max_running = 2 in
  let max_pending = 3 in
  let q = Jobqueue.create ~max_running () in
  let print_stats () =
    printf "pending: %i, running: %i\n%!"
      (Jobqueue.pending q) (Jobqueue.running q)
  in
  let done_ = ref 0 in
  let rec consume_inputs previous_jobs =
    print_stats ();
    assert (Jobqueue.pending q <= max_pending);
    assert (Jobqueue.running q <= max_running);
    if Jobqueue.pending q < max_pending then
      Lwt_stream.get inputs >>= function
      | None -> return ()
      | Some x ->
          let job =
            Jobqueue.submit q (fun () -> sleep 0.001) >>= fun result ->
            incr done_;
            consume_inputs previous_jobs
          in
          Lwt.join [job; consume_inputs previous_jobs]
    else
      previous_jobs
  in
  Lwt_main.run (consume_inputs (return ()));
  assert (!done_ = List.length input_list)

let jobqueue_suite = [
  "pid", `Quick, test_pid;
  "order", `Quick, test_order;
  "timeout", `Quick, test_timeout;
  "values", `Quick, test_values;
  "exceptions", `Quick, test_exceptions;
  "map", `Quick, test_map;
  "many jobs", `Quick, test_many_jobs;
  "throttling", `Quick, test_throttling;
]

let suites = [
  "Jobqueue", jobqueue_suite;
]

let () =
  Printexc.record_backtrace true;
  Alcotest.run "jobqueue" suites
