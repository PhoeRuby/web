#!/usr/bin/python
# -*- coding: utf-8 -*-

from glob import glob
from os import remove
from re import sub, search
from os.path import isfile, splitext


class FioDataParser(object):

    def __init__(self, logList):
        self.data_dict = {}
        self.data_dict2 = {}
        self.data_dict3 = {}
        self.data_dict4 = {}
        self.logList = logList
        self.multipleHandle()

    def getdigit(self, data):
        return sub(r'[^\d]', '', data)

    def multipleHandle(self):
        for e in self.logList:
            with open(e) as rf:
                self.data_dict[splitext(e)[0]] = rf.read().split('\n')

    # create correspond data
    def correspond(self):
        for k, v in self.data_dict.items():
            self.tmp_idx = 0
            self.data_dict2[k] = {}
            for i, e in enumerate(v):
                if search(r'^\w+\:\s\(groupid=\d+\,\ jobs=\d+\):\s', e):
                    if self.tmp_idx == 0:
                        self.tmp_idx = i
                        continue
                    self.tmp_ls = v[self.tmp_idx:i]
                    key = self.tmp_ls[0].split(':')[0]
                    self.data_dict2[k][key] = self.tmp_ls[1:]
                    self.tmp_idx = i
                if (i + 1) == len(v):
                    self.tmp_ls = v[self.tmp_idx:]
                    key = self.tmp_ls[0].split(':')[0]
                    self.data_dict2[k][key] = self.tmp_ls[1:]

        for k, v in self.data_dict2.items():
            self.data_dict3[k] = {}
            for k1, v1 in v.items():
                self.data_dict3[k][k1] = {}
                for e in v1:
                    if 'read :' in e or 'write:' in e:
                        type = e.split(':')[0].strip()
                        self.data_dict3[k][k1][type] = {}
                        self.data_dict3[k][k1][type]['bw'] = e.split(',')[1].strip().split('=')[1][:-4]
                        self.data_dict3[k][k1][type]['iops'] = e.split(',')[2].strip().split('=')[1]
                    if '(usec):' in e and 'avg=' in e:
                        self.data_dict3[k][k1][type]['avg'] = e.split(',')[2].split('=')[1].strip()
                    if '99.99th=' in e:
                        self.data_dict3[k][k1][type]['qos'] = self.getdigit(e.split('=')[1])
        return self.data_dict3

    # arrange output data
    def output(self):
        msg = ''
        data = {}

        if isfile('excel_fmt_report.log'):
            remove('excel_fmt_report.log')

        # sequential the key
        for k, v in self.correspond().items():
            data[k] = {}
            for k1, v1 in v.items():
                k2 = k1.replace('1M', '1024k')
                k2 = '_'.join(['QD' + e.replace('QD', '').zfill(4) if 'QD' in e else e for e in k2.split('_')])
                k2 = '_'.join([e.zfill(5) if e[0].isdigit() else e for e in k2.split('_')])
                data[k][k2] = v1

        x = 0
        for k, v in sorted(data.items()):
            c = 0
            for k1, v1 in sorted(v.items()):
                k1 = sub('_0+', '_', k1)
                k1 = sub('QD0+', 'QD', k1)
                k1 = k1 + ':,'
                if x != 0:
                    k1 = ''
                if 'read' in v1 and 'write' in v1:
                    msg = msg + '|{0} {1} {2}/{3}, {4}/{5}, {6}/{7}, {8}/{9}, '.format(c,
                                                                                       k1,
                                                                                       v1['read']['bw'],
                                                                                       v1['write']['bw'],
                                                                                       v1['read']['iops'],
                                                                                       v1['write']['iops'],
                                                                                       v1['read']['avg'],
                                                                                       v1['write']['avg'],
                                                                                       v1['read']['qos'],
                                                                                       v1['write']['qos'])
                else:
                    for k2, v2 in v1.items():
                        msg = msg + '|{0} {1} {2}, {3}, {4}, {5},'.format(c,
                                                                          k1,
                                                                          v2['bw'],
                                                                          v2['iops'],
                                                                          v2['avg'],
                                                                          v2['qos'])
                c += 1
            x += 1
        msg = [e for e in msg.split('|') if e != '']
        for e in msg:
            num = e.split(' ')[0].zfill(5)
            val = ' '.join(e.split(' ')[1:])
            if num == num:
                try:
                    self.data_dict4[num] = self.data_dict4[num] + val
                except:
                    self.data_dict4[num] = val

        # generate excel format log
        with open('excel_fmt_report.log', 'a') as wf:
            for k, v in sorted(self.data_dict4.items()):
                wf.write(v + '\n')
        print '\nParse Completed! excel_fmt_report.log has been generated.\n'

        return self.data_dict4


if __name__ == '__main__':

    #try:
    print '##### Collect log data and parsing ...'
    log_ls = [e for e in glob('*.log') if not search('^excel', e)]
    log = FioDataParser(logList=sorted(log_ls))
    log.output()
    #except Exception as err:
    #    print str(err)

