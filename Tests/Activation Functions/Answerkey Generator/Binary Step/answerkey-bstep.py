import sys
import pandas as pd                     # used for reading excel files
from argparse import ArgumentParser

#argparser = ArgumentParser()
#argparser.add_argument('input_file', help='Input filename')

#args = argparser.parse_args(sys.argv[1:])

#filename = args.input_file
#print(filename)

answers = []
dataset = []
padding = 8

# read excel file and extract data 
# note that the extracted data is in hexadecimal format
excel_data = pd.read_excel(r'../Input_Dataset.xlsx')
dataset_raw = excel_data['Input Data'].values

#s1 = pd.DataFrame(data, columns=['product_name'])
#s2 = pd.DataFrame(data, columns=['product_name']) # comment out this line if you need two operands

# converts raw hex data to decimal
for data_raw in dataset_raw:
    data = int(data_raw, base=16)
    dataset.append(data)

# format answer
for data in dataset:                                # f(x) = 0 if x < 0, 1 if x > 0
    if data >= 0:
        answer_raw = 1
    else:
        answer_raw = 0

    answer_final = f"{answer_raw:0{padding}}"       # ensures that the hex answer is formatted to have 8 digits
    answers.append(answer_final)

# write answer to answerkey file
with open('answerkey-bstep.mem', 'w') as f:
    for answer in answers:
        f.write(answer)
        f.write("\n")