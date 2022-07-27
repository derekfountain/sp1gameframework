/*
 * Tracing. I wrote an article here: http://www.derekfountain.org/spectrum_ffdc.php
 * which describes the idea behind this. This implementation is standardised
 * using macros so the tools all Just Work(TM).
 *
 * Get a dump by saving Spectrum memory from 0, length 65536, using Fuse's
 * save binary image.
 *
 * Then examine the tracing with:
 *
 * >be -i sp1gameframework.berc zxspectrum_be/sp1.berc -y sp1gameframework.sym dump.ss@0
 *
 */

#ifndef __TRACETABLE_H
#define __TRACETABLE_H

#include <unistd.h>
#include <string.h>

#define TRACING_INACTIVE      ((void*)0xFFFF)

/*
 * Start of memory area used for trace table.
 */
#define TRACE_MEMORY_START ((uint16_t)0)

/*
 * Maximum amount of memory to allocate to tracetables.
 * We use the ROM area up to the char set definition at 0x3D00.
 */
#define MAX_TRACE_MEMORY ((uint16_t)(0x3D00))

/*
 * Macro to generate a function to add an entry to a trace table.
 * The process is to take a pointer to a structure which defines
 * the trace entry, memcpy() it into the next slot of the trace
 * table, advance the next slot point, and if it wraps put the
 * next slot pointer back to the start of the table. Since all
 * tracing needs to do exactly this, this function is generated
 * with a macro to enforce conformity.
 *
 * The macro takes the name of the thing to be traced, the type
 * which defines the trace entry structure, and the size of the
 * table in bytes so it knows when to wrap.
 * It also defines and initialises the table pointer and the
 * next entry in the table pointer.
 */
#define TRACE_FN( NAME, TYPE, TABLE_SIZE )	\
\
TYPE * NAME ## _tracetable = TRACING_INACTIVE; \
TYPE * NAME ## _next_trace = 0xFFFF; \
\
void NAME ## _add_trace( TYPE * ptr ) \
{\
  memcpy( NAME ## _next_trace, ptr, sizeof(TYPE));\
\
  NAME ## _next_trace = (void*)((uint8_t*)NAME ## _next_trace + sizeof(TYPE));\
\
  if( NAME ## _next_trace == (void*)((uint8_t*)NAME ## _tracetable + TABLE_SIZE) )\
      NAME ## _next_trace = NAME ## _tracetable;\
}


/*
 * Find out if the ROM is writable. In some emulators it can be.
 * Answers 1 if it is, or 0 if not.
 */
uint8_t is_rom_writable(void);

/*
 * Clear or otherwise initialise the area of memory all the
 * tracing will go into.
 */
void* clear_trace_area(void);

/*
 * Allocate memory to hold a tracetable of 'size' bytes.
 * Returns a pointer to the zeroth byte (i.e. the first
 * trace entry).
 */
void* allocate_tracememory( size_t size );

#endif
