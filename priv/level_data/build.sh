#!/bin/bash

# run with docker: docker run --rm -v $PWD:/app mspgcc /app/build.sh

set -e

CC=msp430-gcc

cd "$(dirname "$0")"

# shared lib
$CC -std=gnu99 -g -O0 -Wall -Werror -mmcu=msp430g2553 -I./lib -c lib/lib.c -o /tmp/lib.c.o -fdata-sections -ffunction-sections

for cfile in *.c ; do
  echo "compiling $cfile"
  ofile="/tmp/$cfile.o"
  efile="/tmp/$cfile.elf"
  hfile="$cfile.hex"
  dfile="$cfile.dump"

  $CC -std=gnu99 -g -O0 -Wall -Werror -mmcu=msp430g2553 -c $cfile -o $ofile
  $CC $ofile /tmp/lib.c.o -g -mmcu=msp430g2553 -o $efile -Xlinker --section-start -Xlinker int_section=0xff00 -Wl,--gc-sections
  msp430-objcopy -O ihex $efile $hfile
  msp430-objdump -d $efile > $dfile
done
