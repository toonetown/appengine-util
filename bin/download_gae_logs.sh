############
# Downloads appengine logs for all versions and zips them up (if you specify an output that ends in .gz)
#
#!/bin/bash
OUTPUT="$( echo "${1}" | sed -e 's/\.gz$//g')"
O_OUTPUT="${1}"
[ $# -gt 0 ] && shift

if [ -z "${OUTPUT}" ]; then
    echo "Usage: $0 <outputfile> [appcfg-opts...]"
    echo ""
    echo "You can specify a different APPCFG script to use.  Default is"
    echo "script_appcfg.sh"
    exit 1
fi

APPCFG="${APPCFG:-script_appcfg.sh}"
VERSIONS="$(${APPCFG} $@ list_versions | sed -En "s/^default: \[(.*)\]$/\1/p" | sed -E "s/[',]//g")"
[ -n "${VERSIONS}" ] || { ${APPCFG} help request_logs; exit 1; }

rm -f "${OUTPUT}"
for v in ${VERSIONS}; do
    echo "====================="
    echo "Fetching for version '${v}'..."
    echo "====================="
    ${APPCFG} -V ${v} $@ -a request_logs "${OUTPUT}" || exit $?
done
if [ "${OUTPUT}" != "${O_OUTPUT}" ]; then gzip "${OUTPUT}" || exit $?; fi
