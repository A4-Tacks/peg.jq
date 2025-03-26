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
jq: error (at <stdin>:6): error at 1:3 (2), expected one of "(", "-", <[0-9]+>
$ ./example.jq
2+3*(4
jq: error (at <stdin>:1): error at 1:7 (6), expected one of ")", <[*/]>, <[+-]>
```

Grammar Declare from `./example.jq`:

```abnf
num = <[0-9]+> / "(" add ")"
neg = *"-" num
mul = neg *{<[*/]> neg}
add = mul *{<[+-]> mul}
```

Grammar Style like the ABNF

# Operators
- `&` `!`: PEG lookaheads
- `$`: slice region
- `~`: quiet pattern
- `+`: prefix repeat, `>1` count pattern
- `*` `1*` `*1` `2*4`: ABNF style repeat
- `"..."`: case-sensitive string
- `<...>`: JQ regular expressions
- `@name` `@"name"`: expected operator, always pattern fail

# Attributes
- `ignore_rule`: ignore some rule result
- `inline_rule`: inline some rule
- `trace`: output peg trace to log, can using [pegview]

[jq-lang]: https://github.com/jqlang/jq
[pegview]: https://github.com/A4-Tacks/pegview
