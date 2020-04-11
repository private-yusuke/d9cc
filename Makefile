SRCS=$(wildcard *.d)
d9cc: $(SRCS)
	dmd -of=d9cc $(SRCS)

debug: $(SRCS)
	dmd -debug -of=d9cc $(SRCS)

test: d9cc
	./test.sh

clean:
	rm -f d9cc *.o *~ tmp*

# if you want to run "$ make test" after running "$make debug",
# you must first run "$ make clean".