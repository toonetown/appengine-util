####################
# A shell script which adds password functionality (for scripting, using expect) to appcfg.sh.  This can be a drop-in
# replacement for appcfg.sh, but adds the option "-P <password>".  You can specify "-" to read the password from stdin.
# An appropriately-generated app-dir will be created if needed, you can skip that by passing "--no_appdir" as an option
#
#!/bin/bash

OPTS=()
PASSWORD=""

# Parse out all the options - until we hit a command
while [ $# -gt 0 ]; do
    case "${1}" in
    
    "help" | "download_app" | "version") 
        NEEDS_APP_DIR="no"; break
        ;;
    "request_logs" | "rollback" | "start_module_version" | \
    "stop_module_version" | "update" | "update_indexes" | \
    "update_cron" | "update_queues" | "update_dispatch" | \
    "update_dos" | "set_default_version" | "cron_info" | \
    "resource_limits_info" | "vacuum_indexes" | "list_versions" | \
    "delete_version") 
        NEEDS_APP_DIR="yes"; break
        ;;
    "-P")
        shift
        if [ "${1}" == "-" ]; then echo -n "Password : "; read -s PASSWORD; echo ""; else PASSWORD="${1}"; fi
        shift
        ;;
    "--no_appdir")
        NO_APPDIR="yes"; break
        ;;
    *)
        OPTS+=("${1}"); shift
        ;;
    esac
done

# Get the command
CMD="${1}"; if [ $# -gt 0 ]; then shift; fi

# Create a stub APP_DIR if it is needed (and we can)
PARAMS=()
if [ "${NEEDS_APP_DIR}" == "yes" -a -z "${NO_APPDIR}" ]; then
    APP_DIR="${TMPDIR}/script_appcfg.$$"
    trap 'rm -rf "${APP_DIR}"' EXIT

    mkdir -p "${APP_DIR}/WEB-INF" || exit $?
    cat << EOF > "${APP_DIR}/WEB-INF/appengine-web.xml" || exit $?
<?xml version="1.0" encoding="utf-8"?>
<appengine-web-app xmlns="http://appengine.google.com/ns/1.0" 
                   xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" 
                   xsi:schemaLocation="http://appengine.google.com/ns/1.0">
    <application></application>
    <version></version>
    <threadsafe>true</threadsafe>
</appengine-web-app>
EOF
    cat << EOF > "${APP_DIR}/WEB-INF/web.xml" || exit $?
<?xml version="1.0" encoding="UTF-8"?>
<web-app xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
	     xmlns="http://java.sun.com/xml/ns/javaee"
	     xmlns:web="http://java.sun.com/xml/ns/javaee/web-app_2_5.xsd"
	     xsi:schemaLocation="http://java.sun.com/xml/ns/javaee http://java.sun.com/xml/ns/javaee/web-app_2_5.xsd"
	     version="2.5">
</web-app>
EOF

    PARAMS+=("${APP_DIR}")
fi

# Get the parameters
while [ $# -gt 0 ]; do PARAMS+=("${1}"); shift; done

# Execute the command using expect (buffer it if we have stdbuf)
if which stdbuf &>/dev/null; then
    EXPECT="stdbuf -oL -eL expect"
    TR="tr"
else
    EXPECT="expect"
    TR="tr -u"
fi
${EXPECT} << EOT | ${TR} -d '\r'
spawn appcfg.sh ${OPTS[@]} ${CMD} ${PARAMS[@]}
while 1 {
    expect {
        -re "(\[^\r]*\)\r\n" {
            append output \$expect_out(buffer)
        }
        "Password for *" {
            append output \$expect_out(buffer)
            $([ -n "${PASSWORD}" ] && echo "send \"${PASSWORD}\\r"\")
        }
        eof {
            break
        }
    }
}
lassign [wait] pid spawnid os_error_flag value
exit \$value
EOT
exit $?
