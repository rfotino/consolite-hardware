# Consolite Controllers

Consolite supports connecting up to 8 SNES controllers via the general purpose
input/output (GPIO) pins. The following information is only accurate for the
Mimas V2 development board with Spartan 6 FPGA. You may have to modify your
steps for any other board. I used the pinout and protocol from
http://www.gamefaqs.com/snes/916396-super-nintendo/faqs/5395 for the SNES
controllers.

I bought a pair of SNES compatible controllers on Ebay, cut off the connectors
and stripped the wires. Each controller has 5 wires bundled inside - for power,
ground, data latch, data clock, and serial data. Looking into the connector,
the pinout for these wires is as follows (credit to the above source):

 ----------------------------- ---------------------
|                             |                      \
| (1)     (2)     (3)     (4) |   (5)     (6)     (7) |
|                             |                      /
 ----------------------------- ---------------------

| Pin | Description | Color of wire in cable |
|-----|-------------|------------------------|
| 1   | Vccaux      | White                  |
| 2   | Data clock  | Yellow                 |
| 3   | Data latch  | Orange                 |
| 4   | Serial data | Red                    |
| 5   | ?           | no wire                |
| 6   | ?           | no wire                |
| 7   | Ground      | Brown                  |

Your wire colors may vary, depending on if you have OEM or aftermarket
controllers. Mine did not match the above colors, and I had to use their
positions in the connector instead.

After cutting off the connector and stripping the wires, I took 5
"break away headers" (metal pins attached to each other with plastic) and
soldered one of the controller's wires to each of the pins. From left to
right, the wires should be:

Power, Ground, Data latch, Data clock, Serial data

After wrapping the exposed wires with some electrical tape and marking a
side as the top, I plugged the new connector into the GPIO header of the
Mimas V2. The Mimas has four 6x2 headers arranged like the following:

|--------|--------|---|---|---|---|---|----|
| vccaux | ground | 1 | 3 | 5 | 7 | 9 | 11 |
|--------|--------|---|---|---|---|---|----|
| vccaux | ground | 0 | 2 | 4 | 6 | 8 | 10 |
|--------|--------|---|---|---|---|---|----|

We can plug two controllers into each of these headers with our 5-pin
connector, one on the top and one on the bottom. Obviously the connector
is plugged in so that vccaux and ground line up. The 8 players are arranged
in the following way across the four headers:

| Player 5 |   | Player 6 |   | Player 7 |   | Player 8 |
| Player 1 |   | Player 2 |   | Player 3 |   | Player 4 |

Each controller has 12 buttons, and the state of these buttons can be accessed
via an INPUT instruction. The order of INPUT indices is as follows:

6 Push Buttons: 0 through 5
8 Switches: 6 through 13
GPIO Header 1: 14 through 21
GPIO Header 2: 22 through 29
GPIO Header 3: 30 through 37
GPIO Header 4: 38 through 45
SNES Player 1: 46 through 57
SNES Player 2: 58 through 69
SNES Player 3: 70 through 81
SNES Player 4: 82 through 93
SNES Player 5: 94 through 105
SNES Player 6: 106 through 117
SNES Player 7: 118 through 129
SNES Player 8: 130 through 141

The order of the buttons for each SNES controller is as follows:

B, Y, Select, Start, Up, Down, Left, Right, A, X, L, R

For example, to get the status of the B button for player 1, I would poll the
input at index 46.
