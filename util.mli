val read_whole_file : string -> string
val split_words : string -> (string*int) list

(* take up to the first n elements of a list *)
val take : 'a list -> int -> 'a list

type document = {id : int; title : string; contents : string}

(* Computes word vectors for a set of documents. The given file should
 * contain a list of documents: one per line. Each document is of the
 * format: "id @ title @ body" such that '@' does not appear in the title
 * or contents. You could potentially use map-reduce to compute these
 * word vectors *)
val load_documents : string -> document array
