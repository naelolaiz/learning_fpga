# Attempt to generate a sinusoid through a PCM5102 I2S DAC board.
## Board
Item on ali-express, with information on pinout and diagram: https://es.aliexpress.com/item/32968353841.html
![Board diagram](doc/pcm5102_board_diagram.jpg)

## DAC information
 * Datasheet: https://www.ti.com/lit/ds/symlink/pcm5102.pdf
### Extracts
#### Pinout
![Chip pins](doc/pcm5102_table2_TerminalFunctions.png)

#### Clock frequencies
![Master clock frequencies related to the sampling rate frequencies](doc/pcm5102_table3_MasterClock_vs_SRs.png)


## Code
Code copied from from https://github.com/newdigate/papilio_duo_i2s.git

### Implementation
![Original implementation](doc/wave_gen_curcuit.png)

### IMPORTANT NOTES
 * The i2s reset is pulled DOWN but the waveform generator reset is pulled UP!
 * It is important to make
  * XMT pin in PCM5102 board to high (3.3V), to unmute the DAC output
  * FMT to low (0V) to use I2S protocol

### Adaptation
Looking at the table of frequencies, I decided to try 96kHz of sampling rate. Then I modified i2s_master.vhd, to make the constant MCLK_FREQ equals to 24576000, that is equals to 96000 * 256. (so, no PLL mode required)

The current code is still not working properly.
I am currently seeing in the scope:

