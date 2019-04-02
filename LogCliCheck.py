#!/usr/bin/python
# -*- coding: utf-8 -*-

from __future__ import print_function

import sys
sys.path.append('./lib')

from FuncDriveInfo import *
from FuncLogging import logging
from FuncLogsCheck import Validator
from FuncGetVersion import getVersion

from time import sleep
from os import popen, getcwd, makedirs
from argparse import ArgumentParser, RawTextHelpFormatter
from os.path import join, splitext, isdir, isfile, basename


class CliCollector(object):

    def __init__(self):
        self.cycle = 1
        self.white_ls = [
            'temp',
            'time',
            'units',
            'read',
            'raw',
            'write',
            'written'
        ]
        self.cmd_dict = {
            "sata": {
                "smart": "smartctl -A {0}",
            },
            "nvme": {
                "identify": "nvme id-ctrl {0}",
                "fw_log": "nvme fw-log {0}",
                "error_log": "nvme error-log {0}",
                "smart_log": "nvme smart-log {0}",
                "smart_add": "nvme smart-log-add {0}"
            },
            "issdcm": {
                "info": "issdcm -drive_list",
                "smart": "issdcm -drive_index {0} -smart",
                "error_log": "issdcm -drive_index {0} -get_log 1",
                "smart_log": "issdcm -drive_index {0} -get_log 2",
                "fw_log": "issdcm -drive_index {0} -get_log 3",
                "identify": "issdcm -drive_index {0} -identify"
            },
            "aocnvme": {
                "identify": "aocnvme id-ctrl {0}",
                "fw_log": "aocnvme fw-log {0}",
                "error_log": "aocnvme error-log {0}",
                "smart_log": "aocnvme smart-log {0}",
                "smart_add": "aocnvme lnvm smart-log-add {0}"
            }
        }
        self.nvme_ls = getNvmeList(sys_drive=True)
        self.sata_ls = getDriveList(sys_drive=True)
        self.alissd_ls = getAlissdList(sys_drive=True, physical=True)
        self.split_line = '=' * 80

    def filter(self, info):
        tmp = []
        for e in info.splitlines():
            c = 0
            for e1 in self.white_ls:
                if e1.lower() in e.lower():
                    c += 1
                    break
            if e not in tmp and c == 0:
                tmp.append(e)
        tmp = '\n'.join(tmp)
        return tmp

    def checkNum(self, items, drive_type):
        if len(items) == 0:
            logger.warning('WARNING: There are no any {0} been '. \
                           format(drive_type) + 'found in current system.')
            return False
        return True

    def checkReq(self, type):
        if type != 'sata':
            ret = popen('command -v {0} 2> /dev/null'.format(type)).read(). \
                        replace('\n', '')
            if not ret:
                logger.warning('WARNING: Requirement {0}'.format(type) +
                               ' is not found.')
                return False
        return True

    def compare(self, cycle, type):
        keys = [e for e in self.cmd_dict[type].keys() if 'smart' in e.lower()]
        if cycle == self.cycle:
            logger.info('\n{0}\n'.format(self.split_line))
            for e in keys:
                latest = join(logdir, type, 'latest_{0}.log'.format(e))
                criteria = join(logdir, type, 'criteria_{0}.log'.format(e))
                if isfile(latest) and isfile(criteria):
                    data_1 = fopen(file=criteria).replace('\n', '')
                    data_2 = fopen(file=latest).replace('\n', '')
                    if data_1 != data_2:
                        logger.error('Check {0} {1} info FAIL.'. \
                                     format(type, e))
                        logger.error('Please check log between ' +
                                     '{0} and {1}'. \
                                     format(criteria, latest))
                    else:
                        logger.info('Check {0} {1} info PASS.'. \
                                    format(type, e))

    def executor(self, type, items):
        if len(items) == 0:
            return False
        if not self.checkReq(type=type):
            return False
        if not isdir(join(pwd, logdir, type)):
            makedirs(join(pwd, logdir, type), 0o755)
        for i in range(self.cycle):
            logger.info('\n' + self.split_line)
            logger.info('NO. {0} test cli {1} command execution.'. \
                        format(i + 1, type))
            for e in items:
                for e1 in self.cmd_dict[type].keys():
                    cmd = self.cmd_dict[type][e1]
                    log_name = join(logdir, type, e1 + '.log')
                    logger.info('--> run command: ' + cmd.format(e))
                    log = popen(cmd.format(e) + ' 2>&1').read()
                    fopen(file=log_name,
                          content='Cycle-{0}-{1}\n'.format(i + 1, basename(e)),
                          mode='a')
                    fopen(file=log_name, content=log, mode='a')
                    fopen(file=log_name,
                          content='\n{0}\n'.format(self.split_line),
                          mode='a')

                    # logger first/latest cycle for data comparation
                    if 'smart' in e1.lower():
                        latest = join(logdir, type, 'latest_{0}.log'. \
                                      format(e1))
                        criteria = join(logdir, type, 'criteria_{0}.log'. \
                                        format(e1))
                        log = self.filter(info=log)
                        if (i + 1) == 1:
                            fopen(file=criteria, content=log, mode='a')
                        elif (i + 1) == self.cycle:
                            fopen(file=latest, content=log, mode='a')

            # compare smart log between old and new
            self.compare(cycle=i + 1, type=type)

    def runCli(self, cycle):
        self.cycle = cycle

        # clear logs
        chk.clearReports(dir=logdir, ext='.log', assumeyes=yes)
        for e in ['sata', 'nvme', 'issdcm', 'aocnvme']:
            chk.clearReports(dir=join(logdir, e), ext='.log', assumeyes=yes)

        # collect smart log before test begin
        collectSmart(operation='before')

        # Open command handler
        if self.checkNum(items=self.sata_ls, drive_type='SATA HDD'):
            self.executor(type='sata', items=self.sata_ls)

        if self.checkNum(items=self.nvme_ls, drive_type='NVMe SSD'):
            self.executor(type='nvme', items=self.nvme_ls)

        # Intel SSD handler
        issdcm_info = popen('issdcm -drive_list').read().splitlines()
        index_ls = [issdcm_info[i - 1].split(':')[-1].strip() \
                    for i, e in enumerate(issdcm_info) \
                    if 'modelnumber' in e.lower() and 'intel' in e.lower()]
        if self.checkNum(items=index_ls, drive_type='Intel SSD'):
            self.executor(type='issdcm', items=index_ls)

        # Ali flash SSD handler
        if self.checkNum(items=self.alissd_ls, drive_type='Ali flash SSD'):
            self.executor(type='aocnvme', items=self.alissd_ls)

        # collect smart log after test done
        collectSmart(operation='after')

