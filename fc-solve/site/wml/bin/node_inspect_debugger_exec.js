"use strict";
const startCLI = require("./start-cli");

const cli_global = startCLI([
    "node_modules/.bin/qunit",
    "lib/for-node/test-code-emcc.js",
]);

function onFatal(error) {
    cli_global.quit();
    throw error;
}
const timeout = 20 * 1000;

class Queue {
    constructor() {
        const that = this;
        that.idx = 0;
        that.cmds = [
            'sb("lib/for-node/js/web-fc-solve-tests.js", 2);',
            'sb("lib/for-node/js/libfreecell-solver.min.js", 1833)',
            "cont",
        ];
        that.cmds = ["sb(7)", "cont"];
        that.cmds = ["exec [20+4]"];
    }
    run(cli) {
        const that = this;
        console.log("in run();:\n<<<\n" + cli.output + "\n>>>\n");
        if (that.idx === that.cmds.length) {
            console.log("foooooooollllllkkkkkkkkkk\n");
            return;
        } else {
            console.log("apploo idx=" + that.idx + ";\n");
        }
        const mycmd = that.cmds[that.idx++];
        console.log("vwooby idx=" + that.idx + " cmd=" + mycmd + ";\n");
        cli.command(mycmd)
            .then(() => {
                console.log("sweeet idx=" + that.idx + ";\n");
            })
            .catch((error) => {
                console.log(
                    "cli.command returned error at idx=" +
                        that.idx +
                        "; error=<<<" +
                        error +
                        ">>>\n",
                );
            });
        return;
        cli.then(() => {
            console.log("output=[[[[[[[[[[" + cli.output + "]]]]]]]]]]\n");
            cli.waitForPrompt(timeout);
        }).then(() => {
            that.run(cli);
        });
    }
}

const queue = new Queue();

cli_global
    .waitForInitialBreak(timeout)
    .then(() => cli_global.waitForPrompt(timeout))
    .then(() => {
        console.log("test0=<<" + cli_global.output + ">>\n");
    })
    // .then(() => cli_global.command("exec [typeof heartbeat, typeof process.exit]"))
    .then(() => cli_global.command("exec [20+4]"))
    .then(() => {
        console.log("test1=<<" + cli_global.output + ">>\n");
    })
    .then(() => cli_global.command('exec ["2nd command"]'))
    .then(() => {
        console.log("test2=<<" + cli_global.output + ">>\n");
    })
    .then(() => {
        console.log("sparkle\n");
        queue.run(cli_global);
    })
    // .then(() => {console.log(cli_global.output);})
    .then(() => cli_global.quit())
    .then(null, onFatal);
