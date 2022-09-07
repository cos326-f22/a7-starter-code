module type S = sig
  type 'a t
  val tabulate : (int -> 'a) -> int -> 'a t
  val seq_of_array : 'a array -> 'a t
  val array_of_seq : 'a t -> 'a array
  val iter: ('a -> unit) -> 'a t -> unit
  val length : 'a t -> int
  val empty : unit  ->'a t
  val cons : 'a -> 'a t -> 'a t
  val singleton : 'a -> 'a t
  val append : 'a t -> 'a t -> 'a t
  val nth : 'a t -> int -> 'a
  val map : ('a -> 'b) -> 'a t -> 'b t
  val map_reduce : ('a -> 'b) -> ('b -> 'b -> 'b) -> 'b -> 'a t -> 'b
  val reduce : ('a -> 'a -> 'a) -> 'a -> 'a t -> 'a
  val flatten : 'a t t -> 'a t
  val repeat : 'a -> int -> 'a t
  val zip : ('a t * 'b t) -> ('a * 'b) t
  val split : 'a t -> int -> 'a t * 'a t
  val scan: ('a -> 'a -> 'a) -> 'a -> 'a t -> 'a t
end

(*******************************************************)
(* Sequential Sequences Based on a List Representation *)
(*******************************************************)

module ListSeq : S = struct

  type 'a t = 'a list

  let length = List.length

  let empty () = []

  let cons (x:'a) (s:'a t) = x::s

  let singleton x = [x]

  let append = List.append

  let tabulate f n =
    let rec helper acc x =
      if x = n then List.rev acc
      else helper ((f x)::acc) (x+1) in
    helper [] 0

  let nth = List.nth

  let filter = List.filter

  let map = List.map

  let reduce = List.fold_left

  let map_reduce m r b s = reduce r b (map m s)

  let repeat x n =
    let rec helper x n acc =
      if n = 0 then acc else helper x (n-1) (x::acc) in
    helper x n []

  let flatten = List.flatten

  let zip (s1,s2) = List.combine s1 s2

  let split s i =
    let rec helper s i acc =
      match s,i with
        | [],_ -> failwith "split"
        | _,0 -> (List.rev acc,s)
        | h::t,_ -> helper t (i-1) (h::acc) in
    helper s i []

  let iter = List.iter

  let array_of_seq = Array.of_list

  let seq_of_array = Array.to_list

  let scan f b s = 
    let (_,xs) = List.fold_left (fun (v,ls) e -> let r = f v e in (r,r::ls)) (b,[]) s in
    List.rev xs
end

module ArraySeq : S = struct

  type 'a t = 'a array

  let length = Array.length

  let empty () = Array.init 0 (fun _ -> raise (Invalid_argument ""))

  let singleton x = Array.make 1 x

  let append = Array.append

  let cons (x:'a) (s:'a t) = append (singleton x) s

  let tabulate f n = Array.init n f

  let nth = Array.get

  let map = Array.map

  let map_reduce (f: 'a -> 'b) (g: 'b -> 'b -> 'b) (base: 'b) (a: 'a array) : 'b =
    let n = Array.length a in
    let rec iter s i = if i=n then s else iter (g s (f (Array.get a i))) (i+1) in
    iter base 0

  let reduce g base a = map_reduce (fun x -> x) g base a

  let repeat x n = tabulate (fun _ -> x) n

  let flatten (a: 'a array array) : 'a array =
    let n = Array.length a in
    let m = map_reduce Array.length (+) 0 a in
    if m=0 then empty()
    else let rec find i = if Array.length (a.(i))>0
			  then a.(i).(0)
			  else find(i+1) in
	 let x = find 0 in
	 let b = Array.make m x in
	 let rec copy i k = if i<n
			    then let len = Array.length a.(i)
				 in (Array.blit (a.(i)) 0 b k len;
				     copy (i+1) (k+len))
			    else()
	 in copy 0 0; b
	 
  let zip (s1,s2) = tabulate (fun i -> (s1.(i),s2.(i))) (Array.length s1)

  let split s i = (Array.sub s 0 i, Array.sub s i (Array.length s - i))

  let iter = Array.iter
  let array_of_seq a = a
  let seq_of_array a = a

  let scan (f: 'a -> 'a -> 'a) (b: 'a) (s: 'a array) = 
    let u = Array.copy s in
    let n = Array.length s in 
    let rec iter i x = if i=n then ()
		       else let y = f x (u.(i))
			    in Array.set u i y; iter (i+1) y
    in iter 0 b; u

end

module ArraySeqAlt : S = struct
  type 'a t = 'a ArraySeq.t
  let tabulate = ArraySeq.tabulate
  let seq_of_array = ArraySeq.seq_of_array
  let array_of_seq = ArraySeq.array_of_seq
  let iter= ArraySeq.iter
  let length = ArraySeq.length
  let empty = ArraySeq.empty
  let cons = ArraySeq.cons
  let singleton = ArraySeq.singleton
  let append = ArraySeq.append
  let nth = ArraySeq.nth
  let map = ArraySeq.map
  let map_reduce = ArraySeq.map_reduce
  let reduce g base a = map_reduce (fun x -> x) g base a
  let flatten = ArraySeq.flatten
  let repeat = ArraySeq.repeat
  let zip = ArraySeq.zip
  let split = ArraySeq.split
  let scan= ArraySeq.scan
end       

module type SCount = sig
  module SM : S
  type cost = {work: int; span: int}
  val reset : unit -> unit
  val report: unit -> cost
  val reporting: string -> ('a -> 'b) -> 'a -> 'b
end
		       

module Accounting (M: S) : SCount =
  struct
    let work = ref 0
    let span = ref 0
    let cost i j = (work := !work + i; span := !span + j)
    let reset() = (work := 0; span := 0)
    type cost = {work: int; span: int}
    let report() = {work= !work; span= !span}
    let reporting name f x =
      let {work=w; span=s} = report() in
      let y = f x in
      let {work=w'; span=s'} = report() in
      Printf.printf "%s work=%d span=%d\n" name (w'-w) (s'-s);
      y
      
    let log n = let rec f k n = if n<=0 then k else f (k+1) (n asr 1)
		in f 0 (n-1)
    let log' a = 1 + log (M.length a)
    module SM = struct
      type 'a t = 'a M.t
      let tabulate f n = (cost n 1;
		     let s = !span in
		     let smax = ref s in
		     let z = M.tabulate (fun x -> 
				    let y = f x in
                                    smax := max (!smax) (!span);
				    span := s;
				    y) n in
		     span := !smax; z)
      let seq_of_array a = (cost (Array.length a) 1; M.seq_of_array a)
      let array_of_seq a = (cost (M.length a) 1; M.array_of_seq a)
      let iter f a = (cost (M.length a) (M.length a); M.iter f a)
      let length a = (cost 1 1; M.length a)
      let empty () = (cost 1 1; M.empty ())
      let cons x a = (cost (M.length a + 1) 1; M.cons x a)
      let singleton x = (cost 1 1; M.singleton x)
      let append a b = (cost (M.length a + M.length b) 1; M.append a b)
      let nth a i = (cost 1 1; M.nth a i)
      let map g a = (cost (M.length a) 1; 
		     let s = !span in
		     let smax = ref s in
		     let z = M.map (fun x -> 
				    let y = g x in
                                    smax := max (!smax) (!span);
				    span := s;
				    y) a in
		     span := !smax; z)
      let reduce f b a = (cost (M.length a) (log' a);
			  let s = !span in
			  let smax = ref s in
			  let f' i j = (let y = f i j in
                                    smax := max (!smax) (!span);
				    span := s;
				    y) in
			  let z = M.reduce f' b a in
			  span := !smax; z)
      let map_reduce f g b a = reduce g b (map f a)
      let flatten a = let u = M.flatten a
		      in (cost (max (M.length a) (M.length u)) (log' a); u)
      let repeat x n = (cost n 1; M.repeat x n)
      let zip (s1,s2) = (cost (M.length s1) 1; M.zip (s1,s2))
      let split a i = (cost 1 1; M.split a i)
      let scan f b a = (cost (M.length a) (log' a); 
			  let s = !span in
			  let smax = ref s in
			  let f' i j = (let y = f i j in
                                    smax := max (!smax) (!span);
				    span := s;
				    y) in
			  let z = M.scan f' b a in
			  span := !smax; z)
    end
  end

module Acc = Accounting(ArraySeq)
module S = Acc.SM
    
