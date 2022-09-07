# Assignment 7: Parallel Sequences

## Quick Links

- [Preliminaries](#preliminaries)
- [Web indexing](#part-1-an-inverted-index-application)
- [US Census Population](#part-2-us-census-population)
- [Hand-in Instructions](#handin-instructions)
- [Acknowledgments](#acknowledgments)

## Introduction

In this assignment, you will use the functional map-reduce abstraction
to program a "big data" application: search engine indexing.  Parallel
functional map-reduce is used in the real world because of its
efficiency and fault-tolerance in big server farms.

To get started, run

```
git submodule update --init
```

from your git clone (the directory this README.md sits in)
to fetch data files needed to complete this assignment.

## Preliminaries

Since you probably don't have your own server farm, what to do?
Actually, it's
[easy and cheap to rent a server farm](https://aws.amazon.com/pricing/), but we
will do something else instead: use dynamic instrumentation to *estimate* the
parallelism of your program. The **`Accounting`** functor instruments a
`Sequence` implementation to measure *work* and *span* of the map-reduce
programs you run. Your grade will depend, in part, on reducing the span of your
algorithms (without increasing the work too much).

**Caveat 1:** When you perform **map** or **reduce** or **scan** (etc.) using
your own ML functions *f*, *g*, etc., the automatic instrumentation does not
measure the cost of *f* or *g* (except when they themselves do map-reduce
operations). Therefore you must take care to avoid doing lengthy sequential
computations inside the functions you pass to the map-reduce operators.

**Caveat 2:** Measurements of work versus span are not necessarily an accurate
prediction of how fast your code would run on a big server farm.

## Sequence library

The file `sequence.ml` (with interface `sequence.mli`) contains the module type
**`S`** of sequences. You can see how *work* and *span* are estimated by
inspecting **module `Accounting`**.

**Caveat:** After using `seq_of_array arr` to convert an array `arr` to a
sequence, *do not modify* `arr`.

**Caveat:** After using `let arr = array_of_seq s` to convert a sequence to an
array, *do not modify* `arr`.

The following table summarizes the most important operations in the sequence
module and their work and span complexity.

| Function | Description | Work | Span |
| ---      | ---         | ---  | ---  |
| `tabulate` | Create a sequence of length `n` where each element `i` holds the value `f(i)` | n | 1 |
| `seq_of_array` | Create a sequence from an array | 1 | 1 |
| `array_of_seq` | Create an array from a sequence | 1 | 1 |
| `iter` | Iterate through the sequence applying function `f` on each element *in order*. Useful for debugging | n | n |
| `length` | Return the length of the sequence| 1 | 1 |
| `empty` | Return the empty sequence | 1 | 1 |
| `cons` | Return a new sequence like the old one, but with a new element at the beginning of the sequence | n | 1 |
| `singleton` | Return the sequence with a single element | 1 | 1 |
| `append` | Append two sequences together.<br>`append [a0;...;am] [b0;...;bn] = [a0;...;am;b0;...;bn]` | m+n | 1 |
| `nth` | Get the `n`th value in the sequence. Indexing is zero-based. | 1 | 1 |
| `map` | Map the function `f` over a sequence | n | 1 |
| `reduce` | Fold a function `f` over the sequence. To do this in parallel, we require that `f` has type: `'a -> 'a -> 'a`. Additionally, `f` must be associative | n | log(n) |
| `mapreduce` | Combine the map and reduce operations. | n | log(n) |
| `flatten` | Flatten a sequence of sequences into a single sequence.<br>`flatten [[a0;a1]; [a2;a3]] = [a0;a1;a2;a3]` | n | log(n) |
| `repeat` | Create a new sequence of length `n` that contains only the element provided<br>`repeat a 4 = [a;a;a;a]` | n | 1 |
| `zip` | Given a pair of sequences, return a sequence of pairs by drawing a value from both sequences at each shared index. If one sequence is longer than the other, then only zip up to the last element in the shorter sequence.<br>`zip [a0;a1] [b0;b1;b2] = [(a0,b0);(a1,b1)]` | n | 1 |
| `split` | Split a sequence at a given index and return a pair of sequences. The value at the index should go in the second sequence.<br>`split [a0;a1;a2;a3] 1 = ([a0],[a1;a2;a3])`<br>This routine should fail if the index is beyond the limit of the sequence. | 1 | 1 |
| `scan` | This is a variation of the parallel prefix scan shown in class. For a sequence `[a0; a1; a2; ...]`, the result of `scan` will be:<br>`[f base a0; f (f base a0) a1; f (f (f base a0) a1) a2; ...]` | n | log(n) |

## An Inverted Index Application

The following application is designed to exercise the "Map-Reduce" style of
computation, as described in
[Google's influential paper](https://static.googleusercontent.com/media/research.google.com/en/us/archive/mapreduce-osdi04.pdf)
on their distributed Map-Reduce framework.

When implementing your index, you should do so under the assumption that your
code will be executed on a parallel machine with many cores. You should also
assume that you are computing over a large amount of data (e.g.: computing your
inverted index may involve processing many documents). Hence, an implementation
that iterates in sequence over all documents will be considered impossibly
slow&mdash;you must use bulk parallel operations such as map and reduce when
processing sets of documents to minimize the span of your computation. Style and
clarity is important too, particularly to aid in your own debugging.

As you develop your algorithms (for all parts of this assignment), you should
measure their work and span. After you import and `open` the `Sequence` module,
suppose you write a function `f: t1 -> t2` that uses use operations
`S.tabulate`, `S.map`, et cetera. You can measure work and span by invoking
`Acc.reporting "measuring:f" f x` which calls f(x) while measuring work and
span, and produces a line like,

```
measuring:f w=256 span=109
```

### Part 1: Inverted Index

An [inverted index](https://en.wikipedia.org/wiki/Inverted_index) is a mapping
from words to the document *and location within the document* in which they
appear. Read *9 Algorithms that Changed the World* chapter 2: "Search Engine
Indexing", available on reserve for this course (log into canvas.princeton.edu
for COS 326).

For example, if we started with the following documents:

Document 0:

```
OCaml, map reduce
```

Document 1:

```
::fold filter ocaml
```

The inverted index would look like this:

| word | document |
| ---  | ---      |
| ocaml | 0:0:0 1:2:14 |
| map | 0:1:7 |
| reduce | 0:2:11 |
| fold | 1:0:2 |
| filter | 1:1:7 |

For each word, there is a sequence of doc-number:word-number:char-number pairs.
For example, "ocaml" is in document 0 at word 0 (character position 0), and in
document 1 at word 2 (character position 14). To implement this type of index,
complete the `make_index` function in `inverted_index.ml`. This function should
accept a sequence of documents, and return the index. The data file is a
condensed set of documents (such as the three `data/test_index_*.txt` files
provided), one per line. Each document record has an id number, a title, and the
document's contents. To get started, investigate some of the functions in the
module `Util` (with interface `util.mli` and implementation `util.ml`). In
particular, notice that `Util` contains a useful function called
`load_documents`: use it to load a collection of documents from a file.

**Attention to detail:** The example above suggests that your inverted index
should be case insensitive (OCaml and ocaml are considered the same word). You
might find `String.lowercase_ascii` from the
[String](https://caml.inria.fr/pub/docs/manual-ocaml/libref/String.html) library
useful.

## Part 2: Phrase search

As explained in *9 Algorithms that Changed the World,* having the location-
within-document allows queries such as "foo **near** bar", meaning, "find
documents where "foo" appears within *k* words of "bar".

We will do something related: look for a string such as "for a year". That is,
find all documents where the word "for" is the *i*th word, for some *i*, and
then the (*i*+1)th word is "a" and the (*i*+2)nd word is "year". Implement a
function **`search`** that takes an index and a query (a list of strings) and
returns a list of results. A *result* has a document-number, a begin-character-
position of the phrase in that document, and an end-character-position. (To keep
things simple, let the end-character-position be the position of the *first*
character in the last word of the phrase.)

### Testing

We have provided `main.ml`, which is a driver that calls your function to
build an index from a given file, then (if you use the `-dump` option) prints
the resulting index out in string form. To run, first compile into an executable
for testing with the given `Makefile` using `make idx`. Then run the
`main` program with its first command line argument being the
datafile. Here's an example:

```
dune exec main -dump data/test_index_1.txt
Key: {'one'} Values: {'1:4', '1:3', '1:2', '1:1'}
```

Command-line arguments after the name-of-index-file are treated as a search
query; for example,

```
dune exec main data/test_index_1000.txt for a year
940: t rise in December, for a year-on-year rise of
908: ts to 96,000 tonnes for a year from March 1.
382: d not pay principal for a year and a half, the
16: il pays no interest for a year, said Joseph Ar
4: il pays no interest for a year, said Joseph Ar
```

**DO NOT** change any of the types or functors provided for you&mdash;these must
match the given interface. You may write additional functions so long as you do
not require them to be visible outside the module.

## Performance analysis

In the section of your `signature.txt` that says, "Report your work and span
numbers", fill in the ? with your actual numbers.

Then, in the section "Analyze your work and span numbers",
- Define the problem size, N (total size of the actual input to **`make_index`**
    or **`precompute`**)
- As a function of N, based on the measured work and span, and based on the
    algorithms you are using, estimate the asymptotic complexity of the work and
    span of each of these three functions. Is it quadratic, NlogN, linear, logN,
    (logN)^2, etc. ?

As you know if you took COS 226, this kind of estimate is more meaningful if you
measure on inputs of several different sizes and make a graph, but here it might
be OK to eyeball it from just one N.

## Handin Instructions

Your assignment will be automatically submitted every time you push your changes
to your GitHub repository. Within a couple minutes of your submission, the
autograder will make a comment on your commit listing the output of our testing
suite when run against your code. **Note that you will be graded only on your
changes to `inverted_index.ml`**, and not on your
changes to any other files.

You may submit and receive feedback in this way as many times as you like,
whenever you like.
