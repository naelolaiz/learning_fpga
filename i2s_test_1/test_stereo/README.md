Code copied from https://github.com/newdigate/papilio_duo_i2s/tree/master/i2s_function_generator_stereo

## Testing beats
440 Hz sinusoid in channel 1 (yellow). 450 Hz in channel 2 (pink). The white is the sum of the two.

![dual view](doc/440_450_and_sum.png)

View on X-Y

![X-Y view](doc/440_450_and_sum_xy.png)

## Resolution
The stereo version of the sine generator seems to have worst resolution for the sinusoid.
The steps can be seen, even at "low" frequencies. Here is at 3kHz:
![Steps in sine](doc/staircase.png)

In X-Y makes a nice image :)

![Steps in sine - XY view](doc/staircase_in_xy.png)
