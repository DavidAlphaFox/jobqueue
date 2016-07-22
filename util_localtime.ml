open Printf

type t = {
  year : int;
  month : int;
  day : int;
  hour : int;
  min : int;
  sec : float;
  string : string;
}

let invalid label value =
  invalid_arg (sprintf "Util_localtime.create: invalid %s %s" label value)

let invalid_int label n =
  invalid label (string_of_int n)

let create ~year ~month ~day ~hour ~min ~sec =
  if month < 1 || month > 12 then
    invalid_int "month" month;
  if day < 1 || day > 31 then (* TODO: check for months shorter than 31 days *)
    invalid_int "day" day;
  if hour < 0 || hour > 23 then
    invalid_int "hour" hour;
  if min < 0 || min > 59 then
    invalid_int "min" min;
  if not (sec >= 0. && sec < 60.) then
    invalid "sec" (sprintf "%g" sec);
  let string =
    (* RFC 3339 timestamp - without timezone suffix *)
    sprintf "%04d-%02d-%02dT%02d:%02d:%06.3f"
      year month day hour min sec
  in
  {
    year; month; day; hour; min; sec;
    string;
  }

let set_time ?hour ?min ?sec x =
  let hour =
    match hour with
    | None -> x.hour
    | Some h -> h
  in
  let min =
    match min with
    | None -> x.min
    | Some h -> h
  in
  let sec =
    match sec with
    | None -> x.sec
    | Some h -> h
  in
  if hour < 0 || hour > 23
     || min < 0 || min > 59
     || not (sec >= 0. && sec < 60.) then
    invalid_arg "Util_localtime.set_time";

  { x with hour; min; sec }

let of_string s =
  Scanf.sscanf s "%d-%d-%dT%d:%d:%f"
    (fun year month day hour min sec ->
       create ~year ~month ~day ~hour ~min ~sec)

let of_string_opt s =
  try Some (of_string s)
  with _ -> None

let to_string x = x.string

let wrap = of_string
let unwrap = to_string

let of_pair date time =
  create
    ~year: date.Util_dateonly.year
    ~month: date.Util_dateonly.month
    ~day: date.Util_dateonly.day
    ~hour: time.Util_timeonly.hour
    ~min: time.Util_timeonly.min
    ~sec: time.Util_timeonly.sec

let dateonly {year; month; day} =
  Util_dateonly.create ~year ~month ~day

let timeonly {hour; min; sec} =
  Util_timeonly.create ~hour ~min ~sec

let to_pair x =
  (dateonly x, timeonly x)

(*
   1.3 -> 0.3
   -1.3 -> 0.7
*)
let fpart x =
  x -. floor x

let of_unix_tm x subsecond =
  if not (subsecond >= 0. && subsecond < 1.) then
    invalid_arg ("Util_localtime.of_unix_tm: out-of-range subsecond "
                  ^ string_of_float subsecond);
  let open Unix in
  create
    ~year: (1900 + x.tm_year)
    ~month: (1 + x.tm_mon)
    ~day: x.tm_mday
    ~hour: x.tm_hour
    ~min: x.tm_min
    ~sec: (float x.tm_sec +. subsecond)

let to_unix_tm x =
  let tm = {
    Unix.tm_sec = truncate x.sec;
    tm_min = x.min;
    tm_hour = x.hour;
    tm_mday = x.day;
    tm_mon = x.month - 1;
    tm_year = x.year - 1900;
    tm_wday = 0; (* ignored by Unix.mktime *)
    tm_yday = 0; (* ignored by Unix.mktime *)
    tm_isdst = false; (* ignored by Unix.mktime *)
  } in
  (* normalize and complete missing fields *)
  let t, tm = Unix.mktime tm in
  tm, fpart x.sec

let of_float t =
  let open Unix in
  let x = gmtime t in
  of_unix_tm x (fpart t)

let to_float x =
  let t_sec =
    Nldate.since_epoch {
      Nldate.year = x.year;
      month = x.month;
      day = x.day;
      hour = x.hour;
      minute = x.min;
      second = int_of_float (floor x.sec);
      nanos = 0;
      zone = 0;
      week_day = -1;
    }
  in
  t_sec +. fpart x.sec

let test_conversions () =
  let conv s = to_string (of_string s) in
  assert (conv "1996-12-20T00:39:57Z" = "1996-12-20T00:39:57.000");
  assert (conv "12345-12-20T23:59:57.56789" = "12345-12-20T23:59:57.568");
  true

let tests = [
  "conversions", test_conversions;
]
