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


# Extract Output AST
Some operator has a scope and generates a sub list

The following operations have scope
- A rule reference, e.g `a = "x" "y"`, `a`
  ```jq
  debug(.name) | .member | .[0], .[1]
  ```
- A optional, e.g `[a b]`,
  ```jq
  if . != null then .[0], .[1] end
  ```
- A choice, e.g `a b / c`, branch id in last
  ```jq
  if last == 0 then ; a b
      .[0], .[1]
  elif last == 1 then ; c
      .[0]
  end
  ```
- A scope, e.g `x {a b}`
  ```jq
  .[0], (.[1] | .[0], .[1])
  ```

- A repeat, e.g `x 2y`
  ```jq
  .[0], (.[1] | .[0], .[1])
  ```


[jq-lang]: https://github.com/jqlang/jq
[pegview]: https://github.com/A4-Tacks/pegview
