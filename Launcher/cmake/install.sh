#!/bin/sh

source "${MBOX_CORE_LAUNCHER}/launcher.sh"

mbox_print_title Checking cmake
if mbox_exec brew ls --versions cmake; then
    echo "cmake installed, skip!"
else
    mbox_print_title Installing cmake
    mbox_exe brew install cmake
fi
