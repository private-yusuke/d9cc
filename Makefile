SRCS=$(wildcard *.d)
d9cc: $(SRCS)
	dmd -of=d9cc $(SRCS)

debug: $(SRCS)
	dmd -debug -of=d9cc-debug $(SRCS)

test: d9cc
	./test.sh

clean:
	rm -f d9cc d9cc-debug *.o *~ tmp*
