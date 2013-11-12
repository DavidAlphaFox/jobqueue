open Printf

type t = {
  year : int;
  month : int;
  day : int;
  string : string;
}

let invalid label value =
  invalid_arg (sprintf "Util_dateonly.create: invalid %s %s" label value)

let is_leap_year year =
  year mod 4 = 0 && not (year mod 100 = 0)
  || year mod 400 = 0

let create ~year ~month ~day =
  let valid =
    day >= 1 &&
    match month with
    | 1 | 3 | 5 | 7 | 8 | 10 | 12 -> day <= 31
    | 2 when is_leap_year year -> day <= 29
    | 2 -> day <= 28
    | 4 | 6 | 9 | 11 -> day <= 30
    | _ -> invalid "month" (string_of_int month)
  in
  if not valid then
    invalid "month-day" (sprintf "%i-%i" month day);
  let string =
    (* RFC 3339 "date" *)
    sprintf "%04d-%02d-%02d" year month day
  in
  {
    year; month; day;
    string;
  }

let of_string s =
  Scanf.sscanf s "%d-%d-%d"
    (fun year month day -> create ~year ~month ~day)

let of_string_opt s =
  try Some (of_string s)
  with _ -> None

let to_string x = x.string

let wrap = of_string
let unwrap = to_string

let test_conversions () =
  let conv s = to_string (of_string s) in
  assert (conv "-1999-07-24" = "-1999-07-24");
  assert (conv "252525-12-31" = "252525-12-31");
  assert (conv "2525-01-31" = "2525-01-31");
  assert (of_string_opt "1900-02-29" = None);
  assert (of_string_opt "1904-02-29" <> None);
  assert (of_string_opt "2000-02-29" <> None);
  assert (of_string_opt "2001-02-29" = None);
  true

let tests = [
  "conversions", test_conversions;
]