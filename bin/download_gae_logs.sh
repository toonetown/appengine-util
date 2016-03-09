############
# Downloads appengine logs for all versions and zips them up (if you specify an output that ends in .gz)
#
#!/bin/bash
OUTPUT="$( echo "${1}" | sed -e 's/\.gz$//g')"
O_OUTPUT="${1}"
[ $# -gt 0 ] && shift

if [ -z "${OUTPUT}" ]; then
    echo "Usage: $0 <outputfile> [gcloud-opts...]"
    exit 1
fi

VERSIONS="$(gcloud preview app modules list | sed -En 's/^default +([^ ]+) .*$/\1/p')"
[ -n "${VERSIONS}" ] || { gcloud preview app modules get-logs -h; exit 1; }

rm -f "${OUTPUT}"
for v in ${VERSIONS}; do
    echo "====================="
    echo "Fetching for version '${v}'..."
    echo "====================="
    gcloud preview app modules get-logs default "${OUTPUT}.tmp" --version "${v}" $@ || exit $?
    cat "${OUTPUT}.tmp" >> "${OUTPUT}" || exit $?
    rm -f "${OUTPUT}.tmp"
done
if [ "${OUTPUT}" != "${O_OUTPUT}" ]; then gzip "${OUTPUT}" || exit $?; fi
