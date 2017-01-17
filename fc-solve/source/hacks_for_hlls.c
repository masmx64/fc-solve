/*
 * This file is part of Freecell Solver. It is subject to the license terms in
 * the COPYING.txt file found in the top-level directory of this distribution
 * and at http://fc-solve.shlomifish.org/docs/distro/COPYING.html . No part of
 * Freecell Solver, including this file, may be copied, modified, propagated,
 * or distributed except according to the terms contained in the COPYING file.
 *
 * Copyright (c) 2013 Shlomi Fish
 */
/*
 * hacks_for_hlls.c - the Freecell Solver utility methods for high-level
 * languages.
 */

#include "dll_thunk.h"
#include <string.h>
#include <stdlib.h>
#include <stdio.h>
#include "set_weights.h"
#include "fcs_user.h"
#include "fcs_cl.h"
#include "split_cmd_line.h"
#include "prefix.h"
#include "rinutils.h"
#include "cmd_line_enum.h"

DLLEXPORT void freecell_solver_user_stringify_move_ptr(
    void *const user_instance, char *const output_string,
    fcs_move_t *const move_ptr, const int standard_notation)
{
    freecell_solver_user_stringify_move_w_state(
        user_instance, output_string, *move_ptr, standard_notation);
}
