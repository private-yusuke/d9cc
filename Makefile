SRCS=$(wildcard *.d)
d9cc: $(SRCS)
	dmd -of=d9cc $(SRCS)

test: d9cc
	./test.sh

clean:
	rm -f d9cc *.o *~ tmp*