#!/usr/bin/bash
set -o nounset
set -o errtrace
#set -o pipefail
function CATCH_ERROR {
    local __LEC=$? __i __j
    echo "Traceback (most recent call last):" >&2
    for ((__i = ${#FUNCNAME[@]} - 1; __i >= 0; --__i)); do
        printf '  File %q line %s in %q\n' >&2 \
            "${BASH_SOURCE[__i]}" \
            "${BASH_LINENO[__i]}" \
            "${FUNCNAME[__i]}"
        if ((BASH_LINENO[__i])) && [ -f "${BASH_SOURCE[__i]}" ]; then
            for ((__j = 0; __j < BASH_LINENO[__i]; ++__j)); do
                read -r REPLY
            done < "${BASH_SOURCE[__i]}"
            printf '    %s\n' "$REPLY" >&2
        fi
    done
    echo "Error: [ExitCode: ${__LEC}]" >&2
    exit "${__LEC}"
}
trap CATCH_ERROR ERR

OPTIND=1
while getopts h opt; do case "$opt" in
    h)
        printf 'Usage: %q [Options]\n' "${0##*/}"
        echo 'Generate grammar tracer script'
        echo
        printf '%s\n' \
            'Options:' \
            '    -h                 show help' \
            && exit
        ;;
    :|\?)
        ((--OPTIND <= 0)) && OPTIND=1
        printf '%q: parse args failed, near by %q\n' "$0" "${!OPTIND}" >&2
        exit 2
esac done
set -- "${@:OPTIND}"
if [ $# -ne 0 ]; then
    printf '%q: unexpected arg %q\n' "$0" "$1" >&2
    exit 2
fi

hash cat jaq dirname sed

cd -- "$(command dirname -- "$0")" || exit

script_head=$(cat << \OEOF
top_rule_name=decl-list

OPTIND=1
while getopts ht: opt; do case "$opt" in
    h)
        printf 'Usage: %q [Options] <Grammar> [Input]\n' "${0##*/}"
        echo 'Trace peg.jq grammar'
        echo
        printf '%s\n' \
            'Options:' \
            '    -t <NAME>          top rule name' \
            '    -h                 show help' \
            && exit
        ;;
    t) top_rule_name=$OPTARG;;
    :|\?)
        ((--OPTIND <= 0)) && OPTIND=1
        printf '%q: parse args failed, near by %q\n' "$0" "${!OPTIND}" >&2
        exit 2
esac done
set -- "${@:OPTIND}"
if [ $# -gt 2 ]; then
    printf '%q: unexpected arg %q\n' "$0" "$1" >&2
    exit 2
fi
if [ $# -eq 0 ]; then
    printf '%q: expected a arg\n' "$0" >&2
    exit 2
fi

grammar=$1
input=${2-/dev/stdin}

jq_script=$(cat << \EOF
($input_grammar
| pegparse("decl-list"; pegdeclare)
| pegunwrap
| peggrammar
) as $grammar
| $input
| if $grammar | has($top) | not then
    "Invalid rule name: `\($top)`, expected:\n\(
        $grammar|keys|map("    \(.)\n")|add
    )" | halt_error(1)
end
| pegparse($top; {$grammar, trace: true})
| pegshowtrace, (pegunwrap|empty)
EOF
)

exec jaq "$peg_jq"$'\n'"$jq_script" \
    -Rnr \
    --rawfile input_grammar "$grammar" \
    --argjson grammar "[$peg_grammar]" \
    --arg top "$top_rule_name" \
    --rawfile input "$input"
OEOF
)

peg_grammar=$(jq -c . ./grammar.json)
peg_jq=$(sed '/^import/d' ./peg.jq)

cat << OEOF
#!/bin/bash

: << EOF
$(< LICENSE)
EOF

${peg_grammar@A}
${peg_jq@A}

$script_head
OEOF