if __name__ == '__main__':

    # define global variables
    logdir = 'reports'
    pwd = getcwd()
    script = __file__
    script_name = splitext(__file__)[0]
    abs_script_log = join(pwd, logdir, script_name + '.log')
    rev = getVersion(file='README.md')

    # parse arguments
    parser = ArgumentParser(description='Cycle to run cli commands for ' +
                                        'SATA/NVMe drive log collection.',
                            formatter_class=RawTextHelpFormatter,
                            version=rev)
    parser.add_argument('-c', '--cycle',
                        dest='c', type=int, default=10,
                        help='set run cycle (default: %(default)s)')
    parser.add_argument('-y', '--assumeyes',
                        action='store_true',
                        help='answer yes for all questions')
    parser.add_argument('--logfile',
                        dest='lg', type=str, default=abs_script_log,
                        help='set procedure message saved to ' +
                             '\n%(default)s')
    group1 = parser.add_argument_group('Run for 10 cycles', 'python ' + script)
    args = parser.parse_args()
    cycle = args.c
    yes = args.assumeyes
    logName = args.lg

    # config log
    logger = logging()
    logger.basicConfig(
        filename=logName,
        level=logger.INFO,
        format='[%(asctime)-12s] %(levelname)-8s : %(message)s',
        datefmt='%Y-%m-%d %H:%M:%S',
    )

    # create log check object
    chk = Validator(type='sel', logdir=logdir, keydata='')

    cli = CliCollector()
    cli.runCli(cycle=cycle)

