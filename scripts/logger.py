#!/usr/bin/env python

import logging
import sys
import os


def setup_logging(name=None, logfile=False):

    global args
    global conf

    try:
        if args.verbosity > 1:
            log_level = logging.DEBUG
        else:
            log_level = logging.INFO
    except NameError:
        log_level = logging.DEBUG

    log_format = logging.Formatter(logging.BASIC_FORMAT)

    if name:
        log = logging.getLogger("-".join([__name__, name]))
    else:
        log = logging.getLogger(__name__)

    slh = logging.StreamHandler(sys.stdout)
    slh.setFormatter(log_format)
    slh.setLevel(log_level)

    log.addHandler(slh)

    # secondary logging to a file, always DEBUG level
    if logfile:
        fn = os.path.join(conf.logdir, "%s.log" % name)
        flh = logging.FileHandler(fn)
        flh.setFormatter(log_format)
        flh.setLevel(logging.DEBUG)
        log.addHandler(flh)

    return log
