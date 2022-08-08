open Sequence
open Printf

type group = {pop:int; lat:float; lon:float}
type area = {left:float; right:float; top:float; bottom:float}


(* convert latitude to compensate for rectangular projection of map *)
let mercator_conv (lat: float) : float = 
  let pi = (4. *. atan 1.0) in
  let latpi = lat *. (pi /. 180.0) in 
  log ( (tan latpi) +. (1.0 /. (cos latpi)) )


(* used to build parsed data *)
let group_of_data (pop, lat, lon) : group = 
  {pop=pop; lat=(mercator_conv lat); lon=(lon)}


(* compute the row and column in the GUI given the latitude and longitude *)
let rowcol_of_latlon (area: area) (rows,cols) (lat,lon) : int*int =
  let delx = (area.right -. area.left) /. (float_of_int cols) in 
  let dely = (area.top -. area.bottom) /. (float_of_int rows) in 
  let c = int_of_float ((lon -. area.left) /. delx) in
  let r = int_of_float ((lat -. area.bottom) /. dely) in
  let c = min c (cols-1) in
  let r = min r (rows-1) in
  (r,c)


(* latitude and longitude area for a box in terms of rows and colums in the GUI
 * rows, cols:  total number of rows and columns
 * l,b,r,t:     left, bottom, right, and top of box respectively *)
let latlon_of_rowcol (area: area) (rows,cols) (l,b,r,t) : area =
  let delx = (area.right -. area.left) /. (float_of_int cols) in 
  let dely = (area.top -. area.bottom) /. (float_of_int rows) in 
  {left = area.left +. (float_of_int (l - 1)) *. delx;
   right = area.left +. (float_of_int r) *. delx;
   top = area.bottom +. (float_of_int t) *. dely;
   bottom = area.bottom +. (float_of_int (b - 1)) *. dely }


(**************************************************************************
 * Part 1
 * 
 * Find the smallest area encompassing all of the census groups.
 * i.e., the area containing all of the population of the United States
 **************************************************************************)

let closest_to_edge (r1: area) (r2: area) : area =
  {left = (min r1.left r2.left); 
   right = (max r1.right r2.right);
   top = (max r1.top r2.top);
   bottom = (min r1.bottom r2.bottom)}


let encompassing_area (groups: group S.t) : area = 
    let inf = Pervasives.infinity in 
    let ninf = Pervasives.neg_infinity in 
    S.map_reduce 
      (fun g -> {left=g.lon; right=g.lon; top=g.lat; bottom=g.lat}) 
      closest_to_edge 
      {left=inf; right=ninf; top=ninf; bottom=inf} 
      groups


(**************************************************************************
 * Part 2
 *
 * Compute the population within an area by looking at all n census groups
 * and summing their total populations using reduce
 **************************************************************************)



let contains_group (r: area) (g: group) : bool = 
  (g.lon >= r.left && g.lon < r.right) &&
  (g.lat <= r.top && g.lat > r.bottom)


let contains_area (r1: area) (r2: area) : bool = 
  (r2.left >= r1.left && r2.left < r1.right) &&
  (r2.right <= r1.right && r2.right > r1.left) &&
  (r2.top <= r1.top && r2.top > r1.bottom) &&
  (r2.bottom >= r1.bottom && r2.bottom < r1.top)


let population_search (groups: group S.t) (query: area) : int = 
  let g = 
    S.reduce (fun g1 g2 -> 
          match (contains_group query g1, contains_group query g2) with 
          | (false, false) -> {pop=0; lat=query.top; lon=query.left}
          | (true, false) -> g1 
          | (false, true) -> g2 
          | (true, true) -> {pop=g1.pop+g2.pop; lat=g1.lat; lon=g2.lon} 
             ) {pop=0; lat=query.top; lon=query.left} groups in 
  g.pop


(************************************************************************** 
 * Part 3
 *
 * Compute the population within an area by precomputing the total population
 * at each rectangle (x,y) for all groups in rectangles from (1,1) to (x,y).
 * You MUST perform this precompution using parallel prefix scans
 **************************************************************************)

(* Unless you find a different way to solve this problem, let 
 us assume that the precomputation works like this:

A) Make a 2-dimensional grid, in which each square has an integer
  for the population of that latitude-longitude square

B) Make a "summed area table", which is also a 2-dimensional
  grid of the same shape, in which each entry shows the total
  population of every positions that are further South and West
  of that grid position.

Doing part B in parallel is not too hard; use a parallel prefix scan.

Part A is easy to do by a sequential algorithm, such as S.iter
on the groups sequence; and hard to do in parallel.  This long
comment provides suggestions for an algorithm that will do it.

The assignment web page says,
 ... we will overlay a grid on top of the U.S. ...
 ... once we have this grid initialized ...

Here is some advice about structuring this grid.
We start with the input:

STATEFP,COUNTYFP,TRACTCE,BLKGRPCE,POPULATION,LATITUDE,LONGITUDE
01,001,020100,1,698,+32.464812,-086.486527
01,001,020100,2,1214,+32.482391,-086.486912
01,001,020200,1,1003,+32.478035,-086.474786
01,001,020200,2,1167,+32.466372,-086.471060

