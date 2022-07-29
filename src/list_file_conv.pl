#!/usr/bin/perl -w
use strict;

# SP1 Game Framework
# Copyright (C) 2022 Derek Fountain
# 
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

# In the transition from z88dk-2.1 to z88dk-2.2, the format of list
# files changed. The import change for me was the removal of the
# list file offset from the declaration of a function's label.
# It went from, e.g.:
#
#  805   0009              ; Function main
#  806   0009              ; ---------------------------------
#  807   0009              _main:
#  808   0009  DD E5               push    ix
#
# to:
#
#   722                          ; Function main
#   723                          ; ---------------------------------
#   724                          _main:
#   725                          ;main.c:39: if( is_rom_writable() )
#   726   000000 cd0000          	call	_is_rom_writable
#
# Note that line 724 there has lost the 0009 seen on 807. This removes the
# anchor point my generate_taggable_src.pl script uses.
#
# I tried updating the taggable source script, but it's hard to unravel
# what are now very similar lines. I decided it was easier to write an
# intermediate script to put back the missing bit I needed, hence this.
#
# This script creates an intermediate file which can fed into the
# create_taggable_src.pl script. That script takes multiple files so I
# couldn't do it as a pipe without rewriting too much.
#
# The code below takes a list of *.c.lis files, opens each one, reads it
# in, modifies the text, and writes out the same file with a .conv extension.
# The modification regex looks for the
#
# ;Function main
# --------------
# _main:
#
# bit, skips any intermediate stuff the compiler put in there, then reads the
# missing offset value from the next line (the line with the first machine
# code instruction in it). It then rebuilds the line from the bits, adding in
# the offset value.

foreach my $input_file (@ARGV)
{
  my $output_file = ">$input_file.conv";

  open( IN, $input_file ) or die("Input file \"$input_file\" not found\n");
  my $file_content = do { local $/; <IN> };
  close(IN);

#  if( $file_content =~ /(\s+\d+\s+;\sFunction\s(\w+)\n                     # ; Function <name>
#                         \s+\d+\s+;\s-+\n                                  # -----------------
#		         \s+\d+)\s+(_\w+:\n                                 # <line num>   _<name>:
#		         .*?                                                # EXTERNs, bits of C, etc
#		         \s+\d+\s+)([0-9a-f]{6})(\s+[0-9a-f]+.*?\n)/xs )    # First line of the function
#  {
#    print STDERR "xx$1   $4 $3$4$5xx\n";
#    print STDERR "xx$1xx\n";
#  }

  $file_content =~ s/(\s+\d+\s+;\sFunction\s(\w+)\n                                    # ; Function <name>
                      \s+\d+\s+;\s-+\n                                                 # -----------------
		      \s+\d+)\s+(_\w+:\n                                               # <line num>   _<name>:
		      .*?                                                              # EXTERNs, bits of C, etc
		      \s+\d+\s+)([0-9a-f]{6})(\s+[0-9a-f]+.*?\n)/$1   $4 $3$4$5/xsg;   # First line of the function

  open( OUT, $output_file ) or die("Unable to write to \"$output_file\"\n");
  print OUT $file_content;
  close(OUT);
}


__END__

Example - see line 724 below:

   720                          ;main.c:37: int main()
   721                          ;	---------------------------------
   722                          ; Function main
   723                          ; ---------------------------------
   724                          _main:
   725                          ;main.c:39: if( is_rom_writable() )
   726   000000 cd0000          	call	_is_rom_writable


   720                          ;main.c:37: int main()
   721                          ;	---------------------------------
   722                          ; Function main
   723                          ; ---------------------------------
   724   000000 _main:
   725                          ;main.c:39: if( is_rom_writable() )
   726   000000 cd0000          	call	_is_rom_writable
