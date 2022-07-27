/*
 * SP1 Game Framework
 * Copyright (C) 2022 Derek Fountain
 * 
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 * 
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 * 
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
 */

#include <arch/zx.h>
#include <arch/zx/sp1.h>
#include <intrinsic.h>
#include <input.h>
#include <stdint.h>
#include <z80.h>

#include "tracetable.h"
#include "gameloop.h"
#include "int.h"

/* Hopefully the optimiser won't remove this. :) Keep it 8 bytes, BE expects that */
unsigned char version[8] = "ver1.00";

struct sp1_Rect full_screen = {0, 0, 32, 24};


int main()
{
  if( is_rom_writable() )
  {
    /* Flicker the border if ROM is being used for trace */
    zx_border(INK_RED);
    z80_delay_ms(100);
    zx_border(INK_BLUE);
    z80_delay_ms(100);
    zx_border(INK_WHITE);

    clear_trace_area();    

    init_gameloop_trace();
  }

  setup_int();

  sp1_Initialize( SP1_IFLAG_MAKE_ROTTBL | SP1_IFLAG_OVERWRITE_TILES | SP1_IFLAG_OVERWRITE_DFILE,
                  INK_BLACK | PAPER_WHITE,
                  'O' );
  sp1_Invalidate(&full_screen);
  sp1_UpdateNow();

  while( 1 );
}
