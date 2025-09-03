#!/usr/bin/bash
set -o nounset
set -o errtrace
#set -o pipefail
function CATCH_ERROR { # {{{
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
trap CATCH_ERROR ERR # }}}

OPTIND=1
while getopts h opt; do case "$opt" in
    h)
        printf 'Usage: %q [Options]\n' "${0##*/}"
        echo 'bootstarp script'
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

hash jq rm

test -f ./grammar.abnf
test -f ./grammar.json
test -f ./peg.jq

gen_proc='
[inputs] | join("\n")
| pegparse("decl-list"; pegdeclare)
#| pegshowtrace # trace or gen parser
| pegunwrap | peggrammar
'

jq -nR "$(<peg.jq)$gen_proc" ./grammar.abnf > grammar_oldgen.json

mv grammar.json grammar_old.json
mv grammar_oldgen.json grammar.json

jq -nR "$(<peg.jq)$gen_proc" ./grammar.abnf > grammar_newgen.json

diff grammar.json grammar_newgen.json

rm grammar_newgen.json
