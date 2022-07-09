# Attempt to generate a sinusoid through a PCM5102 I2S DAC board.
![One looking good 1 kHz sinusoid](doc/CenteredSine33kHz.png)
## PCM5102 Board
Item on ali-express, with information on pinout and diagram: https://es.aliexpress.com/item/32968353841.html
![Board diagram](doc/pcm5102_board_diagram.jpg)

## DAC information
 * Datasheet: https://www.ti.com/lit/ds/symlink/pcm5102.pdf
### Extracts
#### Pinout
![Chip pins](doc/pcm5102_table2_TerminalFunctions.png)

#### Clock frequencies
![Master clock frequencies related to the sampling rate frequencies](doc/pcm5102_table3_MasterClock_vs_SRs.png)


## FPGA code
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
I am using the internal Cyclone IV dev board 50MHz in pin 23, as clock for i2s_master.
The current code is still not working properly.
### Debugging
#### Left/Right / Word Select
We can confirm here that the input frequency of 24576000 Hz for the master clock correctly ended in a LRCLK frequency (=sampling rate) of 96kHz.
![Left/Right select (freq equals to sampling rate)](doc/LeftRight_WordSelect.png)
#### I2S data signal
![I2S data signal](doc/DataOut.png)
#### BCK / data clock
![Data clock](doc/BCK_DataClock.png)
![Data clock in detail](doc/BCK_DataClock_Detailed.png)
#### Master Clock
![Master clock](doc/MasterClock.png)
![Master clock in detail - single shot capture](doc/MasterClock_Detailed_SingleShot.png)
#### Some signal!
I managed to replicate a distorted waveform! I got it by sending the (16 bit) output of the waveform generator into the 16 most significant bits of the (24 bit) i2s input, instead of the 16 LSB. 
This is the waveform I get. If that is the original sinusoid distorted, the frequency I calculated previously is wrong, as we can appreciate here (3.817 kHz)

![Measuring period of DAC output](doc/DAC_with_number_in_MSB_detailed.png)

Finally! I was doing the calculations wrong:
 * I intended 2MHz in an audio application :P (to much FPGA)
 * The DAC was using the clock input as in the example (from the I2S word select signal), but then I was doing the calculations as with the 50MHz input clock.

Here is the new DAC output I get. It is still doing a strange wraparound. But it is (almost) a sinusoid, at the proper frequency!

![Now we are talking!](doc/DAC_with_number_in_MSB_1kHz.png)

I did a quick hack adding substracting an offset to make it look good. And in fact, that is basically what the [original code](https://github.com/newdigate/papilio_duo_i2s/blob/master/i2s_function_generator/circuit/shift_left_16_to_24.vhd) does.
I will do my own oscillator instead.

![One looking good 1 kHz sinusoid](doc/CenteredSine33kHz.png)
