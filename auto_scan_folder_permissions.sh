#!/bin/bash
progName="${0##*/}"

# Global variables:
scanPath="$1"


# Print some help and custom message:
function getHelp()
{
    echo "$1" >&2
    echo "This script monitors a path for new directories and sets ACLs based on the directory's name.  It was created to autoassign permissions on shared folders automatically created by MFDs." >&2
    echo "This script must run as root, since root is the only Linux user that can change file access to users other than itself." >&2
    echo "Usage: ${progName} /path/to/monitor" >&2
    exit 1
}  # End of getHelp()

# Print stdout and send to logger:
function printILog() { echo "$1"; logger "${progName}: Info: ${1}"; }
function printELog() { echo "$1" >&2; logger "${progName}: Error: ${1}"; }


# Check for common bad arguments and print help if found:
if [ $# -ne 1 ]; then getHelp "Invalid number of arguments!"; fi
if ! [ -d $scanPath ]; then getHelp "Path argument must be a directory!"; fi
if [ "$UID" -ne 0 ]; then getHelp "Must run this as root!"; fi


#Generates message and log when program is exited
function exit_logger(){
    printILog "Terminated by sigint/sigterm, exiting!"
    exit 0
}

# Catch ctrl-c and exit gracefully:
trap exit_logger SIGINT SIGTERM


# Inotify watch given directory and loop forever:
while true; do
    while read -r userName;do
        if id "$userName" >/dev/null 2>&1; then
            if setfacl -R -m "u:${userName}:rwx,d:u:${userName}:rwx,o::---,d:o::---" "${scanPath}/${userName}";then
                printILog "ACLs for ${scanPath}/${userName} have been successfully set for user $userName"
            else
                printELog "Failed to set ACLs on \"${scanPath}/${userName}\" for user \"${userName}\""
            fi
        else
            printELog "User ${userName} was not found, removing directory ${userName}"
            rmdir --ignore-fail-on-non-empty "${scanPath}/${userName}"
        fi
    done < <(inotifywait --format '%f' -q -m -e create "$scanPath")
    printELog "Something serious going on, trying to establish watches again in 60 seconds!"
    sleep 60
done
