
open Sequence
open Printf

module A = Accounting(ArraySeq)
module M = A.SM
	     
let _ = Random.init 17
let bench_size = 100000
let random_bound = 1000
let add_iterations = 1000

let randoms_bench = Array.init bench_size (fun i -> (Random.int random_bound) + 2 )
let lseq_bench = ListSeq.seq_of_array randoms_bench
let aseq_bench = M.seq_of_array randoms_bench

let test_seq_empty = M.seq_of_array [| |]
let test_seq_inorder = M.seq_of_array [|1;2;3;4;5|]
let test_seq_reverse = M.seq_of_array [|5;4;3;2;1|]
let test_seq_random = M.seq_of_array [|4;1;2;5;3|]


let slow_add n z = 
  let y = ref 0 in 
  for i = 1 to n do 
    y := !y + i
  done; 
  z + !y

let mapper = slow_add add_iterations
let reducer x y = mapper (x+y)


(***********************************************
 *
 * Unit tests for Sequence data structure
 *
 ***********************************************)

let assert_equal seq pseq = 
  assert (ListSeq.array_of_seq seq = M.array_of_seq pseq)

let pseq_eq ps1 ps2 = 
    (M.array_of_seq ps1) = (M.array_of_seq ps2)

let check_all fp eq results = 
  let r1 = fp test_seq_inorder in 
  let r2 = fp test_seq_reverse in 
  let r3 = fp test_seq_random in 
  assert (eq r1 results.(0));
  assert (eq r2 results.(1));
  assert (eq r3 results.(2))

let test_singleton () = 
  assert (M.array_of_seq (M.singleton 5) = [|5|])

let test_empty () = 
  assert (M.array_of_seq (M.empty ()) = [||])

let test_length_empty () = 
  assert (M.length test_seq_empty = 0)

let test_length () = 
  check_all M.length (=) [|5;5;5|]

let test_cons_empty () = 
  assert (pseq_eq (M.cons 0 test_seq_empty) (M.seq_of_array [|0|]))

let test_cons () = 
  let results = 
    [| (M.seq_of_array [|0;1;2;3;4;5|]);
       (M.seq_of_array [|0;5;4;3;2;1|]);
       (M.seq_of_array [|0;4;1;2;5;3|]); |] in  
  check_all (M.cons 0) pseq_eq results

let test_append_empty () = 
  let empty_seq = M.empty () in 
  assert (pseq_eq (M.append empty_seq empty_seq) (empty_seq));
  assert (pseq_eq (M.append empty_seq test_seq_random) (test_seq_random));
  assert (pseq_eq (M.append test_seq_random empty_seq) (test_seq_random))

let test_append () = 
  let results = 
    [| (M.seq_of_array [|1;2;3;4;5;1;2;3;4;5|]);
       (M.seq_of_array [|1;2;3;4;5;5;4;3;2;1|]);
       (M.seq_of_array [|1;2;3;4;5;4;1;2;5;3|]); |] in  
  check_all (M.append test_seq_inorder) pseq_eq results

let test_nth () = 
  check_all (fun s -> M.nth s 0) (=) [|1;5;4|];
  check_all (fun s -> M.nth s 1) (=) [|2;4;1|];
  check_all (fun s -> M.nth s 2) (=) [|3;3;2|];
  check_all (fun s -> M.nth s 3) (=) [|4;2;5|];
  check_all (fun s -> M.nth s 4) (=) [|5;1;3|]

let test_reduce_empty () = 
  assert (M.reduce (+) 0 test_seq_empty = 0);
  assert (M.reduce (+) 100 test_seq_empty = 100)

let test_reduce () = 
  check_all (M.reduce (+) 1) (=) [|16; 16; 16|]

let test_map_empty () = 
  assert (pseq_eq (M.map ((+) 1) test_seq_empty) test_seq_empty)

let test_map () = 
  let results = 
    [| (M.seq_of_array [|2;3;4;5;6|]);
       (M.seq_of_array [|6;5;4;3;2|]);
       (M.seq_of_array [|5;2;3;6;4|]); |] in
  check_all (M.map ((+) 1)) pseq_eq results

let test_mapreduce_empty () = 
  assert ((M.map_reduce (fun x -> x) (+) 99 test_seq_empty) = 99)

let test_mapreduce () = 
  check_all (M.map_reduce (fun x -> x * 2) (+) 1) (=) [|31; 31; 31|]

let test_flatten_empty () = 
  let pseq = M.singleton test_seq_empty in 
  assert (pseq_eq (M.flatten pseq) (test_seq_empty))

let test_flatten () = 
  let pseq = M.seq_of_array [|test_seq_inorder; test_seq_reverse|] in 
  assert (pseq_eq (M.flatten pseq) (M.seq_of_array [|1;2;3;4;5;5;4;3;2;1|]))

let test_repeat_empty () = 
  assert (pseq_eq (M.repeat 3 0) test_seq_empty)

let test_repeat () =
  assert (pseq_eq (M.repeat 3 5) (M.seq_of_array [|3;3;3;3;3|]))

let test_zip_empty () = 
  assert (pseq_eq (M.empty ()) (M.zip (test_seq_empty,test_seq_empty)))

