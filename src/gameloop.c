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
#include <string.h>
#include <stdint.h>
#include <z80.h>
#include <sound.h>

#include "tracetable.h"

/***
 *      _______             _             
 *     |__   __|           (_)            
 *        | |_ __ __ _  ___ _ _ __   __ _ 
 *        | | '__/ _` |/ __| | '_ \ / _` |
 *        | | | | (_| | (__| | | | | (_| |
 *        |_|_|  \__,_|\___|_|_| |_|\__, |
 *                                   __/ |
 *                                  |___/ 
 *
 * This defines the game loop's trace table.
 */

typedef enum _gameloop_tracetype
{
  ENTER,
  EXIT,
} GAMELOOP_TRACETYPE;

typedef struct _gameloop_trace
{
  uint16_t           ticker;
  GAMELOOP_TRACETYPE tracetype;
} GAMELOOP_TRACE;

/* BE:PICKUPDEF */
#define GAMELOOP_TRACE_ENTRIES 500
#define GAMELOOP_TRACETABLE_SIZE ((size_t)sizeof(GAMELOOP_TRACE)*GAMELOOP_TRACE_ENTRIES)

/* It's quicker to do this with a macro, as long as it's only used once or twice */
#define GAMELOOP_TRACE_CREATE(ttype) { \
    if( gameloop_tracetable != TRACING_INACTIVE ) { \
      GAMELOOP_TRACE      glt;   \
      glt.tracetype       = ttype; \
      gameloop_add_trace(&glt); \
    } \
}

TRACE_FN( gameloop, GAMELOOP_TRACE, GAMELOOP_TRACETABLE_SIZE )

void init_gameloop_trace(void)
{
  gameloop_tracetable = gameloop_next_trace = allocate_tracememory(GAMELOOP_TRACETABLE_SIZE);
}

