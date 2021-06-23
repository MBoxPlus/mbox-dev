#!/bin/sh

source "${MBOX_CORE_LAUNCHER}/launcher.sh"

mbox_print_title Checking cmake
if mbox_exec brew ls --versions cmake; then
    echo "cmake installed."
else
    mbox_print_error "cmake is not installed."
    exit 1
fi
