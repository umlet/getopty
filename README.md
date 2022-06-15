# getopty
**Nimble Julia helper functions for command line scripts -- option parsing, stdout/err capture, end user exception..**

*(Note: this is not (yet) a full-fleged Julia package. The code snippets are a template for quickly creating command line scripts--for potentially air-gapped systems without package manager infrastructure. Vertical code size is minimized, so no tall docstrings.)*

```Getopty``` collects a small set of tiny helpers for command line scripting. The function ```exe()```, for example, runs a shell command and returns the exitcode, and its stdout/stderr as vectors of strings (adapted from a Julia Discourse [post](https://discourse.julialang.org/t/collecting-all-output-from-shell-commands/15592)). The exception type ```ErrorEnduser``` signals that an error is meant to be reported to end users without the intimidating backtrace (e.g., for simple hiccups like "file not found"). A bit more details now on..

---

### Option Parsing

Good option parsers for Julia exist, see [ArgParse.jl](https://github.com/carlobaldassi/ArgParse.jl) or [ArgMacros.jl](https://github.com/zachmatson/ArgMacros.jl) or [Getopt.jl](https://github.com/attractivechaos/Getopt.jl). 

```Getopty``` has a sligthly different focus. It uses a C/GNU/[getopt](https://www.gnu.org/software/libc/manual/html_node/Getopt.html)-inspired approach and it:
* supports **in-order** processing/parsing--one can always randomly permute the option input later after all;
* is maximally **local**--options are defined where the are being ```if```-ed upon;
* checks and **converts** int/float types, and a string like ```-8``` is treated as an *argument* instead of an *option*;
* has a **tiny** API as it happily omits auto-help functionality (usage messages, but that is a purely personal preference, should tell a story with examples rather then doggedly reeling off all options).

Here is an example:
```julia
function main()
    while length(ARGS) > 0
        opt = getopt()

        if opt == "--hello"
            println("Hello, World!")                # this option has no arguments

        elseif opt in ["--happy-birthday", "-h"]
            arg = getarg()                          # <- 1 string argument          <=> getargs("s")[1]
            println("Happy birthday, $(arg)!")      # (getarg() returns value; getargs() a vector)

        elseif opt == "--greet"
            args = getargs()                        # <- 1+ string arguments        <=> getargs("ss*")
            println("Hello everyone, $(join(args, " and "))!")

        elseif opt == "--cheer"
            name,howoften = getargs("si")           # <- 1 string, 1 int
            println("To $(name):", " hip hip, hooray!"^howoften)

        elseif opt == "--smalltalk"
            args = getargs0()                       # <- 0+ strings                 <=> getargs("s*")
            foreach(x->println("Nice weather, $(x)!"), args)

        elseif opt == "--karaoke"
            args = getargs("siff*")                 # <- 1 string, 1 int, and (1 & 0+ floats = 1+ floats)
            println("I sing '$(args[1])'!", " But first a drink!"^args[2])
            for f in args[3:end]  println( f > 0.5 ? "LAAA!" : "La-laa!" )  end

        elseif opt === nothing                      # "naked", option-less arguments
            args = getargs0()                       # could be in error, if a user entered 3 args for '--hooray',
            foreach(x->println("Bye, $(x)!"), args) # ..so some addtl. checks might be needed (or naked args forbidden)
            # @assert length(ARGS) == 0             # <- for example, making sure naked args were at the end

        else  erroruser("unknown command line option '$(opt)'")
        end
    end
end
```

Your script ```party.jl``` with the ```main``` above would then:
```
>party.jl --hello --greet Joe Jack John --cheer Jose 3 --smalltalk Jeremy Julian --karaoke "Final Countdown" 4 .4 .6 .3 .9 -h Jim Joe Jack John Jose Jim
Hello, World!
Hello everyone, Joe and Jack and John!
To Jose: hip hip, hooray! hip hip, hooray! hip hip, hooray!
Nice weather, Jeremy!
Nice weather, Julian!
I sing 'Final Countdown'! But first a drink! But first a drink! But first a drink! But first a drink!
La-laa!
LAAA!
La-laa!
LAAA!
Happy birthday, Jim!
Bye, Joe!
Bye, Jack!
Bye, John!
Bye, Jose!
Bye, Jim!
```
