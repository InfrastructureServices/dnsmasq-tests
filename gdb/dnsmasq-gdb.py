#!/usr/bin/python
# GDB helper routines in python to print sockaddr* structures in a nice way
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Copyright (C) 2023  Red Hat, Inc.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
# 

import socket
import sys
import gdb.printing

class BytesHelper(object):
    def __init__(self):
        self.byte_type = gdb.lookup_type('uint8_t')
        self.sa_type = gdb.lookup_type('struct sockaddr')
        self.sa_in_type = gdb.lookup_type('struct sockaddr_in')
        self.sa_in6_type = gdb.lookup_type('struct sockaddr_in6')

    def to_bytes(self, var):
        len = var.type.sizeof
        atype = self.byte_type.array(0, len-1)
        ba = bytearray()
        bytelike = var.cast(atype)
        for i in range(len):
            ba.append(bytelike[i])
        return ba

    def ntohs(self, var):
        return int.from_bytes(int(var).to_bytes(2, byteorder='big'), byteorder=sys.byteorder)

    def ntohl(self, var):
        return int.from_bytes(int(var).to_bytes(4, byteorder='big'), byteorder=sys.byteorder)

    def get_family(self, var):
        if var.type == self.sa_type:
            return var['sa_family']
        elif var.type == self.sa_in_type:
            return var['sin_family']
        elif var.type == self.sa_in6_type:
            return var['sin6_family']
        else:
            raise TypeError("Invalid variable type used: "+var.type.name)

    def get_family_string(self, var):
        af = int(self.get_family(var))
        try:
            return socket.AddressFamily(af).name
        except ValueError:
            return str(af)

    def string_sockaddr_any(self, var):
        family = self.get_family(var)
        if family == socket.AF_INET:
            return self.string_sockaddr_in(var)
        elif family == socket.AF_INET6:
            return self.string_sockaddr_in6(var)
        # Just print whatever we know about it.
        return var

    def string_sockaddr_in(self, var):
        if var.type == self.sa_type and var['sa_family'] == socket.AF_INET:
            var = var.cast(self.sa_in_type)
        if var.type != self.sa_in_type:
            return '{{{af}}}'.format(af=self.get_family_string(var))
            #raise(TypeError('Wrong type of variable used: '+var.type.name))

        assert(var['sin_family'] == socket.AF_INET)
        nport = var['sin_port']
        naddr = var['sin_addr']

        hport = self.ntohs(nport)
        haddr = socket.inet_ntop(socket.AF_INET, self.to_bytes(naddr))
        return '{{INET;{haddr}:{hport}}}'.format(hport=hport, haddr=haddr)

    def string_sockaddr_in6(self, var):
        if var.type == self.sa_type and var['sa_family'] == socket.AF_INET6:
            var = var.cast(self.sa_in6_type)
        if var.type != self.sa_in6_type:
            return '{{{af}}}'.format(af=self.get_family_string(var))

        assert(var['sin6_family'] == socket.AF_INET6)
        nport = var['sin6_port']
        naddr = var['sin6_addr']
        nflow = var['sin6_flowinfo']
        nscope = var['sin6_scope_id']

        hport = self.ntohs(nport)
        haddr = socket.inet_ntop(socket.AF_INET6, self.to_bytes(naddr))
        hflow = ''
        if nflow != 0:
            hflow = ';flow=0x%X' % (self.ntohl(nflow),)
        hscope = ''
        if nscope != 0:
            hscope = '%%%d' % (self.ntohl(nscope),)
        return '{{INET6;[{haddr}{hscope}]:{hport}{hflow}}}'.format(hport=hport, haddr=haddr, hflow=hflow, hscope=hscope)


class ToBytes(gdb.Command):
    """Make bytearray sequence from given variable"""
    def __init__(self, helper):
        super(ToBytes, self).__init__("to_bytes", gdb.COMMAND_USER)
        self.helper = helper

    def invoke(self, arg, from_tty):
        var = gdb.parse_and_eval(arg)
        print(self.helper.to_bytes(var))

class PrinterSockaddrIn(gdb.Command):
    """Print struct sockaddr_in in a friendly way."""
    def __init__(self, helper):
        super(PrinterSockaddrIn, self).__init__("p_sockaddr_in", gdb.COMMAND_USER)
        self.helper = helper

    def invoke(self, arg, from_tty):
        var = gdb.parse_and_eval(arg)
        print(self.helper.string_sockaddr_in(var))

class PrinterSockaddrIn6(gdb.Command):
    """Print struct sockaddr_in6 in a friendly way."""
    def __init__(self, helper):
        super(PrinterSockaddrIn6, self).__init__("p_sockaddr_in6", gdb.COMMAND_USER)
        self.helper = helper

    def invoke(self, arg, from_tty):
        var = gdb.parse_and_eval(arg)
        print(self.helper.string_sockaddr_in6(var))

class PrinterSockaddr(gdb.Command):
    """Print struct sockaddr in a friendly way."""
    """Make bytearray sequence from given variable"""
    def __init__(self, helper):
        super(PrinterSockaddr, self).__init__("p_sockaddr", gdb.COMMAND_USER)
        self.helper = helper

    def invoke(self, arg, from_tty):
        var = gdb.parse_and_eval(arg)
        print(self.helper.string_sockaddr_any(var))

# gdb.ValuePrinter base in newer versions
class SockaddrPrinter(object):
    """Print struct sockaddr_in a nicer way."""
    collection = '_glibc'

    def __init__(self, val):
        self.val = val
        self.helper = _helper # FIXME: how to pass this?

    def to_string(self):
        try:
            return self.helper.string_sockaddr_any(self.val)
        except Exception as e:
            print(e)
            raise(e)

    def display_hint(self):
        return None # 'string' ?

def build_pretty_printer():
    pp = gdb.printing.RegexpCollectionPrettyPrinter(SockaddrPrinter.collection)
    pp.add_printer('struct sockaddr', '^struct sockaddr(|_in|_in6)$', SockaddrPrinter)
    pp.add_printer('sockaddr', '^sockaddr(|_in|_in6)$', SockaddrPrinter)
    return pp

def is_registered():
    for i in gdb.pretty_printers:
        if i.name == SockaddrPrinter.collection:
            return True
    return False

def register_printers(objfile=gdb.current_objfile()):
    gdb.printing.register_pretty_printer(objfile, build_pretty_printer())

_helper = BytesHelper()
ToBytes(_helper)
PrinterSockaddrIn(_helper)
PrinterSockaddrIn6(_helper)
PrinterSockaddr(_helper)

if not is_registered():
    register_printers()
