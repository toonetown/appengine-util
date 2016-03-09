#!/bin/bash
############
# Downloads the needed combined logs to keep a directory up-to-date - up to a maximum number of days.  Sorts and 
# separates the logs by date as well.
#
APP="$(gcloud info --format='value(config.project)')"
DIR="${1}"
MAX="${2:-7}"

if [ -z "${APP}" -o ! -d "${DIR}" -o ${MAX} -le 0 ]; then
    echo "Usage: ${0} <output-dir> [max-days]"
    echo ""
    echo "You must make sure that gcloud is set up and authenticating correctly"
    exit 1
fi

FILE_FMT="${FILE_FMT:-${APP}.%Y-%m-%d.combined.log.gz}"
LOG_DATE_FMT="\[%d/%b/%Y\(:[0-9]\{2\}\)\{3\} [-\+][0-9]\{4\}\]"

# Linux and OS X have different format for getting prior dates
if date -v-1d &>/dev/null; then 
    date_ago() { _d=${1}; shift; date -v-${_d}d "$@"; }
else
    date_ago() { _d=${1}; shift; date -d "${_d} days ago" "$@"; }
fi


# Find the last full log
for ((i=1; i<=${MAX}; i++)); do if [ -f "${DIR}/$(date_ago ${i} "+${FILE_FMT}")" ]; then break; fi; done
if [ ${i} -eq 1 ]; then echo "Already downloaded everything"; exit 0; fi
if [ ${i} -gt ${MAX} ]; then echo "Warning: Did not find any logs in the past ${MAX} days" >&2; fi

TDIR="${TMPDIR}/get-logs.$$"
mkdir -p "${TDIR}"
trap "rm -rf ${TDIR}" EXIT
LOG="${TDIR}/gae.log"

echo ""
echo "=========================="
echo "Downloading previous ${i} days worth of logs for ${APP}..."
download_gae_logs.sh "${LOG}" --days ${i} || exit $?

_a="$(echo -en '\07')"
for ((i=((${i}-1)); i>0; i--)); do
    OUT="$(date_ago ${i} "+${FILE_FMT}")"
    LOG_REGEX="$(date_ago ${i} "+${LOG_DATE_FMT}")"
    echo ""
    echo "=========================="
    echo "Extracting ${i} day(s) ago (${OUT})..."
    cat "${LOG}" | \
        grep "${LOG_REGEX}" | \
        sed -E "s|(\[[0-9a-zA-Z/]*:)([0-9]*:)([0-9]*:)([0-9]* )([-\+][0-9]{4}\])|\1${_a}\2${_a}\3${_a}\4${_a}\5|g" | \
        sort -n -t"${_a}" -k2,2 -k3,3 -k4,4 | \
        tr -d "${_a}" | \
        gzip -> "${TDIR}/in_progress"
    [ ${PIPESTATUS[1]} -eq 0 ] || { echo "No logs found for $(date_ago ${i} "+%Y-%m-%d")" >&2; exit 1; }
    mv "${TDIR}/in_progress" "${DIR}/${OUT}" || exit 1
done
