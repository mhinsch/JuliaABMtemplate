module Scheduler

export PQScheduler, PQScheduler2, isempty, schedule!, time_now, time_next, schedule_in!, next!, upto!, unschedule!, reset!


using DataStructures


mutable struct PQScheduler{TIME}
	queue :: PriorityQueue{Any, TIME}
	actions :: Dict{Any, Function}
	now :: TIME
end

PQScheduler{TIME}() where {TIME} = PQScheduler{TIME}(
	PriorityQueue{Any, TIME}(), Dict{Any, Function}(), TIME(0))


Base.isempty(scheduler::PQScheduler{TIME}) where {TIME} = isempty(scheduler.queue)

"add a single item"
function schedule!(fun, obj, at, scheduler)
	scheduler.queue[obj] = at
	scheduler.actions[obj] = fun
#	println("<- ", at)
end


time_now(scheduler) = scheduler.now
time_next(scheduler) = isempty(scheduler) ? scheduler.now : peek(scheduler.queue)[2]


"add a single item at `wait` time from now"
function schedule_in!(fun, obj, wait, scheduler)
	t = time_now(scheduler) + wait
	schedule!(fun, obj, t, scheduler)
end


"run the next action"
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
"run actions up to `time`"
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

function unschedule!(scheduler, obj::Any)
	delete!(scheduler.queue, obj)
	delete!(scheduler.actions, obj)
end

function reset!(scheduler)
	empty!(scheduler.actions)
	empty!(scheduler.queue)
	scheduler.time = typeof(scheduler.time)(0)
end


mutable struct PQScheduler2{TIME}
	queue :: PriorityQueue{Any, Tuple{TIME, Function}}
	now :: TIME
end

PQScheduler2{TIME}() where {TIME} = PQScheduler2{TIME}(
	PriorityQueue{Any, Tuple{TIME, Function}}(), TIME(0))


Base.isempty(scheduler::PQScheduler2{TIME}) where {TIME} = isempty(scheduler.queue)

"add a single item"
function schedule!(fun, obj, at, scheduler::PQScheduler2)
	scheduler.queue[obj] = (at, fun)
#	println("<- ", at)
end


time_next(scheduler::PQScheduler2) = isempty(scheduler) ? scheduler.now : peek(scheduler.queue)[2][1]


"run the next action"
function next!(scheduler::PQScheduler2)
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
function upto!(scheduler::PQScheduler2, atime)
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

function unschedule!(scheduler::PQScheduler2, obj::Any)
	delete!(scheduler.queue, obj)
end

function reset!(scheduler::PQScheduler2)
	empty!(scheduler.queue)
	scheduler.time = typeof(scheduler.time)(0)
end
end
