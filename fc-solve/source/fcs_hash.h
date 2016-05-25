/* Copyright (c) 2000 Shlomi Fish
 *
 * Permission is hereby granted, free of charge, to any person
 * obtaining a copy of this software and associated documentation
 * files (the "Software"), to deal in the Software without
 * restriction, including without limitation the rights to use,
 * copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following
 * conditions:
 *
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
 * OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
 * HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
 * WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
 * OTHER DEALINGS IN THE SOFTWARE.
 */
/*
 * fcs_hash.h - header file of Freecell Solver's internal hash implementation.
 *
 */

#pragma once

#ifdef __cplusplus
extern "C" {
#endif

#include "config.h"

#include "meta_alloc.h"
#include "rinutils.h"

#ifdef FCS_INLINED_HASH_COMPARISON
enum FCS_INLINED_HASH_DATA_TYPE
{
    FCS_INLINED_HASH__COLUMNS,
    FCS_INLINED_HASH__STATES,
};
#endif

typedef int fc_solve_hash_value_t;

struct fc_solve_hash_symlink_item_struct
{
    /* A pointer to the data structure that is to be collected */
    void * key;
    /* We also store the hash value corresponding to this key for faster
       comparisons */
    fc_solve_hash_value_t hash_value;
#ifdef FCS_ENABLE_SECONDARY_HASH_VALUE
    /*
     * We also store a secondary hash value, which is not used for indexing,
     * but is used to speed up comparison.
     * */
    fc_solve_hash_value_t secondary_hash_value;
#endif
    /* The next item in the list */
    struct fc_solve_hash_symlink_item_struct * next;
};

typedef struct fc_solve_hash_symlink_item_struct fc_solve_hash_symlink_item_t;

typedef struct
{
    fc_solve_hash_symlink_item_t * first_item;
} fc_solve_hash_symlink_t;

struct fc_solve_instance_struct;

#ifndef FCS_INLINED_HASH_COMPARISON
#ifdef FCS_WITH_CONTEXT_VARIABLE
typedef int (*fcs_hash_compare_function_t)(const void * const, const void * const, void * context);
#else
typedef int (*fcs_hash_compare_function_t)(const void * const, const void * const);
#endif
#endif

typedef struct
{
    /* The vector of the hash table itself */
    fc_solve_hash_symlink_t * entries;
#ifndef FCS_WITHOUT_TRIM_MAX_STORED_STATES
    /* The list of vacant items as freed by the garbage collector. Use
     * if before allocating more. */
    fc_solve_hash_symlink_item_t * list_of_vacant_items;
#endif
    /* A comparison function that can be used for comparing two keys
       in the collection */
#ifdef FCS_INLINED_HASH_COMPARISON
    enum FCS_INLINED_HASH_DATA_TYPE hash_type;
#else
    fcs_hash_compare_function_t compare_function;
#ifdef FCS_WITH_CONTEXT_VARIABLE
    /* A context to pass to the comparison function */
    void * context;
#else
#endif
#endif

    /* The size of the hash table */
    int size;

    /* A bit mask that extract the lowest bits out of the hash value */
    int size_bitmask;
    /* The number of elements stored inside the hash */
    fcs_int_limit_t num_elems;

    fcs_int_limit_t max_num_elems_before_resize;

    fcs_compact_allocator_t allocator;
#ifdef FCS_RCS_STATES
    struct fc_solve_instance_struct * instance;
#endif
} fc_solve_hash_t;

static GCC_INLINE void fcs_hash_set_max_num_elems(
    fc_solve_hash_t * const hash,
    const fcs_int_limit_t new_size
)
{
    hash->max_num_elems_before_resize = (new_size << 1);
}

static GCC_INLINE void fc_solve_hash_init(
    fcs_meta_compact_allocator_t * const meta_alloc,
    fc_solve_hash_t * const hash,
#ifdef FCS_INLINED_HASH_COMPARISON
    const enum FCS_INLINED_HASH_DATA_TYPE hash_type
#else
    fcs_hash_compare_function_t compare_function
#ifdef FCS_WITH_CONTEXT_VARIABLE
    , void * const context
#else
#endif
#endif
    )
{
    const typeof(hash->size) initial_hash_size = 2048;

    hash->size = initial_hash_size;
    hash->size_bitmask = initial_hash_size-1;
    fcs_hash_set_max_num_elems(hash, initial_hash_size);

    hash->num_elems = 0;

    /* Allocate a table of size entries */
    /* Initialize all the cells of the hash table to NULL, which indicate
       that the end of each chain is right at the start. */
    hash->entries = (fc_solve_hash_symlink_t *)calloc(
        initial_hash_size, sizeof(hash->entries[0])
        );

#ifndef FCS_WITHOUT_TRIM_MAX_STORED_STATES
    hash->list_of_vacant_items = NULL;
#endif

#ifdef FCS_INLINED_HASH_COMPARISON
    hash->hash_type = hash_type;
#else
    hash->compare_function = compare_function;
#ifdef FCS_WITH_CONTEXT_VARIABLE
    hash->context = context;
#endif
#endif

    fc_solve_compact_allocator_init(&(hash->allocator), meta_alloc);

    return;
}


static GCC_INLINE void fc_solve_hash_free(
    fc_solve_hash_t * const hash
    )
{
    fc_solve_compact_allocator_finish(&(hash->allocator));

    free(hash->entries);
    hash->entries = NULL;
}

#ifndef FCS_WITHOUT_TRIM_MAX_STORED_STATES
static GCC_INLINE void fc_solve_hash_foreach(
    fc_solve_hash_t * const hash,
    const fcs_bool_t (*should_delete_ptr)(void * const key, void * const context),
    void * const context
    )
{
    const_SLOT(size, hash);
    for (int i = 0 ; i < size ; i++)
    {
        fc_solve_hash_symlink_item_t * * item = &(hash->entries[i].first_item);
        while ((*item) != NULL)
        {
            if (should_delete_ptr((*item)->key, context))
            {
                fc_solve_hash_symlink_item_t * next_item = (*item)->next;
                /* Garbage collect (*item). */
                (*item)->next = hash->list_of_vacant_items;
                hash->list_of_vacant_items = (*item);
                /* Skip the item in the chain. */
                (*item) = next_item;

                hash->num_elems--;
            }
            else
            {
                item = &((*item)->next);
            }
        }
    }
}
#endif

#ifdef __cplusplus
}
#endif
