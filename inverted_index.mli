(* inverted_index computes an inverted index for the contents of a given file, 
 * either with basic document mapping or advanced intrafile location. 
 * The filename is the given string. *)

open Sequence

module DocID: sig type t=int val compare: t -> t -> int end
type doc_id = DocID.t
               
module DMap : Map.S with type key=string

type location = doc_id * int * int
type doc_loc_index = location S.t DMap.t
                             
val make_index : Util.document S.t -> doc_loc_index

type result = {res_docid: doc_id; res_begin: int; res_end: int}
val show_result: Util.document S.t -> result -> unit
val search: doc_loc_index -> string list -> result list
						   
