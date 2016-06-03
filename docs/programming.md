# Running Programs on Consolite

This document describes how to load programs onto the board and run them. Programs
can either be loaded over a mini USB cable or via a micro SD card.

Consolite binaries are typically created using the provided
[assembler](https://github.com/rfotino/consolite-assembler). The assembly
code can either be written by hand, or you can write C-like code and compile
it with the provided [compiler](https://github.com/rfotino/consolite-compiler).
Binaries can be up to 64KiB in size. Once loaded into RAM, the processor begins
executing at memory address 0x0000.

## Loading over USB

If there is no micro SD card in the slot, Consolite will wait until it has received
64KiB of data over the UART interface has loaded the data into RAM. Data can be
sent over USB by plugging the board into your computer and simply doing

```sh
cat PROGRAM_NAME /dev/zero > /dev/ttyACM0
```

from the terminal, where `PROGRAM_NAME` is the file you are loading and `/dev/ttyACM0`
is the name of the serial port for the board. You can figure out the name of the serial
port by comparing the output of `ls /dev` before and after plugging the board into
your computer. The `/dev/zero` is for padding the output with zeros in the likely case
that the program you are loading is not exactly 64KiB.

The UART interface is only receiving at 19200 baud, since I had trouble getting it to
send any faster - that means it will take about 34 seconds to load a program. Progress
will be shown on the 7-segment display.

## Loading from Micro SD Card

The preferred way of loading programs is from the micro SD card, since this takes only
a fraction of a second and removes the reliance on an external computer when using
Consolite. Additionally, you can have up to 256 programs stored on the SD card at a time.

The micro SD card I used was a class 4 8GB SDHC card - any SDHC card should work, and
SDXC cards may work as well. Lower capacity cards (<= 2GB) won't work, as I didn't have
access to any when writing the SD card controller so I couldn't add that functionality.

The micro SD card is used as a block device, so it doesn't need any file system. After
plugging it in to your computer, you will want to unmount and possibly erase the existing
file system. Unmounting should be enough however, since our direct writing of programs
will probably destroy the file system anyway. To write a single program to the SD card,
use:

```sh
dd if=PROGRAM_NAME of=/dev/mmcblk0
```

You may need to prefix this command with `sudo`. The output file, `/dev/mmcblk0`, might be
different for your system, so you need to check the contents of `ls /dev` before and
after plugging in the card.

To load multiple programs, you should create an image file before dding it to the SD card.
First you need to pad each program to 64KiB, then concatenate them all together. Once the
programs have been concatenated, the image can be written to the SD card. Suppose we have
two files, `program1` with size 512 bytes and `program2` with size 1024 bytes:

```sh
# Pad files with 65536 - SIZE bytes
dd if=/dev/zero bs=1 count=65024 >> program1
dd if=/dev/zero bs=1 count=64512 >> program2
# Concatenate to form image
cat program1 program2 > image
# Write image to SD card, replacing /dev/mmcblk0 with your device's name
dd if=image of=/dev/mmcblk0
```

The reason the files need to be padded to a length of 64KiB is because, to find program *N*,
Consolite loads the 64KiB program starting at byte offset *N* * 64KiB. The switches on the
MimasV2 board act as an 8-bit binary number determining which program to load. If all the
switches are in the 0 position when booting up Consolite, the 0th program will be loaded;
if the switches are in the 00000001 position when booting, the 1st program will be loaded,
etc. This allows you to have 256 different programs on the SD card ready to execute.
