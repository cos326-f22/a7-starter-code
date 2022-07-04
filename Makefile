OCAMLBUILD=ocamlbuild
OCBFLAGS= -no-links

# Note: on Windows, where symbolic links don't work,
# you may wish to set   OCBFLAGS= -no-links
# and then run by saying _build/main_index.native
# instead of  ./main_index.native
#
# On Mac or Linux, you can set  OCBFLAGS=

all: seq idx qpop

seq: 
	$(OCAMLBUILD) $(OCBFLAGS) test_seq.native

idx:
	$(OCAMLBUILD) $(OCBFLAGS) main_index.native

qpop:
	$(OCAMLBUILD) $(OCBFLAGS) population.native

clean:
	ocamlbuild -clean

