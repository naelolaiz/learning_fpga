#!/usr/bin/python

#import math
#table_size = 16
# first element (integer) includes sign.
#angle_q_size = (3,5)
#output_q_size = (2,6)
#float_angles = [ 2 * math.pi * t / table_size for t in range(table_size) ]
#sinTable     = [ bin(round(math.sin(angle) * (2**output_q_size[1])) & (2**sum(output_q_size)-1)) for angle in float_angles ]
#cosTable     = [ bin(round(math.cos(angle) * (2**output_q_size[1])) & (2**sum(output_q_size)-1)) for angle in float_angles ]
#q_angles     = [ round(angle * (2**angle_q_size[1])) for angle in float_angles ]
#print(list(zip(q_angles, sinTable, cosTable)))

#import math
#table_size = 16
#float_angles = [ 2 * math.pi * t / table_size for t in range(table_size) ]
#sinTable=[math.sin(angle) for angle in float_angles]
#cosTable=[math.cos(angle) for angle in float_angles]
#
#sinProductTables = []
#cosProductTables = []
#for trigOutIndex in range(len(sinTable)):
#    sinProductTable = []
#    cosProductTable = []
#    for i in range(2, 16):  # skip trivial 0 and 1
#        sinProductTable.append(format(round(sinTable[trigOutIndex] * i) & 0x1F, '05b')) # max value is +/-1 * 15
#        cosProductTable.append(format(round(cosTable[trigOutIndex] * i) & 0x1F, '05b'))
#    sinProductTables.append(sinProductTable)
#    cosProductTables.append(cosProductTable)
##print(list(zip(float_angles,sinTable,cosTable)))
#print(sinProductTables)
#print(cosProductTables)

import math
bits_for_table_size = 5               # max value of sin : 0x1F. we calculate only until PI/2
bits_for_multiplication_table_lut = 4 # hexadecimal table of multiplication (to apply per nibble)

normalized_output_bits_for_unsigned_output = bits_for_table_size + bits_for_multiplication_table_lut # 9 bits for unsigned output

table_size = 2**bits_for_table_size
max_value_for_trig_output = table_size-1
multiplication_table_size = 2**bits_for_multiplication_table_lut
max_value_for_multiplication_table = multiplication_table_size-1

float_angles = [ (math.pi / 2) * t / table_size for t in range(table_size) ]
sinTableFloat=[math.sin(angle) for angle in float_angles]
#sinTable=[round(math.sin(angle) * 2**(normalized_output_bits_for_unsigned - bits_for_multiplication_table_lut)) for angle in float_angles]

sinProductTables = []
for sinFloat in sinTableFloat:
    sinProductTable = []
    for i in range(0, multiplication_table_size):
        sinProductTable.append(format(round(sinFloat * i * (2**(normalized_output_bits_for_unsigned_output - bits_for_multiplication_table_lut) -1)), '0{}x'.format(math.ceil(normalized_output_bits_for_unsigned_output/4)))) # 4 bits per nibble. We want to save numbers as nibbles. Here we left 3 MSBits unused per number (12 bit storing 9 bit numbers)
        #sinProductTable.append(format(round(sinFloat * i) & (2**normalized_output_bits_for_unsigned - 1), '02x')) 
    #bytearray([1,2,3,4][::-1]).hex()
    sinProductTables.append(sinProductTable)


for table in sinProductTables:
    print ("".join(table[::-1]))


#print(sinProductTables)
#print(float_angles)
#print(sinTable)
