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
![Original implementation](doc/wave_gen_circuit.png)

### IMPORTANT NOTES
 * The i2s reset is pulled DOWN but the waveform generator reset is pulled UP!
 * It is important to make
  * XMT pin in PCM5102 board to high (3.3V), to unmute the DAC output
  * FMT to low (0V) to use I2S protocol

### Adaptation
Looking at the table of frequencies, I decided to try 96kHz of sampling rate. Then I modified i2s_master.vhd, to make the constant MCLK_FREQ equals to 24576000, that is equals to 96000 * 256. (so, no PLL mode required)
I am using the internal Cyclone IV dev board 50MHz in pin 23, as clock for i2s_master. The phase_inc of the waveform generator is set to 2 MHz (in theory : 2 * 2**32 / 50 ) (2 MHz * bit resolution / 50MHz).

The current code is still not working properly.
### Debugging
Some previous before I saw a deformed output, I thought the bits could be inverted or something (I didn't save it with the scope. I will try to duplicate the results).
But currently I am seeing a muted signal  (small noise up to 200mV) in the DAC board output.
The I2S signals I am seeing:
#### Left/Right / Word Select
![Left/Right select (freq equals to sampling rate)](doc/LeftRight_WordSelect.png)
#### I2S data signal
![I2S data signal](doc/DataOut.png)
#### BCK / data clock
CHECK: Is it normal to not be periodic?
![Data clock](doc/BCK_DataClock.png)
![Data clock in detail](doc/BCK_DataClock_Detailed.png)
#### Master Clock
CHECK: Are the discontinuities expected?
![Master clock](doc/MasterClock.png)
![Master clock in detail - single shot capture](doc/MasterClock_Detailed_SingleShot.png)
