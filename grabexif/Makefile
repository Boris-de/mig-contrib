CC = gcc
applications = grabexif

all: $(applications)

CFLAGS=-Wall -g

grabexif: src/grabexif.c
	$(CC) $(CFLAGS) -o $@ $<

install:
	cp grabexif /usr/local/bin

clean:
	rm -f $(applications)