In the population.ml, function main processes this into:

groups = [(698,lat1,lon1),(1214,lat2,lon2),(1003,lat3,lon3),(1167,lat4,lon4)]

and then using rowcol_of_latlon you might get the list

groups = [(p1,r1,c1),(p2,r2,c2),(p3,r3,c3),(p4,r4,c4)]
where in this case p1=698, p2=1214, etc.

For preprocessing you'll want to build a two-dimensional grid;
suppose rows=3, cols=5,
and suppose groups= [(p1,0,2),(p2,1,0),(p3,2,1),(p4,1,0)],
then the grid will be,

0     0   p1   0   0 
p2+p4 0    0   0   0
0     p3   0   0   0

the question is, how do we create that grid from the groups?

A sequential algorithm is easy:  just initialize the matrix
to all zeros, then iterate through the groups,
incrementing the appropriate grid position for each new
population p.  In fact, I strongly recommend you start with
that algorithm, for two reasons:

(1) It's easy, and you can debug the rest of your algorithm
(2) When you've finished the rest of the assignment, you
can come back and implement the parallel version of this
algorithm, and you can use your sequential version to test it.

So, the next few paragraphs are guidance about how to do the
fancy parallel grid initialization, which you'll come back to later.

BEGINNING OF PARALLEL GRID INITIALIZATION ALGORITHM

Suppose we flatten the grid into 1 dimension as follows:

0     0   p1   0   0   p2+p4 0    0   0   0   0   p3   0   0   0

Then for each "group" (p,r,c), we can have (p,i),
where i is a 1-dim index calculated from (r,c).
  [(p0,i0); (p1,i1); (p2,i2); (p3,i3); ...; (pk,ik)]

The goal is to produce a 1-dimensional array m
such that m[i] = the sum of all the p's whose second
coordinate is equal to i.

Step 1 is to sort the input (by i, not by p) so that they
ordered by i.  I suggest parallel quicksort; see the lecture notes.
To implement the parallel "filter" function, use "flatten"
(think about it...).

Step 2 is the hard part.  The core of the problem is,
take a sequence such as 
 [ (1,2);(1,3);(1,3);(1,6) ]   with upper-bound 10,
and convert it to a sequence such as :
 [ 0; 0; 1; 2; 0; 0; 1; 0; 0; 0 ]   which has length 10

In fact, as you work on this, just think about _only_
this little example.

When you write an algorithm for this using S.reduce or S.scan, 
the hard part is that the function you use in S.reduce or S.scan must
be associative, otherwise it doesn't parallelize.  

Here's my solution (maybe you have a better one).  Given a sequence of chunks,
where each chunk is either:
*   (p,i)    meaning population p at index i
*   (p,i,s,q,j)
   meaning population p at index i;
   then sequence of populations s with length exactly (j-i-1);
   then population q at length j
Now if we have a sequence of these chunks,
we can join any adjacent two of them together.
For example,
   (p,i,s,q,j) (p',i',s',q',j')
where if j=i' then the result is    (p,i,s@(q+p')@s',q',j')
and if j<i' then the result is  (p,i,s@q@z@p'@s',q',j')
where z is a sequence of zeros, length i'-j'-1.
Call this function join_chunks; then if you reduce join_chunks
over your sorted groups sequence, you'll get the one-dimensional matrix.

(Parallel reduce only works reliably if your join_chunks function is
 associative; you really ought to prove that it is.)

Try out this "join chunks" algorithm on the groups, [(1,2);(1,3);(1,3);(1,6)],
and verify that no matter in which order you join the chunks together,
you get the same result chunk.  Then, from the final joined chunk,
see how to compute the answer  [ 0; 0; 1; 2; 0; 0; 1; 0; 0; 0 ].

In fact, you should demonstrate this for real: 
*)

let sample_groups = S.seq_of_array [|(1,2);(1,3);(1,3);(1,6)|]

let make_onedim_grid (s: (int*int) S.t) (max: int) : int S.t = 
    S.empty() (* FIXME *)

let sample_onedim = make_onedim_grid sample_groups 10;;


(* Now, from the one-dimensional matrix, you can form the two-dimensional
matrix by doing a "tabulate" over rows, and for each row
you take the appropriate slice of the 1-dim array.  For this 
you use S.split, which fortunately has work=1, span=1.

END OF PARALLEL GRID INITIALIZATION ALGORITHM *)

let precompute (groups: group S.t) (us_area: area) (rows,cols) : int S.t S.t = 
  failwith "pre: implement me"
  (* this algorithm has two parts: 
     (1) create a grid where position (r,c) has the population
         living at those coordinates
     (2) from that, create a grid where at position (r,c) you
         have the total population living south of r and west of c.
   *)
 
let population_lookup (summed_areas: int S.t S.t) (l,b,r,t) : int = 
  failwith "look: implement me"
  (* Here, "summed_areas" is the result of precompute, *)








