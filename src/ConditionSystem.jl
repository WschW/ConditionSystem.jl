module ConditionSystem

struct CondtionFrameKey end

export signal!, withhandler, get_restarts

struct HandlerEntry
    condition::DataType
    handler::Function
end

struct ConditionFrame
    handlerStack::Vector{HandlerStackKey}
    restarts::Vector{Symbol}
end

struct Restart

end

function get_conditionframe()
    key = HandlerStackKey()
    task_storage = task_local_storage()
    if haskey(task_storage,key)
        return task_storage[key]::ConditionFrame
    end
    out = ConditionFrame()
    task_storage[key] = out
end

get_handlers() = get_conditionframe().handlerStack
get_restarts() = get_conditionframe().restarts


restart(x::Symbol) = restart!(Restart(x))
restart(x::Restart) = throw(restart)

propogate_restart(x::Restart) = rethrow(x)
propogate_restart(x::Any) = rethrow(x)
propogate_restart(x::Any,match) = rethrow(x)
propogate_restart(x::Restart,match) = x == match ? nothing : rethrow(x)


function push_handler!(condition::DataType,handler::Function)
    push!(get_handlers(),HandlerEntry(condition,handler))
end

function pop_handler!()
    pop!(get_handlers())
end

"""
searches for an applicable handler case if it finds a handler case such that condition <:
"""
function signal!(datum::DataType,args...)
    handlers = get_handlers()
    pos = findlast(x->datum <: x.condition,handlers)
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
function withhandler(fn,condition::DataType,handler::Function; restart::Union{Function,Symbol} = nothing)
    frame = get_conditionframe()
    handlers = frame.handlers
    push!(handlers,HandlerEntry(condition,handler))
    if restart === nothing
        try
            fn()
        finally
            pop!(handlers)
        end
    else
        try
            run = true
            while run
                run = false
                try
                    fn()
                catch e
                    propogate_restart(e,restart)
                    run = true
                end
            end
        finally
            pop!(handlers)
        end
    end
end

function withhandler(fn,condition::Tuple{<:Type},handler::Tuple{Function})
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
