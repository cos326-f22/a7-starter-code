open Sequence

(* doc_id is a string, representing the document id, 
 * which will be used in the values in the index. *)
module DocID = struct type t=int let compare = compare end
type doc_id = DocID.t

(* doc_index is the basic type of index, a mapping with:
 * strings as keys
 * Sets of doc_ids as values *)

(* see https://caml.inria.fr/pub/docs/manual-ocaml/libref/Map.Make.html *)
module DMap = Map.Make(String)

(* doc_loc_index  a mapping with:
 * strings as keys
 * Sets of locations -- each location has
     doc_id:  which document this word is in
     int:  this word appears as the nth word in the file
     int:  this word starts at the nth character of the file
 *)

type location = doc_id * int * int

type doc_loc_index = (location S.t) DMap.t 

(* A web-search for a phrase (list of words) returns a list of results;
  each result indicates in which document the word appears,
  and the start-character and end-character of the phrase in the doc.
  If the phrase appears more than once in a document, then
  there is more than one result with the same doc_id. *)

type result = {res_docid: doc_id; res_begin: int; res_end: int}

let show_result (docs: Util.document S.t) {res_docid=i;res_begin=b;res_end=e} =
  let {Util.id=i';Util.title=t;Util.contents=cts} = S.nth docs i in
  let b' = max 0 (b-20) in
  let e' = min (String.length cts) (e+20) in
  let excerpt = String.sub cts b' (e'-b')  in
  (print_int i; print_string ": "; print_string excerpt; print_string "\n")


(* These methods each compute an inverted index of the specified type 
 * for the contents of a file. The filename is the given string. The
 * result is the computed inverted index. *)
(* use PSeq.map_reduce to construct your index in parallel *)
(* use DMap to create a map from words to a {D,DL}Set of document ids *)
(* Some handy functions: 
 *  Util.split_words converts document contents to a list of words 
 *  String.lowercase_ascii converts a word uniformly to lower case *)

(**** START OF SOLUTION ****)

let make_index (docs: Util.document S.t) : doc_loc_index =
   failwith "implement me"

let search (dex: doc_loc_index) (query: string list) : result list =
   failwith "implement me"
   
(* debugging framework 
let tolist s = Array.to_list (S.array_of_seq s)
let docs = S.seq_of_array (Util.load_documents "data/test_index_1000.txt")
let dex = make_index docs
let rs = search dex ["for";"a";"year"]
let _ = List.iter (show_result docs) rs
*)
