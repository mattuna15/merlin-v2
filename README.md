# merlin-v2
Updated version of Merlin. 

Currently has 
- [x] working pipelined 68030 cpu running at 50mhz
- [x] working MFP based on MFP68901 from Motorola. I have amended this to include RX/TX fifo and configurable baud rates to improve stability and predictable results. Timers and GPIO also working
- [x] working Hyperram 32 bit memory. Upto 4 64mbit chips supported.
- [X] Flashrom read/xip using QUAD SPI. This code is being built from scratch to support the Flash Rom on digilent boards (such as Nexys Video)
- [X] CPM68k working with ramdrive and existing images
- [X] Easy68k compatible console io  
- [ ] [WIP] Integrate VGA/HDMI Controller from Merlin vga project
      
TO DO
- [ ] Keyboard, Mouse, SD Card, Network


![image](https://github.com/mattuna15/merlin-v2/assets/16086727/93461986-8602-4a06-a2a1-92b2070e981f)

