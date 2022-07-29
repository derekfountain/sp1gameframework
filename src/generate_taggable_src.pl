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

# This script creates a "taggable source" file which can be loaded into my
# modified version of Fuse. See https://spectrumcomputing.co.uk/forums/viewtopic.php?t=974
#
# The idea is to load the symbols of the generated executable and note the
# address in the Spectrum memory each one appears at. Then load and merge
# all the *.c.lis files produced by the compiler. Those *.c.lis files
# contain the assembly language generated to implement the C code, and
# each instruction is labelled with a numeric offset from the start of
# the list file. So the idea is to pick out each symbol as the parse
# of the list file comes across it, note the location in memory that
# symbol is at, then continue down the list file adding the offset of each
# instruction to the symbol's definition.
#
# Example:
#
#   722                          ; Function main
#   723                          ; ---------------------------------
#   724   000000 _main:
#   725                          ;main.c:39: if( is_rom_writable() )
#   726   000000 cd0000          	call	_is_rom_writable
#   727   000003 7d              	ld	a, l
#   728   000004 b7              	or	a, a
#   729   000005 2800            	jr	Z,l_main_00102
#
# I come across the _main: symbol and note it's at offset 000000 in this
# list file (line 724). I find its location in the symbols table - let's say
# it lands at 32768. The first subsequent instruction is a "call", and its
# offset is 000000 from the start of this file (line 726). So that call is
# at 000000-000000+32768, which is 32768.
#
# The next instruction is the "ld a,l" at offset 000003, so 000003-000000
# is 3, 32768+3 is 32771, so that instruction is at 32771. And so on.
#
# When a new symbol is found:
#
#
#   685                          ; Function setup_int
#   686                          ; ---------------------------------
#   687   00000d _setup_int:
#   688                          ;int.c:43: memset( TABLE_ADDR, JUMP_POINT_HIGH_BYTE, 257 );
#   689   00000d 2100d0          	ld	hl,0xd000
#
# I find the _setup_int: symbol. Let's say it lands at 40000. The next
# instruction is at offset 00000d, which places it at 40013.
#
# The output from this script is in the form:
#
# 0x8000 ++ <rest of line in list file>
#
# This loads into Fuse, which tags the line with the address value it
# contains - 0x8000 in this case. When the PC reaches 8000 that value
# is searched in the text as tag, and the text viewer is scrolled to 
# that location.
#
# Some locations will have several tags all the same:
#
#   724   008000 _main:
#   725                          ;main.c:39: if( is_rom_writable() )
#   726   008000 cd0000          	call	_is_rom_writable
#
# In this case the viewer would scroll to the /last/ line with that address
# entry which is the opposite of what's required. So the output is set to
# only write a single address once in the tagged output:
#
# 0x8000 ++ <rest of line in list file>
# 0x     ++ <rest of next line in list file>

#
#
#

# Load in the symbols table. The real symbols table has all the information
# but for now my previously created symbols file containing name=value pairs
# is easiest to parse.
#
my %symbols = ();

my $symbols_filename = shift( @ARGV );
open( SYM_FILE_HANDLE, $symbols_filename ) or die("No such input file \"$symbols_filename\"\n");
while( my $line = <SYM_FILE_HANDLE> ) {

  if( $line =~ /^(\w+)\s+(\w+)/ ) {
    $symbols{$1} = "0x$2";
  }
}
close( SYM_FILE_HANDLE );


my %addresses_written=();

foreach my $lis_filename (@ARGV) {

  open( LIS_FILE_HANDLE, $lis_filename ) or die("No such input file \"$lis_filename\"\n");

  my $in_function = undef;
  my $lis_file_offset = "0000";
  my $offset_at_last_symbol = "0000";
  my $last_symbol_address = "0000";
  my $rest_of_line;

  my $skip_block = 0;
  while( my $line = <LIS_FILE_HANDLE> ) {
    chomp($line);
    $rest_of_line = $line;

    # Skip over the lis file IF 0/ENDIF blocks
    #
    if( $line =~ /\d+\s+\w+\s+IF 0/ ) {
      $skip_block = 1;
    }
    elsif( $skip_block && $line =~ /\d+\s+\w+\s+ENDIF/ ) {
      $skip_block = 0;
    }
    elsif( $line =~ /^1\s+0000\s+MODULE/ ) {
      $lis_file_offset       = "0000";
      $offset_at_last_symbol = "0000";
      $last_symbol_address   = "0000";
    }
    else {

      if( ! $skip_block ) {

	# Most lines start with, for example:
	#
	#    726   000000 cd0000          	call	_is_rom_writable
	#
	# The first value is a line number in the *.lis file. The second
	# value is a hex number which indicates the hex offset from the
	# start of the list file. Then there's the machine code values.
	# The rest of the line is the assembler.
	#
	# Function declaration lines are:
	#
	#    724   000000 _main:
	#
	# So the same, only there's nothing in the rest-of-line
	#
	if( $line =~ /^\s*(\d+)\s\s\s(\w+)(\s+.*)$/ ) {
	  my $lis_file_line_number = $1;

	  # Note the offset of this line from the start of the list file
	  #
	  $lis_file_offset = $2;

	  $rest_of_line = $3;

	  # We found a line of interest, work out if it's a new function
	  # defintition.
	  #
	  #    724   000000 _main:
	  #
	  # If so, it will be in the symbols file.
	  #
	  if( $line =~ /^\s*\d+\s+\w+\s+(_\w+):\s*$/ ) {
	    my $symbol = $1;
	    
	    if( exists( $symbols{$symbol} ) ) {

	      $last_symbol_address = $symbols{$symbol};
	      $offset_at_last_symbol = $lis_file_offset;
	    
	      # At this point I know the location in Spectrum memory of that
	      # symbol, and the location of the symbol's code from the start
	      # of the list file.

#	      print "++++ ".$symbols{$symbol}." -- ".$symbol."\n";
	    }
	    else {
	      print "???? -- ".$symbol."\n";
	    }
	  }
	}	  
      }
    }

    # So for each line I can subtract the line's location in the list file
    # from the location in the list of the last symbol - the function we're
    # parsing though. That gives the offset is bytes of the current line's
    # instruction from the start of the defintion of the function the symbol
    # refers to. Add that offset to where the function is in Spectrum memory
    # to find the address of the current line's m/c code in the Spectrum
    # memory.
    #
    my $address = hex($lis_file_offset) - hex($offset_at_last_symbol) + hex($last_symbol_address);
    if( !exists( $addresses_written{$address} ) )
    {
      printf("0x%04X ++ %s\n", $address, $rest_of_line);
      $addresses_written{$address} = 1;
    }
    else
    {
      printf("0x     ++ %s\n", $rest_of_line);
    }
 
  }

  close( LIS_FILE_HANDLE );
}
