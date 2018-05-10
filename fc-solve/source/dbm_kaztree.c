/*
 * This file is part of Freecell Solver. It is subject to the license terms in
 * the COPYING.txt file found in the top-level directory of this distribution
 * and at http://fc-solve.shlomifish.org/docs/distro/COPYING.html . No part of
 * Freecell Solver, including this file, may be copied, modified, propagated,
 * or distributed except according to the terms contained in the COPYING file.
 *
 * Copyright (c) 2000 Shlomi Fish
 */
#include "dbm_solver.h"
#include "generic_tree.h"

#include "dbm_kaztree_compare.h"

typedef struct
{
    dict_t *kaz_tree;
    meta_allocator meta_alloc;
#ifndef FCS_LIBAVL_STORE_WHOLE_KEYS
    compact_allocator allocator;
#endif
} fcs_dbm;

void fc_solve_dbm_store_init(fcs_dbm_store_t *const store,
    const char *path GCC_UNUSED, void **const recycle_bin_ptr)
{
    fcs_dbm *const db = SMALLOC1(db);

    fc_solve_meta_compact_allocator_init(&(db->meta_alloc));

    db->kaz_tree = fc_solve_kaz_tree_create(
        compare_records, NULL, &(db->meta_alloc), recycle_bin_ptr);

#ifndef FCS_LIBAVL_STORE_WHOLE_KEYS
    fc_solve_compact_allocator_init(&(db->allocator), &(db->meta_alloc));
#endif

    *store = (fcs_dbm_store_t)db;
}

dict_t *__attribute__((pure)) fc_solve_dbm_store_get_dict(fcs_dbm_store_t store)
{
    return (((fcs_dbm *)store)->kaz_tree);
}

/*
 * Returns TRUE if the key was added (it didn't already exist.)
 * */
fcs_dbm_record_t *fc_solve_dbm_store_insert_key_value(fcs_dbm_store_t store,
    const fcs_encoded_state_buffer_t *key, fcs_dbm_record_t *const parent,
    const bool should_modify_parent GCC_UNUSED)
{
#ifdef FCS_LIBAVL_STORE_WHOLE_KEYS
    fcs_dbm_record_t record_on_stack;

    /* This memset() call is done to please valgrind and for general
     * good measure. It is not absolutely necessary (but should not
     * hurt much). It is needed due to struct padding and alignment
     * issues.
     * */
    memset(&record_on_stack, '\0', sizeof(record_on_stack));
#endif

    fcs_dbm *const db = (fcs_dbm *)store;

    fcs_dbm_record_t *to_check;
#ifdef FCS_LIBAVL_STORE_WHOLE_KEYS
    to_check = &record_on_stack;
#else
    to_check = (fcs_dbm_record_t *)fcs_compact_alloc_ptr(
        &(db->allocator), sizeof(*to_check));
#endif

#ifdef FCS_DBM_RECORD_POINTER_REPR
    to_check->key = *key;
    fcs_dbm_record_set_parent_ptr(to_check, parent);
#else
    to_check->key = *key;
    to_check->parent = parent->parent;
#endif
    bool ret =
        (fc_solve_kaz_tree_alloc_insert(db->kaz_tree, to_check) == NULL);

#ifndef FCS_LIBAVL_STORE_WHOLE_KEYS
    if (!ret)
    {
        fcs_compact_alloc_release(&(db->allocator));
    }
#endif
    if (ret)
    {
        if (should_modify_parent && parent)
        {
            fcs_dbm_record_increment_refcount(parent);
        }

        return ((fcs_dbm_record_t *)(fc_solve_kaz_tree_lookup_value(
            db->kaz_tree, to_check)));
    }
    else
    {
        return NULL;
    }
}

bool fc_solve_dbm_store_lookup_parent(
    fcs_dbm_store_t store, const unsigned char *key, unsigned char *parent)
{
    fcs_dbm_record_t to_check = {
        .key = *(const fcs_encoded_state_buffer_t *)key};

    dict_key_t existing =
        fc_solve_kaz_tree_lookup_value(((fcs_dbm *)store)->kaz_tree, &to_check);
    if (!existing)
    {
        return FALSE;
    }
    else
    {
#ifdef FCS_DBM_RECORD_POINTER_REPR
        fcs_dbm_record_t *const p =
            fcs_dbm_record_get_parent_ptr((fcs_dbm_record_t *)existing);

        if (p)
        {
            *(fcs_encoded_state_buffer_t *)parent = p->key;
        }
        else
        {
            fcs_init_encoded_state((fcs_encoded_state_buffer_t *)parent);
        }
#else
        *(fcs_encoded_state_buffer_t *)parent =
            ((fcs_dbm_record_t *)existing)->parent;
#endif
        return TRUE;
    }
}

extern void fc_solve_dbm_store_destroy(fcs_dbm_store_t store)
{
    fcs_dbm *const db = (fcs_dbm *)store;

    fc_solve_kaz_tree_destroy(db->kaz_tree);
#ifndef FCS_LIBAVL_STORE_WHOLE_KEYS
    fc_solve_compact_allocator_finish(&(db->allocator));
#endif
    fc_solve_meta_compact_allocator_finish(&(db->meta_alloc));
    free(db);
}
