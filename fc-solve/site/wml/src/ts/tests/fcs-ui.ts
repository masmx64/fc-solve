import * as test_strings from "../web-fcs-tests-strings";

const ms_deal_24 = `4C 2C 9C 8C QS 4S 2H
5H QH 3C AC 3H 4H QD
QC 9S 6H 9H 3S KS 3D
5D 2S JC 5C JH 6D AS
2D KD TH TC TD 8D
7H JS KH TS KC 7C
AH 5S 6S AD 8H JD
7S 6C 7D 4D 8S 9D
`;
const solution_for_deal_24__default = test_strings.dict["24_default_ascii"];
const solution_for_deal_24__default__with_unicoded_suits =
    test_strings.dict["24_default_unicode_suits"];

function _get_solution(): string {
    return $("#output").val() as string;
}
const flipped_deal__with_leading_line = `
JH 5D 8S 7S KH TS 9D AH
9C 3D 5C AC JD TC JC 7C
5S 9S KD 9H 7D 4S 2C 6D
KC 2S QC 6C 4C 5H QS 8D
6S 3C 3H QH 8H QD TH TD
2H AD 4D KS 6H JS 2D 7H
AS 8C 3S 4H

`;
const flipped_deal = `# MS Freecell Deal no. 240 flipped
JH 5D 8S 7S KH TS 9D AH
9C 3D 5C AC JD TC JC 7C
5S 9S KD 9H 7D 4S 2C 6D
KC 2S QC 6C 4C 5H QS 8D
6S 3C 3H QH 8H QD TH TD
2H AD 4D KS 6H JS 2D 7H
AS 8C 3S 4H

`;
const non_flipped = `JH 9C 5S KC 6S 2H AS
5D 3D 9S 2S 3C AD 8C
8S 5C KD QC 3H 4D 3S
7S AC 9H 6C QH KS 4H
KH JD 7D 4C 8H 6H
TS TC 4S 5H QD JS
9D JC 2C QS TH 2D
AH 7C 6D 8D TD 7H`;
class Ops {
    constructor(
        public assert,
        public done,
        public on_stdin_change,
        public on_output_change,
    ) {
        return;
    }
    public wrap_stdin() {
        const that = this;
        return that.on_stdin_change(that, that.assert, that.done);
    }
    public wrap_output() {
        const that = this;
        return that.on_output_change(that, that.assert, that.done);
    }
}
let count: number = 0;
const on_flip_stdin = (my_operations, assert, done) => {
    const board: string = $("#stdin").val() as string;

    assert.deepEqual(
        board,
        non_flipped.replace(/^/gms, ": ") + "\n",
        "got the double-flipped text",
    );
    done();
    if (++count < 2) {
        $("#stdin").val(flipped_deal__with_leading_line);
        $("#run_do_solve").click();
    }
};
const on_flip_output = (my_operations, assert, done) => {
    const board_parse__wrap = $("#board_parse__wrap");

    assert.deepEqual(
        board_parse__wrap.find("h2").text(),
        "Board Input Parsing Warnings:",
        "warnings",
    );
    my_operations.on_stdin_change = on_flip_stdin;
    $("#fcs_flip_deal").click();
    done();
};
const on_stdin_initial_layout = (my_operations, assert, done) => {
    const board: string = $("#stdin").val() as string;
    // alert(board);
    // const board = $("#deal_number").text();
    // assert.equal(board, "KC", "foo");
    // TEST
    assert.deepEqual(
        board.replace(/^#[^\n]*\n/gms, "").replace(/^: /gms, ""),
        ms_deal_24,
        "got the initial layout text",
    );

    // TEST
    assert.deepEqual(_get_solution(), "", "solution is empty at start");
    $("#run_do_solve").click();
    done();
};
const on_change_initial_layout = (my_operations, assert, done) => {
    const sol: string = _get_solution();

    // TEST
    assert.deepEqual(sol, solution_for_deal_24__default, "solution was filled");
    my_operations.on_stdin_change = (a, b, c) => {};
    my_operations.on_output_change = on_flip_output;
    $("#stdin").val(flipped_deal);
    $("#run_do_solve").click();

    done();
};
function my_func(qunit: QUnit, my_callback: () => void) {
    qunit.module("FC_Solve.WebUI", () => {
        qunit.test("populate_deal", (assert) => {
            assert.expect(7);

            let done = assert.async(7);
            let my_operations = new Ops(
                assert,
                done,
                on_stdin_initial_layout,
                on_change_initial_layout,
            );
            (() => {
                $("#stdin").change(() => {
                    return my_operations.wrap_stdin();
                });
                $("#output").change(() => {
                    return my_operations.wrap_output();
                });
                $("#deal_number").val("24");
                $("#preset").val("default");
                $("#one_based").prop("checked", false);
                $("#populate_input").click();
                done();
            })();
        });
    });

    my_callback();

    return;
}

export function test_js_fc_solve_class(qunit: QUnit, my_callback: () => void) {
    my_func(qunit, my_callback);
    return;
}
