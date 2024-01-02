# merlin-v2
Updated version of Merlin. 

Currently has 
- [x] working pipelined 68030 cpu running at 50mhz
- [x] working MFP based on MFP68901 from Motorola. I have amended this to include RX/TX fifo and configurable baud rates to improve stability and predictable results. Timers and GPIO also working
- [x] working Hyperram 32 bit memory. Upto 4 64mbit chips supported.
- [ ] WIP Flashrom read/xip using QUAD SPI. This code is being built from scratch to support the Flash Rom on digilent boards (such as Nexys Video)

TO DO
- [ ] Integrate VGA/HDMI Controller from Merlin vga project
- [ ] Keyboard, Mouse, SD Card, Network

