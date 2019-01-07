module ConditionSystem

struct HandlerStackKey end

#export AbstractCondition, signal!, withhandler, AbstractCondition

abstract type AbstractCondition end

struct HandlerEntry
    condition::Type{<:AbstractCondition}
    handler::Function
end

function get_handlers()
    key = HandlerStackKey()
    task_storage = task_local_storage()
    if haskey(task_storage,key)
        return task_storage[key]::Vector{HandlerEntry}
    end
    out = HandlerEntry[]
    task_storage[key] = out
end

function push_handler!(condition::Type{<:AbstractCondition},handler::Function)
    push!(get_handlers(),HandlerEntry(condition,handler))
end

function pop_handler!()
    pop!(get_handlers())
end

"""
searches for an applicable handler case, returns true if found and run, else false
"""
function signal!(datum::Type{<:AbstractCondition},args...)
    handlers = get_handlers()
    pos = findfirst(x->datum <: x.condition,handlers)
    if pos === nothing
        false
    else
        handlers[pos].handler(args...)
        true
    end
end

"""
runs the given function and handles signals
"""
function withhandler(fn,condition::Type{<:AbstractCondition},handler::Function)
    handlers = get_handlers()
    push!(handlers,HandlerEntry(condition,handler))
    try
        fn()
    finally
        pop!(handlers)
    end
end

function withhandler(fn,condition::Tuple{<:Type{<:AbstractCondition}},handler::Tuple{Function})
    len = length(condition)
    len == length(handler) ||  throw(DimensionMismatch("Differing numbers of conditions and handlers"))
    for pos = 1:len
        @inbounds push!(handlers,HandlerEntry(condition[pos],handler[pos]))
    end
    try
        fn()
    finally
        for pos = 1:len
            pop!(handlers)
        end
    end
end


end # module
