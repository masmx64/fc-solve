/*
 * This file is part of Freecell Solver. It is subject to the license terms in
 * the COPYING.txt file found in the top-level directory of this distribution
 * and at http://fc-solve.shlomifish.org/docs/distro/COPYING.html . No part of
 * Freecell Solver, including this file, may be copied, modified, propagated,
 * or distributed except according to the terms contained in the COPYING file.
 *
 * Copyright (c) 2000 Shlomi Fish
 */
// card.c - functions to convert cards and card components to and from
// their user representation.
#include "state.h"
#include "rank2str.h"

#ifdef DEFINE_fc_solve_empty_card
DEFINE_fc_solve_empty_card();
#endif

// Converts a suit to its user representation.
static inline void suit2str(const int suit, char *str)
{
    str[0] = "HCDS"[suit];
    str[1] = '\0';
}

// Convert an entire card to its user representation.
void fc_solve_card_stringify(
    const fcs_card_t card, char *const str PASS_T(const fcs_bool_t t))
{
    rank2str(fcs_card_rank(card), str PASS_T(t));
    suit2str(fcs_card_suit(card), strchr(str, '\0'));
}
