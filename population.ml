
open Sys
open Query

let (|>) v f = f v

let read_args () = 
  let input_file = Sys.argv.(1) in 
  let rows = int_of_string Sys.argv.(2) in 
  let cols = int_of_string Sys.argv.(3) in 
  let l = int_of_string Sys.argv.(4) in 
  let b = int_of_string Sys.argv.(5) in 
  let r = int_of_string Sys.argv.(6) in 
  let t = int_of_string Sys.argv.(7) in 
  (input_file, rows, cols, l, b, r, t)

type groupseq = Query.group Sequence.S.t

let slow_precompute (groups: groupseq) ((rows,cols):int*int) :
        int * (groupseq * (int*int) * Query.area) = 
  let us_area = Query.encompassing_area groups in
  let us_pop = Query.population_search groups us_area in 
  (us_pop, (groups, (rows,cols), us_area))

	   
let slow_compute (us_pop, (groups, (rows,cols), us_area)) (l,b,r,t) = 
     let query = Query.latlon_of_rowcol us_area (rows,cols) (l,b,r,t) in
     Query.population_search groups query 

let fast_precompute (groups: groupseq) ((rows,cols):int*int) =
  let us_area = Query.encompassing_area groups in
  let us_pop = Query.population_search groups us_area in 
  let summed_areas = Query.precompute groups us_area (rows,cols) in 
  (us_pop, summed_areas)

let fast_compute (us_pop, summed_areas) (l,b,r,t) =
      Query.population_lookup summed_areas (l,b,r,t)

let measure_performance name
    (precompute: groupseq -> int*int -> int * 'a)
    (compute: int * 'a -> (int*int*int*int) -> int)
    (groups: groupseq)
    (rowscols: int*int)
    (l,b,r,t)  : unit =
  (* try*)
  let (us_pop, bundle) = 
       Sequence.Acc.reporting (name^":precompute")
         (precompute groups) rowscols in
  let pop = 
       Sequence.Acc.reporting (name^":compute")
          (compute (us_pop, bundle)) (l,b,r,t) in
  let perc = (float_of_int pop /. float_of_int us_pop) *. 100.0 in
  Printf.printf "%d, %.1f%%\n" pop perc

let main () = 
  if Array.length Sys.argv < 8 then 
    (print_endline "Usage: ./population.native [file] [rows] [cols] [left] [bottom] [right] [top]";
     Pervasives.exit 0)
  else 
    let (input_file, rows, cols, l, b, r, t) = read_args () in
    assert (l >= 1 && r <= cols);
    assert (b >= 1 && t <= rows);
    assert (l <= r && b <= t);
    let groups = (Parse.parse input_file Query.group_of_data) 
                  |> Array.of_list 
                  |> Sequence.S.seq_of_array in 
    measure_performance "slow"
       slow_precompute slow_compute groups 
       (rows,cols) (l,b,r,t);
    measure_performance "fast"
       fast_precompute fast_compute groups
       (rows,cols) (l,b,r,t);;

main ();;