let test_zip () = 
  let results = 
    [| (M.seq_of_array [|(1,1);(2,2);(3,3);(4,4);(5,5)|]);
       (M.seq_of_array [|(1,5);(2,4);(3,3);(4,2);(5,1)|]);
       (M.seq_of_array [|(1,4);(2,1);(3,2);(4,5);(5,3)|]); |] in
  check_all 
    (fun s -> M.zip (test_seq_inorder,s)) 
    pseq_eq results

let test_split () = 
  let eq' (a,b) (c,d) = (pseq_eq a c) && (pseq_eq b d) in 
  let results1 = 
    [| (M.seq_of_array [||], M.seq_of_array [|1;2;3;4;5|]);
       (M.seq_of_array [||], M.seq_of_array [|5;4;3;2;1|]);
       (M.seq_of_array [||], M.seq_of_array [|4;1;2;5;3|]); |] in 
  check_all (fun s -> M.split s 0) eq' results1;
  let results2 = 
    [| (M.seq_of_array [|1;2|], M.seq_of_array [|3;4;5|]);
       (M.seq_of_array [|5;4|], M.seq_of_array [|3;2;1|]);
       (M.seq_of_array [|4;1|], M.seq_of_array [|2;5;3|]); |] in 
  check_all (fun s -> M.split s 2) eq' results2

let test_scan_empty () = 
  assert (M.scan (+) 1 test_seq_empty = test_seq_empty)

let test_scan1 () = 
  let results = 
    [| (M.seq_of_array [|1;3;6;10;15|]);
       (M.seq_of_array [|5;9;12;14;15|]);
       (M.seq_of_array [|4;5;7;12;15|]); |] in 
  check_all (M.scan (+) 0) pseq_eq results

let test_scan2 () = 
  let results = 
    [| (M.seq_of_array [|2;4;7;11;16|]);
       (M.seq_of_array [|6;10;13;15;16|]);
       (M.seq_of_array [|5;6;8;13;16|]); |] in 
  check_all (M.scan (+) 1) pseq_eq results

(***********************************************
 *
 * Benchmarks for Sequence data structure
 *
 ***********************************************)

let timeit f x = let t = Sys.time() in let y = f x in (y, Sys.time()-.t)

let bench_reduce () = 
  let (r1,tlist) = timeit (ListSeq.reduce reducer 1) lseq_bench in 
  let (r2,tarray) = timeit (M.reduce reducer 1) aseq_bench in 
  assert (r1 = r2);
  tlist /. tarray

let bench_map () = 
  let (r1,tlist) = timeit (ListSeq.map mapper) lseq_bench in 
  let (r2,tarray) = timeit (M.map mapper) aseq_bench in 
  assert_equal r1 r2;
  tlist /. tarray

let bench_map_reduce () = 
  let (r1,tlist) = timeit (ListSeq.map_reduce mapper reducer 1) lseq_bench in 
  let (r2,tarray) = timeit (M.map_reduce mapper reducer 1) aseq_bench in 
  assert (r1 = r2);
  tlist /. tarray

let bench_scan () = 
  let (r1,tlist) = timeit (ListSeq.scan reducer 1) lseq_bench in 
  let (r2,tarray) = timeit (M.scan reducer 1) aseq_bench in 
  assert_equal r1 r2;
  tlist /. tarray


let run_tests tests bmarks = 
  let rec test_aux ts = 
    match ts with
    | [] -> ()
    | (descr, f)::tl ->
        let _ = A.reset() in
	let str = (try f () with _ -> "failed") in
	let {A.work=w; A.span=s} = A.report() in
	let s1 = "W=" ^ string_of_int w ^ ",S=" ^ string_of_int s ^ " " ^ str in
        print_endline ( descr ^ ":\t" ^ s1);
        test_aux tl
  in 
  print_endline "\nRunning Tests";
  print_endline "==============================================";
  test_aux ( List.map (fun (x,f) -> (x, fun _ -> f (); "success")) tests); 
  print_endline "==============================================\n";
  print_endline ("\nRunning Benchmarks, size: " ^ (string_of_int bench_size));
  print_endline "==============================================";
  test_aux ( List.map (fun (x,f) -> (x, fun _ -> "speedup=" ^ (string_of_float (f ()))) ) bmarks); 
  print_endline "==============================================\n"


let () = 
  let bmarks = 
    [("reduce        ", bench_reduce);
     ("map           ", bench_map);
     ("mapreduce     ", bench_map_reduce);
     ("scan          ", bench_scan) ] in

  let tests = 
    [("empty      ", test_empty);
     ("singleton  ", test_singleton);
     ("length     ", test_length_empty);
     ("length     ", test_length);
     ("cons       ", test_cons_empty);
     ("cons       ", test_cons);
     ("append     ", test_append_empty);
     ("append     ", test_append);
     ("nth        ", test_nth);
     ("reduce     ", test_reduce_empty);
     ("reduce     ", test_reduce);
     ("map        ", test_map_empty);
     ("map        ", test_map);
     ("mapreduce  ", test_mapreduce_empty);
     ("mapreduce  ", test_mapreduce); 
     ("flatten    ", test_flatten_empty);
     ("flatten    ", test_flatten);
     ("repeat     ", test_repeat_empty);
     ("repeat     ", test_repeat);
     ("zip        ", test_zip_empty);
     ("zip        ", test_zip);
     ("split      ", test_split);
     ("scan       ", test_scan_empty);
     ("scan       ", test_scan1);
     ("scan       ", test_scan2) ] in

  run_tests tests bmarks
