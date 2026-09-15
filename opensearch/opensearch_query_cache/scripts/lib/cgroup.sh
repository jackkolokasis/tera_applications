#!/usr/bin/env bash

setup_cgroup() {
    if [ "${DRY_RUN:-false}" != "true" ]; then
        # Remove a stale cgroup from an interrupted previous run.
        sudo cgdelete memory:memlim >/dev/null 2>&1 || true
    fi

    run_step \
        "Create cgroup" \
        sudo cgcreate \
            -a "$(whoami):sudo" \
            -t "$(whoami):sudo" \
            -g memory:memlim

    run_step \
        "Set cgroup memory limit to ${MEM_BUDGET}" \
        cgset -r memory.max="${MEM_BUDGET}" memlim

    run_step \
        "Set cgroup permissions" \
        sudo chmod o+w /sys/fs/cgroup/cgroup.procs
}

delete_cgroup() {
    if [ "${DRY_RUN:-false}" == "true" ]; then
        print_status "Delete cgroup" skip
        return 0
    fi

    sudo cgdelete memory:memlim >/dev/null 2>&1 || true
}

drop_page_cache() {
    run_step \
        "Drop page cache" \
        sudo sh -c 'echo 3 > /proc/sys/vm/drop_caches'
}
