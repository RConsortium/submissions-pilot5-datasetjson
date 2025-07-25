

# the following prompts can be used to extract specific information from code

prompt_var_dat_code <- "Please review the following R code and identify the variables used, 
along with the corresponding datasets they belong to.
Provide a comma seperated text table with two columns: 
one for the variable names and the other for the associated dataset names. 
no explanation please.
Please use the initial source dataset names, don't include anything from intermediate datasets. 
only include the variables from datasets whose dataset name starting with the letter a. 
Make sure two headers are included for the two columns - Variable and Dataset"


prompt_filter_code <- "Please review the following R code and identify the filtering criteria applied. 
When outputing variable name, parsing the associated data set name and the variable name, seperated by a dot, 
and captialize all characters. Please use the initial source dataset names instead of the intermediate dataset names.
no explanation please. please ensure the condition is included. no line break please. seperate values by ; "

prompt_output_code <- "Please review the following R code and identify the output file name. 
no explanation please. please output a single file name."

prompt_parse_dat_var <- "Below is a table with two columns: the first column are variable names and the other column are the associated dataset names. 
For each row, generate one value by parsing the data set name and the variable name, seperated by a dot. 
captialize all characters. no explanation please. do not include line break please. seperate values by ; "


# compare results

prompt_compare <- "compare the two text chuncks, summarize descripencies between the two text chuncks. 
but do not highlight any formatting differences such as the use of different delimiters, punctuation, or the order of variables. 
Focus only on comparing the content of the two chunks.
If no significant difference, output NULL. no explanation if response is NULL.
do not include line break please."

# retrieve variable names
