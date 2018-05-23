#!/usr/bin/env python3

from TAP.Simple import plan
# TEST:source "$^CURRENT_DIRNAME/../lib/FC_Solve/__init__.py"
from FC_Solve import FC_Solve


class MyTests:
    def test_1(self):
        testname = "test_1"

        fcs = FC_Solve()

        # TEST*$input_cmd_line
        fcs.input_cmd_line(
            "dto 1",
            ["-to", "0123456789", "-dto", "1,0132456789"]
        )

        # TEST
        fcs.num_by_depth_tests_order_is(testname, 2)

        # TEST
        fcs.by_depth_max_depth_of_depth_idx_is(testname, 0, 1)

    def test_2(self):
        testname = "test_1"

        fcs = FC_Solve()

        # TEST*$input_cmd_line
        fcs.input_cmd_line(
            "dto 1",
            ["-to", "0123456789", "-dto", "1,0132456789", "-dto", "50,056234"]
        )

        # TEST
        fcs.num_by_depth_tests_order_is(testname, 3)

        # TEST
        fcs.by_depth_max_depth_of_depth_idx_is(testname, 0, 1)

        # TEST
        fcs.by_depth_max_depth_of_depth_idx_is(testname, 1, 50)

    def main(self):
        self.test_1()
        self.test_2()


if __name__ == "__main__":
    plan(7)
    MyTests().main()
