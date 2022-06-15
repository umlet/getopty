#!/bin/bash
###############################################################################
###############################################################################
#= start of bash code section (a Julia multi-line comment, so don't remove the '=' here)

# This exec uses an explicit '--' which is thrown away by Julia; subsequent user input of '--' goes through.
# You can add additional Julia options here -- like '-t 4'.
exec julia  "${BASH_SOURCE[0]}"  --  "$@"
# The exec has replaced the bash script call; this line and subsequent ones are never reached in bash

=#  # end of bash code section/Julia multi-line comment
###############################################################################
###############################################################################
# start of Julia code section


###############################################################################
module Errory
export erroruser, ErrorEnduser
struct ErrorEnduser <: Exception  msg::String  end  # meant to be printed without stacktrace, for end users
erroruser(msg) = throw(ErrorEnduser(msg))
# Base.showerror(io::IO, ex::ErrorEnduser) = print(io, ex.msg)
# Base.showerror(io::IO, ex::ErrorEnduser, bt; backtrace=true) = showerror(io, ex)
end  # module
###############################################################################


###############################################################################
module Filey
export fiter

import Base.Iterators
function fiter(f;   dashstdin=true, skipcomment=true, skipempty=true, stateful=true)
    RET = ( dashstdin && f in ["-", '-'] )  ?  eachline(stdin)  :  eachline(f)
    skipcomment  &&  ( RET = Iterators.filter(x -> !startswith(x, '#'), RET) )
    skipempty    &&  ( RET = Iterators.filter(!=(""), RET) )
    stateful     &&  ( RET = Iterators.Stateful(RET) )
    return RET
end
end  # module
###############################################################################


###############################################################################
module Convy
export isint, isfloat, toint, tofloat, trytoint, trytofloat

isint(x) = tryparse(Int64, x) !== nothing
isfloat(x) = tryparse(Float64, x) !== nothing

toint(x) = parse(Int64, x)
tofloat(x) = parse(Float64, x)

trytoint(x) = tryparse(Int64, x)
trytofloat(x) = tryparse(Float64, x)
end  # module
###############################################################################


###############################################################################
module Exey
export exe
function exe(scmd::String; fail=true, okexits=[])
    cmd = Cmd(["bash", "-c", scmd])
    out = Pipe()                                                            ; err = Pipe()
    process = run(pipeline(cmd, stdout=out, stderr=err), wait=false);  wait(process);  exitcode = process.exitcode

    close(out.in)                                                           ; close(err.in)
    out0 = @async String(read(out))                                         ; err0 = @async String(read(err))
    out1 = fetch(out0)                                                      ; err1 = fetch(err0)
    length(out1) > 0  &&  last(out1) == '\n'  &&  (out1 = chop(out1))       ; length(err1) > 0  &&  last(err1) == '\n'  &&  (err1 = chop(err1))
    outs = out1 != "" ? split(out1, '\n') : String[]                        ; errs = err1 != "" ? split(err1, '\n') : String[]

    exitcode != 0  &&  !(exitcode in okexits)  &&  fail  &&  error("exe: OS system command failed: '$(scmd)'; stderr:\n$(err1)")
    return (; exitcode, outs, errs)
end
end
###############################################################################


###############################################################################
module Getopty
export getopt, getargs, getargs0, getarg

using ..Errory
using ..Convy

function isopt(s::AbstractString)
    s == "--"               &&  return true         # caller should handle this
    startswith(s, "--")     &&  return true
    s == "-"                &&  return false        # for 'stdin' convention
    startswith(s, "-")      &&  return !isfloat(s)  # treats negative numbers as arguments, not options (.e., '-1' is not a valid option)
    return false
end

_lastopt = nothing
function getopt(;from=ARGS)::Union{String, Nothing}
    RET = nothing
    if length(from) > 0
        isopt(from[1])  &&  ( RET = popfirst!(from) )
    end
    global _lastopt = RET
    return RET
end

function getargs(stypes::AbstractString="ss*"; from=ARGS, stopatopt=true, opt=_lastopt)  # opt ist just used for error msgs
    RET = []
    tryto = Dict('s'=>identity, 'i'=>trytoint, 'f'=>trytofloat)
    typenames = Dict('i'=>"integer", 'f'=>"float")
    errmsgprefix = opt !== nothing  ?  "at option '$(opt)': "  :  ""

    length(stypes) == 0  &&  error("getargs: stypes empty")
    # '^' and '$' match full string  ||  's', 'i', or f, at least once: [s|i|f]+  ||  one '*' optionally: \*?
    !occursin(r"^[s|i|f]+\*?$", stypes)  &&  error("getargs: invalid stypes '$(stypes)'")

    types = collect(stypes);  typerest = nothing
    types[end] == '*'  &&  ( pop!(types);  typerest = pop!(types) )

    for type in types
        length(from) == 0  &&  erroruser(errmsgprefix * "not enough arguments; at least $(length(types)) required")
        s = popfirst!(from)
        ( stopatopt && isopt(s) )  &&  erroruser(errmsgprefix * "argument list contains the option '$(s)'")
        ( tmp = tryto[type](s) ) !== nothing  ?  push!(RET, tmp)  :  erroruser(errmsgprefix * "argument '$(s)' not of type $(typenames[type])")
    end
    if typerest !== nothing
        while length(from) > 0
            ( stopatopt && isopt(from[1]) )  &&  break
            s = popfirst!(from)
            (tmp = tryto[typerest](s)) !== nothing  ?  push!(RET, tmp)  :  erroruser(errmsgprefix * "argument '$(s)' not of type $(typenames[typerest])")
        end
    end
    return RET
end
getargs0(; from=ARGS, stopatopt=true, opt=_lastopt) = getargs("s*"; from=from, stopatopt=stopatopt, opt=opt)
function getarg(stype::Union{AbstractString, Char}="s"; from=ARGS, stopatopt=true, opt=_lastopt)
    length(stype) != 1  &&  error("getarg: invalid stype '$(stype)': only single type specifier allowed")
    return getargs(string(stype); from=from, stopatopt=stopatopt, opt=opt)[1]
end
end  # module
###############################################################################


###############################################################################
function _main()
    try  main()
    catch e  
        isa(e, Base.IOError)  &&  e.code == Base.UV_EPIPE  &&  exit(0)  # suppress SIGPIPE in pipeline
        isa(e, InterruptException)  &&  ( @warn "computation interrupted";  exit(1) )
        isa(e, Errory.ErrorEnduser)  &&  ( println(stderr, "ERROR: ", e.msg);  exit(99) )
        rethrow()
    end
end
###############################################################################


###############################################################################
###############################################################################
###############################################################################
###############################################################################
###############################################################################
# new code here

using .Errory
using .Getopty
using .Exey



#=
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
=#

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
###############################################################################
if abspath(PROGRAM_FILE) == @__FILE__
    _main()  
end
###############################################################################
# v 0.1.0
