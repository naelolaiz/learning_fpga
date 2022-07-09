# Attempt to generate a sinusoid through a PCM5102 I2S DAC board.
## Board
Item on ali-express, with information on pinout and diagram: https://es.aliexpress.com/item/32968353841.html
![Board diagram](doc/pcm5102_board_diagram.jpg)

## DAC information
 * Datasheet: https://www.ti.com/lit/ds/symlink/pcm5102.pdf
### Extracts
#### Pinout
![Chip pins](doc/pcm5102_table2_TerminalFunctions.png)
![Another pinout description](doc/pcm5102_board_pinout.jpg)

#### Clock frequencies
![Master clock frequencies related to the sampling rate frequencies](doc/pcm5102_table3_MasterClock_vs_SRs.png)


## Code
Code copied from from https://github.com/newdigate/papilio_duo_i2s.git

