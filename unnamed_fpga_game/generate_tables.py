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
bits_for_trig_output = 4              # max value of sin : 0xF (we calculate only the positive part, then we use as negative in the code when needed)
bits_for_multiplication_table_lut = 4 # hexadecimal
float_angles = [ math.pi * t / table_size for t in range(table_size) ]
sinTable=[round(math.sin(angle) * 2**bits_for_trig_output) for angle in float_angles]

sinProductTables = []
for sin in sinTable:
    sinProductTable = []
    for i in range(2, 2**bits_for_multiplication_table_lut):  # skip trivial 0 and 1
        sinProductTable.append(format(round(sin * i) & (2**bits_for_trig_output * 2**bits_for_multiplication_table_lut -1), '08b')) # max value is +1 * 15
    sinProductTables.append(sinProductTable)
#print(list(zip(float_angles,sinTable,cosTable)))
print(sinProductTables)

