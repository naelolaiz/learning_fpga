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
![driving 4 multiplexed 7 segments digits with alphanumeric characters, with scroll](7segments/text/doc/scrolling_long_text.gif)