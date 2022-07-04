open Sequence
open Inverted_index

let main =
  let argc = Array.length Sys.argv in 

  let usage0 = "usage: " ^ Sys.argv.(0) ^ " " in
  let usage1 = usage0 ^ "[-dump] filename [search phrase]\n" in

  let (dump,next) =
    if argc >= 2 && Sys.argv.(1) = "-dump"
    then (true,2) else (false,1) in

  if next >= argc then 
    (print_string usage1; exit 0)
  else

  let filename = Sys.argv.(next) in

  let query = Array.to_list 
          (Array.sub Sys.argv 
	    (next+1) (argc-(next+1))) in

  let docs = S.seq_of_array (Util.load_documents filename) in
  let index = Acc.reporting "make_index" make_index docs in
  if dump
  then DMap.iter (fun word seq ->
       print_string "Key: {";
       print_string word; print_string "} Values: {";
       S.iter (fun (i,w,_) ->
         print_int i; print_string ":"; print_int w; print_string " ") seq;
       print_string "}\n")
       index
  else ();
  if query<>[] then List.iter (show_result docs) 
			  (Acc.reporting "search" (search index) query)
  else ()
