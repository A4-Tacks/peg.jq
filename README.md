Parsing Expression Grammar impl for [jq-lang]

# Examples
```
$ ./example.jq
1+2
3
3*4
12
2*3+3*4
18
(1+2)*3
9
-2*3
-6
8+
jq: error (at <stdin>:6): error at 1:3 (2), expected one of "-", "[0-9]+", "\\("
$ ./example.jq
2+3*(4
jq: error (at <stdin>:1): error at 1:7 (6), expected one of "[*/]", "[+-]", "\\)"
```

Grammar Declare from `./example.jq`:

```abnf
num = "[0-9]+" / "\(" add "\)"
neg = *"-" num
mul = neg *{"[*/]" neg}
add = mul *{"[+-]" mul}
```

Grammar Style like the ABNF

# Operators
- `&` `!`: PEG lookaheads
- `$`: slice region
- `~`: quiet pattern
- `+`: prefix repeat, `>1` pattern
- `*` `1*` `*1` `2*4`: ABNF style repeat
- `"..."`: JQ regular expressions
- `@name` `@"name"`: expected operator, always pattern fail

[jq-lang]: https://github.com/jqlang/jq
