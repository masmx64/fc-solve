#!/usr/bin/env python3
#
# find-freecell-deal-index.py - a program to find out the Freecell deal index
# based on the initial cards layout.
#
# Copyright by Shlomi Fish, 2018
#
# Licensed under the MIT/Expat License.
"""
For now, you can try using these as drivers:

    bash ../../scripts/opencl-test.bash

    CC=clang REBUILD=1 prove ../../scripts/opencl-test.t

"""

import sys

from make_pysol_freecell_board import find_index_main

COMMON_RAND = '((r[gid] = (r[gid]*214013 + 2531011)) >> 16)'


def _update_file(fn, newtext):
    update = False
    try:
        with open(fn, "rt") as fh:
            oldtext = fh.read()
    except FileNotFoundError:
        update = True
    if update or (oldtext != newtext):
        with open(fn, "wt") as fh:
            fh.write(newtext)


def find_ret(ints, num_ints_in_first=4):
    assert len(ints) == 51
    STEP = 6

    def _myrand(mod):
        return ('(({} & 0x7fff) % {})').format(COMMON_RAND, mod)

    def _myrand_to_4G(mod):
        return ('((({} & 0x7fff)|0x8000) % {})').format(COMMON_RAND, mod)

    def _myrand_to_8G(mod):
        return ('((({} & 0xffff)+1) % {})').format(COMMON_RAND, mod)
    _myrand_lookups = {base: _myrand(base) for base in range(1, 53)}
    _myrand_to_4G_lookups = {
        base: _myrand_to_4G(base) for base in range(1, 53)}
    _myrand_to_8G_lookups = {
        base: _myrand_to_8G(base) for base in range(1, 53)}
    kernel_sum_cl_code = ""
    kernel_sum_to_4G_cl_code = ""
    kernel_sum_to_8G_cl_code = ""
    bits_width = 0
    for i in range(num_ints_in_first):
        ints.pop(0)

        def _expr(myr):
            return "i[gid] " + (
                ("= " + myr) if i == 0 else
                ("|= (" + myr + " << " + str(bits_width) + ")")
            ) + ";\n"

        def _e2(lookup):
            return _expr(lookup[52-i])

        kernel_sum_cl_code += _e2(_myrand_lookups)
        kernel_sum_to_4G_cl_code += _e2(_myrand_to_4G_lookups)
        kernel_sum_to_8G_cl_code += _e2(_myrand_to_8G_lookups)
        bits_width += STEP

    assert len(ints) == 51 - num_ints_in_first
    myints_str = ",".join(['0']*1+list(reversed([str(x) for x in ints])))

    def _myformat(template, extra_fields={}):
        return template.format(
            **{
                'apply_limit': '0',
                'bufsize': 300000,
                'kernel_sum_cl_code': kernel_sum_cl_code,
                'kernel_sum_to_4G_cl_code': kernel_sum_to_4G_cl_code,
                'kernel_sum_to_8G_cl_code': kernel_sum_to_8G_cl_code,
                'limit': str((1 << 31)-1),
                'myints': myints_str,
                'num_ints_in_first': num_ints_in_first,
                **extra_fields,
            }
        )

    def _update_file_using_template(fn, template, extra_fields={
            }):
        return _update_file(fn=fn, newtext=_myformat(
            template=template, extra_fields=extra_fields,))
    _update_file_using_template(fn="vecinit_prog.ocl", template=(
                '''kernel void vecinit(global unsigned * restrict r, unsigned mystart)
    {{
      const unsigned gid = get_global_id(0);
      r[gid] = gid + mystart;
    }}'''))
    _update_file_using_template(fn="msfc_deal_finder_to_2G.ocl", template=(
                '''kernel void sum(global unsigned * restrict r,
                     global unsigned * restrict i)
    {{
      const unsigned gid = get_global_id(0);
      {kernel_sum_cl_code}
    }}'''))
    _update_file_using_template(fn="msfc_deal_finder_2G_to_4G.ocl", template=(
                '''kernel void sumg(global unsigned * restrict r,
                     global unsigned * restrict i)
    {{
      const unsigned gid = get_global_id(0);
      {kernel_sum_to_4G_cl_code}
    }}'''))
    _update_file_using_template(fn="msfc_deal_finder_4G_to_8G.ocl", template=(
                '''kernel void sumh(global unsigned * restrict r,
                     global unsigned * restrict i)
    {{
      const unsigned gid = get_global_id(0);
      {kernel_sum_to_8G_cl_code}
    }}'''))
    c_loop_template = '''{{
ret = -1;
{{
{int_type} mystart = {start};
while (! is_right)
{{
    cl_event init_evt = vecinit(vecinit_k, que, r_buff, mystart, num_elems);
    cl_event sum_evt = vecsum(
        {my_vecsum_var}, que, i_buff, r_buff, num_elems, init_evt
    );
    cl_int *r_buff_arr = clEnqueueMapBuffer(que, r_buff, CL_FALSE,
            CL_MAP_READ,
            0, num_elems,
            1, &sum_evt, &init_evt, &err);
    ocl_check(err, "clEnqueueMapBuffer r_buff_arr");
    assert(r_buff_arr);

    cl_int *i_buff_arr = clEnqueueMapBuffer(que, i_buff, CL_FALSE,
            CL_MAP_READ,
            0, num_elems,
            1, &sum_evt, &init_evt, &err);
    ocl_check(err, "clEnqueueMapBuffer i_buff_arr");
    assert(i_buff_arr);

    clWaitForEvents(1, &sum_evt);

for(cl_int myiterint=0;myiterint < cl_int_num_elems; ++myiterint)
{{
        if (i_buff_arr[myiterint] == first_int)
        {{
            is_right = true;
            {int_type} rr = r_buff_arr[myiterint];
            for (int n = num_remaining_ints; n >=1; --n)
            {{
                rr = ((rr * (({int_type})214013) +
                    (({int_type})2531011)) & (({int_type})0xFFFFFFFF));
                if ( (((rr >> 16) & {mask}){seed_proc_code}) % n != myints[n])
                {{
                    is_right = false;
                    break;
                }}
            }}
                #if 0
                printf("%lu\\n", ((unsigned long)(mystart+0)));
                #endif
            if ( is_right)
            {{
                ret =
                ((((long long)mystart)+myiterint){ret_offset});

{check_ret}
                goto {cleanup_label};
            }}
        }}
    }}

    const {int_type} newstart = mystart + num_elems;
    #if {apply_limit}
    if (mystart > {limit})
    #else
    if (newstart < mystart)
    #endif
    {{
        break;
    }}
    else
    {{
        mystart = newstart;
    }}
}}
}}
{cleanup_label}:
    if (ret > 0)
    {{
    goto meta_cleanup;
    }}
}}
'''
    c_loop_two_g = _myformat(
        template=c_loop_template,
        extra_fields={
            'check_ret': '',
            'cleanup_label': ('c_loop_two_g' + '__cleanup'),
            'int_type': 'int',
            'mask': '0x7fff',
            'my_vecsum_var': 'vecsum_k',
            'ret_offset': '',
            'seed_proc_code': '',
            'start': '1',
        }
    )
    c_loop_four_g = _myformat(
        template=c_loop_template,
        extra_fields={
            'check_ret': '''
                if (ret >= 0x100000000LL)
                {
                    ret = -1;
                }\n''',
            'cleanup_label': ('c_loop_four_g' + '__cleanup'),
            'int_type': 'unsigned',
            'mask': '0x7fff',
            'my_vecsum_var': 'vecsum_k4G',
            'ret_offset': '',
            'seed_proc_code': '|0x8000',
            'start': '0x80000000U',
        }
    )
    c_loop_eight_g = _myformat(
        template=c_loop_template,
        extra_fields={
            'check_ret': '',
            'cleanup_label': ('c_loop_eight_g' + '__cleanup'),
            'int_type': 'unsigned',
            'limit': '0x100000000LL',
            'mask': '0xffff',
            'my_vecsum_var': 'vecsum_k8G',
            'ret_offset': '+0x100000000LL',
            'seed_proc_code': '+1',
            'start': '0',
        }
    )
    _update_file_using_template(fn="opencl_find_deal_idx.c", extra_fields={
        'c_loop_four_g': c_loop_four_g,
        'c_loop_eight_g': c_loop_eight_g,
        'c_loop_two_g': c_loop_two_g,
        }, template=('''
/*
    Code based on
    https://www.dmi.unict.it/bilotta/gpgpu/svolti/aa201920/opencl/
    under CC0 / Public Domain.

    Also see:
    https://www.dmi.unict.it/bilotta/gpgpu/libro/gpu-programming.html
    by Giuseppe Bilotta.

    Thanks!

*/
#include <assert.h>
#include <stdbool.h>
#include <stdlib.h>
#include <stdio.h>
#include <time.h>
#include "freecell-solver/fcs_dllexport.h"

#define CL_TARGET_OPENCL_VERSION 120

#include <fcs_ocl_boiler.h>

static size_t gws_align_init;
static size_t gws_align_sum;

static cl_event vecinit(cl_kernel vecinit_k, cl_command_queue que,
        cl_mem r_buff, cl_int mystart, cl_int num_elems)
{{
        const size_t gws[] = {{ round_mul_up(((size_t)num_elems),
            gws_align_init) }};
#if 0
        printf("vecinit gws: mystart = %d ; num_elems = %d | gws_align_init ="
            " %zu ; gws[0] = %zu\\n",
            mystart, num_elems, gws_align_init, gws[0]);
#endif
        cl_event vecinit_evt;
        cl_int err;

        cl_uint i = 0;
        err = clSetKernelArg(vecinit_k, i++, sizeof(r_buff), &r_buff);
        ocl_check(err, "r_buff set vecinit arg", i-1);
        err = clSetKernelArg(vecinit_k, i++, sizeof(mystart), &mystart);
        ocl_check(err, "mystart set vecinit arg", i-1);


        err = clEnqueueNDRangeKernel(que, vecinit_k, 1,
                NULL, gws, NULL,
                0, NULL, &vecinit_evt);

        ocl_check(err, "enqueue vecinit");

        return vecinit_evt;
}}

static cl_event vecsum(cl_kernel vecsum_k, cl_command_queue que,
        cl_mem i_buff, cl_mem r_buff, cl_int num_elems,
        cl_event init_evt)
{{
        const size_t gws[] = {{
        round_mul_up(((size_t)num_elems), gws_align_sum) }};
        #if 0
        printf("vecsum gws: %d | %zu = %zu\\n",
        num_elems, gws_align_sum, gws[0]);
        #endif
        cl_event vecsum_evt;
        cl_int err;

        cl_uint i = 0;
        err = clSetKernelArg(vecsum_k, i++, sizeof(r_buff), &r_buff);
        ocl_check(err, "r_buff set vecsum arg", i-1);
        err = clSetKernelArg(vecsum_k, i++, sizeof(i_buff), &i_buff);
        ocl_check(err, "i_buff set vecsum arg", i-1);

        err = clEnqueueNDRangeKernel(que, vecsum_k, 1,
                NULL, gws, NULL,
                1, &init_evt, &vecsum_evt);

        ocl_check(err, "enqueue vecsum");

        return vecsum_evt;
}}

static const int num_ints_in_first = {num_ints_in_first};
static const int num_remaining_ints = 4*13 - num_ints_in_first;
DLLEXPORT long long fc_solve_user__opencl_find_deal(
    const int first_int,
    const int * myints
)
{{
    long long ret = -1;
        const size_t num_elems = {bufsize};
        const cl_int cl_int_num_elems = (cl_int)num_elems;
        const size_t bufsize = num_elems * sizeof(cl_int);

        cl_platform_id p = select_platform();
        cl_device_id d = select_device(p);
        cl_context ctx = create_context(p, d);
        cl_command_queue que = create_queue(ctx, d);
        cl_program vecinit_prog = create_program("vecinit_prog.ocl", ctx, d);
        cl_program prog = create_program("msfc_deal_finder_to_2G.ocl", ctx, d);
        cl_program prog4G =
            create_program("msfc_deal_finder_2G_to_4G.ocl", ctx, d);
        cl_program prog8G =
            create_program("msfc_deal_finder_4G_to_8G.ocl", ctx, d);
        cl_int err;

        cl_kernel vecinit_k = clCreateKernel(vecinit_prog, "vecinit", &err);
        ocl_check(err, "create kernel vecinit");
        cl_kernel vecsum_k = clCreateKernel(prog, "sum", &err);
        ocl_check(err, "create kernel vecsum");
        cl_kernel vecsum_k4G = clCreateKernel(prog4G, "sumg", &err);
        ocl_check(err, "create kernel vecsum_k4G");
        cl_kernel vecsum_k8G = clCreateKernel(prog8G, "sumh", &err);
        ocl_check(err, "create kernel vecsum_k8G");

        /* get information about the preferred work-group size multiple */
        err = clGetKernelWorkGroupInfo(vecinit_k, d,
                CL_KERNEL_PREFERRED_WORK_GROUP_SIZE_MULTIPLE,
                sizeof(gws_align_init), &gws_align_init, NULL);
        ocl_check(err, "preferred wg multiple for init");
        err = clGetKernelWorkGroupInfo(vecsum_k, d,
                CL_KERNEL_PREFERRED_WORK_GROUP_SIZE_MULTIPLE,
                sizeof(gws_align_sum), &gws_align_sum, NULL);
        ocl_check(err, "preferred wg multiple for sum");


bool is_right = false;
cl_mem r_buff = NULL, i_buff = NULL;
r_buff = clCreateBuffer(ctx,
        CL_MEM_READ_WRITE, // | CL_MEM_HOST_NO_ACCESS,
                bufsize, NULL,
                        &err);
        ocl_check(err, "create buffer r_buff");
i_buff = clCreateBuffer(ctx,
        CL_MEM_READ_WRITE, // | CL_MEM_HOST_NO_ACCESS,
                bufsize, NULL,
                        &err);
        ocl_check(err, "create buffer i_buff");
{c_loop_two_g}
{c_loop_four_g}
{c_loop_eight_g}
meta_cleanup:
clReleaseContext(ctx);
clReleaseDevice(d);
clUnloadPlatformCompiler(p);
return ret;
}}
'''))
    return 0


if __name__ == "__main__":
    sys.exit(find_index_main(sys.argv, find_ret))
