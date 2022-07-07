# learning_fpga
Project containing tests for learning FPGA/VHDL. 
## Hardware
![used board](doc/board.jpg?raw=true)
 * FPGA chip: EP4CE6E22C8N. ([datasheet in mouser](https://www.mouser.es/datasheet/2/612/cyiv-51001-1299459.pdf))
 * Dev board: Cyclone IV. "RZ EasyFPGA A2.2" ([banggood link](https://www.banggood.com/es/ALTERA-Cyclone-IV-EP4CE6-FPGA-Development-Board-Kit-Altera-EP4CE-NIOSII-FPGA-Board-and-USB-Downloader-Infrared-Controller-p-1622523.html), with information in chineese)
## Software
 * Intel Quartus FPGA Lite 21.1 ([download link](https://www.intel.com/content/www/us/en/software-kit/684215/intel-quartus-prime-lite-edition-design-software-version-21-1-for-linux.html))
## links
 * compatible code related interesting projects
   * [VGA using same board](https://github.com/fsmiamoto/EasyFPGA-VGA)
   * [Some Translations of the chineese information and examples for the board, in Verilog](https://github.com/jvitkauskas/Altera-Cyclone-IV-board-V3.0)
   * [Information in Portuguese, with example in vhdl](https://github.com/filippovf/KitEasyFPGA)
## Demos:
### [Driving 4 multiplexed 7 segment digits with alphanumeric characters, with scroll](https://github.com/naelolaiz/learning_fpga/tree/main/7segments/text)
![What it looks like](7segments/text/doc/scrolling_long_text.gif)
![RTL view](7segments/text/doc/RTL_view.png)
## Log:
- Learn VHDL (in progress)
  - [x] hello world: blinking led (+keyboard) : https://github.com/naelolaiz/learning_fpga/tree/main/blink_led
  - [x] driver for 7 segments display
    - [x] basic handling and mux for 4 digits on a simple counter: https://github.com/naelolaiz/learning_fpga/tree/main/7segments/counter
    - [x] extended handling with alphanumeric chars, strings and scrolling: https://github.com/naelolaiz/learning_fpga/tree/main/7segments/text
    - (in progress) simple clock application using entities for compositions: https://github.com/naelolaiz/learning_fpga/tree/main/7segments/clock
      - [x] create reusable entity for digits and connect instances in cascade.
      - [x] create reusable entity for a timer. Use it as clock for the first digit.
      - [x] create reusable entity for a time counter (instatiating a timer inside). Use it for handling the CableSelect on the multiplexed digits.
      - [x] allow two view modes HHMM/MMSS. Change it with a button.
        - [x] use a debouncer for the button (this is the only code that is not mine. It is copied from https://nandland.com/project-4-debounce-a-switch/). I copied it because I knew that it was there, and I was focused on other functionalities. TODO: create my own version.
      - [x] allow setting the time by increasing the numbers with a second button.
        - [x] the speed should be fast, and should depend on the current view mode.
      - [x] allow setting the time by decreasing the numbers with a third button. Update digit entity accordingly.
      - [x] make the middle dot on the second display to blink. At different intervals depending on the view mode (0.5 sec to change state -period 1hz- for HHMM, 0.25 ? sec to change state in MMSS)
        - TODO: cleanup code. I created this separated branch to test different things, but now the code is a bit messy...
      - [x] create VariableTimers.
        - [x] create serial configuration port
      - [x] add alarm
        - make alarm sound intermitent
	  - make alarm sound 20 seconds
	- use fourth unused button for switching to a new mode: set alarm
      - TODO: 
        - milliseconds view
        - improve set time interface (dynamic speed for increasing/decreasing time)
        - cleanup
        - simplify code to remove redundant timers
 - [x] create a CI github action to compile a vhdl file with ghdl : https://github.com/naelolaiz/learning_fpga/blob/main/.github/workflows/ci.yml
   - TODO: make other vhdl files compatible. At least " Clock" (they don't currently compile because of missing configurations and probably different standards used?)
  - TODO:
    - create a simple game with the buttons and the 7 segments display (snake / space invaders)
      - learn how to generate random numbers with the FPGA
    - create a vga text driver
      - adapt 7 segment created entities to use VGA as display (clock, game, ...)
    - create an i2s driver
      - create / find a FFT implementation to
        - create a spectral analyzer (i2s, fft, vga)
        - (+IFFT, +DSP algorithms) create an FX/DSP module
          - (+bluetooth/BLE driver) extend module with wireless audio
- Learn Verilog (TODO)
