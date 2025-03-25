#!/bin/jq -nRf
include "peg";

def eval:
  . as {$name} |
  .members |
  if $name == "num" then
    first | # rule spaces
    if last == 0 then # choice branchs
      first | tonumber
    else
      .[1] | eval
    end
  elif $name == "neg" then
    if first | length % 2 == 1 then
      last | -eval
    else
      last | eval
    end
  elif $name == "mul" then
    reduce last[] as $rest (first|eval; if $rest[0] == "*" then
      .*($rest[1]|eval)
    else
      ./($rest[1]|eval)
    end)
  elif $name == "add" then
    reduce last[] as $rest (first|eval; if $rest[0] == "+" then
      .+($rest[1]|eval)
    else
      .-($rest[1]|eval)
    end)
  end
  ;

"
num = \"[0-9]+\" / \"\\(\" add \"\\)\"
neg = *\"-\" num
mul = neg *{\"[*/]\" neg}
add = mul *{\"[+-]\" mul}
"
| pegparse("decl-list"; pegdeclare) # parse declare
| pegunwrap
| peggrammar as $grammar
| inputs
| pegparse("add"; {$grammar}) # parse your grammar
| pegunwrap
| eval
