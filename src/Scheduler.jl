module Scheduler

export PQScheduler, PQScheduler2, isempty, schedule!, time_now, time_next, schedule_in!, next!, upto!, unschedule!, reset!


using DataStructures


"A simple scheduler based on PriorityQueue."
mutable struct PQScheduler{TIME}
	queue :: PriorityQueue{Any, TIME}
	actions :: Dict{Any, Function}
	now :: TIME
end

"Construct an empty PQScheduler with a give TIME type."
PQScheduler{TIME}() where {TIME} = PQScheduler{TIME}(
	PriorityQueue{Any, TIME}(), Dict{Any, Function}(), TIME(0))

"Returns true if the scheduler does not contain any actions."
Base.isempty(scheduler::PQScheduler{TIME}) where {TIME} = isempty(scheduler.queue)

"Add a single item to the scheduler. Adds function `fun` to be called on `obj` at time `at` to `scheduler`."
function schedule!(fun, obj, at, scheduler)
	scheduler.queue[obj] = at
	scheduler.actions[obj] = fun
#	println("<- ", at)
end

"Time stamp of the last action that was executed by `scheduler`."
time_now(scheduler) = scheduler.now
"Time stamp of the next action to be executed by `scheduler` or `time_now` if it is empty."
time_next(scheduler) = isempty(scheduler) ? scheduler.now : peek(scheduler.queue)[2]


"Add a single item (`fun` to be called on `obj`) at `wait` time from now to `scheduler`."
function schedule_in!(fun, obj, wait, scheduler)
	t = time_now(scheduler) + wait
	schedule!(fun, obj, t, scheduler)
end


"Run the next action in `scheduler` or do nothing if empty. Returns the action's return value."
function next!(scheduler)
#	println("! ", scheduler.now)

	if isempty(scheduler)
		return
	end

	obj, time = peek(scheduler.queue)

	scheduler.now = time
	dequeue!(scheduler.queue)
	fun = scheduler.actions[obj]
	delete!(scheduler.actions, obj)
	fun(obj)
end

# we could implement this using repeated calls to next but that
# would require redundant calls to peek
"Run actions in `scheduler` up to time `atime`. Returns the scheduler."
function upto!(scheduler, atime)
#	println("! ", scheduler.now, " ... ", time)

	while !isempty(scheduler)
		obj, time = peek(scheduler.queue)

		if time > atime
			scheduler.now = atime
			break
		end

		scheduler.now = time
		dequeue!(scheduler.queue)
		fun = scheduler.actions[obj]
		delete!(scheduler.actions, obj)
		fun(obj)
	end

	scheduler
end

"Remove action for `obj` from `scheduler`."
function unschedule!(scheduler, obj::Any)
	delete!(scheduler.queue, obj)
	delete!(scheduler.actions, obj)
end

"Remove all actions from `scheduler` and reset time to 0."
function reset!(scheduler)
	empty!(scheduler.actions)
	empty!(scheduler.queue)
	scheduler.time = typeof(scheduler.time)(0)
end


# *** alternative, simpler implementation
# this is actually substantially slower with more memory allocation

mutable struct PQScheduler2{TIME}
	queue :: PriorityQueue{Any, Tuple{TIME, Function}}
	now :: TIME
end

PQScheduler2{TIME}() where {TIME} = PQScheduler2{TIME}(
	PriorityQueue{Any, Tuple{TIME, Function}}(), TIME(0))


Base.isempty(scheduler::PQScheduler2{TIME}) where {TIME} = isempty(scheduler.queue)

"add a single item"
function schedule!(fun, obj, at, scheduler::PQScheduler2{T}) where{T}
	scheduler.queue[obj] = (at, fun)
#	println("<- ", at)
end


time_next(scheduler::PQScheduler2{T}) where{T} = isempty(scheduler) ? scheduler.now : peek(scheduler.queue)[2][1]


"run the next action"
function next!(scheduler::PQScheduler2{T}) where{T}
#	println("! ", scheduler.now)

	if isempty(scheduler)
		return
	end

	obj, (time, fun) = peek(scheduler.queue)

	scheduler.now = time
	dequeue!(scheduler.queue)
	fun(obj)
end

# we could implement this using repeated calls to next but that
# would require redundant calls to peek
"run actions up to `time`"
function upto!(scheduler::PQScheduler2{T}, atime) where{T}
#	println("! ", scheduler.now, " ... ", time)

	while !isempty(scheduler)
		obj, (time, fun) = peek(scheduler.queue)

		if time > atime
			scheduler.now = atime
			break
		end

		scheduler.now = time
		dequeue!(scheduler.queue)
		fun(obj)
	end

	scheduler
end

function unschedule!(scheduler::PQScheduler2{T}, obj::Any) where{T}
	delete!(scheduler.queue, obj)
end

function reset!(scheduler::PQScheduler2{T}) where{T}
	empty!(scheduler.queue)
	scheduler.time = typeof(scheduler.time)(0)
end
end
