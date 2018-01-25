# use all rules
all

# Intent lists with 4 spaces
rule 'MD007', :indent => 4

# Don't enforce line length limitations within code blocks and tables
rule 'MD013', :code_blocks => false, :tables => false

# numbered lists should have the correct order
rule 'MD029', :style => "ordered"

