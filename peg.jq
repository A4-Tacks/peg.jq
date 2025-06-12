import "grammar" as $grammar;

def srcpos($index):
  def x: if $index >= length then "x" else empty end;
  reduce ((.[:$index+1] | scan(".|[\\r\\n]"; "mg")), x) as $ch ([1, null, false];
    if last then .[0] += 1 | .[1] = 1 | last = false
    else .[1] += 1
    end |
    if $ch == "\n" then
      last = true
    end
  )
  | [.[0], .[1] // 1]
  ;

def find(cond; update):
  def _find: if cond | not then update | _find end;
  _find;
def not($val): $val | not;
def toset:
  if type == "array" then
    map({key: .}) | from_entries
  end
  ;

def pegparse($topname; $config):
  def expected($expected):
    .fail = true |
    if .quiet_level == 0 then
      if .i > .errpos then
        .errpos = .i | .expected = {}
      end |

      if .i == .errpos then
        .expected[$expected] = true
      end
    end
    ;
  def pop_result:
    .result[-2] += [.result[-1]] |
    .result |= .[:-1]
    ;
  def parse($pat):
    . as {$i, $result} |
    .fail = false |
    if $pat | type == "string" then
      if .trace then .log += [{attemping: $pat, at: .i}] end |
      .result += [[]] |

      parse(.grammar[$pat] // error("cannot find rule \($pat)")) |

      if .ignore_rule//{} | has($pat) then
        .result |= .[:-1]
      else
        pop_result |
        if .inline_rule//{} | has($pat) | not then
          .result[-1][-1] |= {name: $pat, members: .}
        end
      end |

      if .trace then .log += [if .fail then
        {failed: $pat, at: .i}
      else
        {matched: $pat, at: $i, to: .i}
      end] end

    elif $pat | type == "array" then
      reduce $pat[] as $pat (.;
        if .fail | not then
          parse($pat)
        end
      )

    elif $pat.keyword then
      if .src[.i:] | startswith($pat.keyword) then
        .i += ($pat.keyword | length) |
        .result[-1] += [$pat.keyword]
      else
        expected($pat.keyword | @json)
      end

    elif $pat.match then
      ((.src[.i:] | match("^(?:\($pat.match))")) as $m
      | .result[-1] += [if $m.contains|length!=0 then
        $m.captures[0].string else $m.string
      end] | .i += $m.length)
      // expected("<\($pat.match)>")

    elif $pat.look then
      .quiet_level += 1 |
      parse($pat.look) |
      .quiet_level -= 1 |

      .i = $i |
      if $pat.invert then .fail |= not end

    elif $pat.choice then
      .result += [[]] |
      .fail = true |

      reduce $pat.choice[] as $pat ([., -1]; if first.fail then
        first |= parse($pat) |
        last += 1
      end) |
      first.result[-1] += [last] |
      first |

      pop_result

    elif $pat.scope then
      .result += [[]] |
      parse($pat.scope) |
      pop_result

    elif $pat.optional then
      .result += [[]] |

      parse($pat.optional) |

      if .fail then
        .result[-2] += [null]
      else
        .result[-2] += [.result[-1]]
      end |
      .result |= .[:-1] |
      .fail = false

    elif $pat.repeat then
      .result += [[]] |

      $pat as {$repeat, $base, $to} |

      reduce range($base+0) as $_ (.;
        if .fail | not then
          parse($repeat)
        end
      ) |

      if not(.fail) and $to != null then
        if $to == true then
          find(.fail; parse($repeat))
        else reduce range($to - ($base+0)) as $_ (.;
          if .fail | not then
            parse($repeat)
          end
        ) end |
        .fail = false
      end |
      pop_result

    elif $pat.quiet then
      .quiet_level += 1 |
      parse($pat.quiet) |
      .quiet_level -= 1

    elif $pat.slice then
      parse($pat.slice) |
      .result = $result |
      .result[-1] += [.src[$i:.i]]

    elif $pat.expected then
      expected($pat.expected)

    else
      error("unknown parse declare: \($pat)")
    end |
    if .fail then .i = $i | .result = $result end
    ;

  {
    src: .,
    i: 0,
    fail: true,
    expected: {},
    errpos: 0,
    quiet_level: 0,
    result: [[]],
    log: [],
  } * $config
  | (.inline_rule, .ignore_rule) |= toset
  | if .trace then .log += [{init: .i}] end
  | parse($topname)
  | if .i != (.src | length) then .fail = true end
  ;

def pegunwrap:
  if .fail then
    .errpos as $i |
    error(
      "error at \(.src|srcpos($i)|map(tostring)|join(":")) (\($i))"
      +", expected "
      +(if .expected | length == 1 then
        .expected|keys[]
      else
        "one of \(.expected|keys|join(", "))"
      end)
    )
  end
  | .result[][]
  ;

def peggrammar:
  . as {$name} |
  .members |
  if $name == "ident" then
    first[0]
  elif $name == "number" then
    first[0] | tonumber
  elif $name == "string" then
    {keyword: first[1]}
  elif $name == "match" then
    {match: first[1]}
  elif $name == "label" then
    first[0] | if .name == "string" then
      .members[0][1] | gsub("\\\\\""; "\"")
    else
      .members[0][0]
    end
  elif $name == "repeat" then
    first |
    if last == 0 then
      {base: 1, to: true}
    elif last == 1 then
      {to: ((.[1]//empty|.[0]|peggrammar)//true)}
    elif last == 2 then
      {base: first|peggrammar}+({to:
        (.[1]//empty|(.[1][0]//empty|peggrammar)//true)
      }//{})
    else
      error
    end
  elif $name == "decl-list" then
    [first[] | peggrammar] | from_entries
  elif $name == "decl" then
    {key: first, value: last} | map_values(peggrammar)
  elif $name == "patchoice" then
    {choice: [
      (first|peggrammar),
      (.[1]|foreach range(1; length; 2) as $i (.;.; .[$i])|peggrammar),
      (.[2]//empty | {expected: .[1]|peggrammar})
    ]} |
    if .choice | length == 1 then
      .choice | if length == 1 then first end
    end
  elif $name == "patlist" then
    [first, last[] | peggrammar] |
    if length == 1 then first end
  elif $name == "patrepeat" then
    first |
    if last == 0 then
      {repeat: .[1] | peggrammar}+(first | peggrammar)
    elif last == 1 then
      first | peggrammar
    else
      error
    end
  elif $name == "patops" then
    first |
    if last == 0 then
      {look: .[1] | peggrammar}
    elif last == 1 then
      {look: .[1] | peggrammar, invert: true}
    elif last == 2 then
      {quiet: .[1] | peggrammar}
    elif last == 3 then
      {slice: .[1] | peggrammar}
    elif last == 4 then
      first | peggrammar
    else
      error
    end
  elif $name == "patatom" then
    first |
    if last == 0 then
      first | peggrammar
    elif last == 1 then
      first | peggrammar
    elif last == 2 then
      first | peggrammar
    elif last == 3 then
      {optional: .[1] | peggrammar}
    elif last == 4 then
      .[1] | peggrammar
    elif last == 5 then
      {scope: .[1] | peggrammar}
    else
      error
    end
  else
    error
  end
  ;

def pegshowtrace:
  def pos($src): . as $i | $src | srcpos($i) | map(tostring) | join(":");
  . as {$src} |
  .log[] |
  if .init then
    if .init == 0 then
      "[PEG_INPUT_START]\n\($src)\n[PEG_TRACE_START]"
    else
      "[PEG_INPUT_START] from \(.init)\n\($src)\n[PEG_TRACE_START]"
    end
  elif .attemping then
    "[PEG_TRACE] Attempting to match rule `\(.attemping)` at \(.at|pos($src))"
  elif .matched then
    "[PEG_TRACE] Matched rule `\(.matched)` at \(.at|pos($src)) to \(.to|pos($src))"
  elif .failed then
    "[PEG_TRACE] Failed to match rule `\(.failed)` at \(.at|pos($src))"
  end;

def pegdeclare:
  {
    grammar: $grammar[0],
    ignore_rule: ["_"],
    inline_rule: [],
  };

#[inputs] | join("\n")
#| pegparse("decl-list"; pegdeclare)
##| pegshowtrace # trace or gen parser
#| pegunwrap | peggrammar
