module Scheduler

export PQScheduler, isempty, schedule!, time_now, time_next, schedule_in!, next!, upto!


using DataStructures

mutable struct PQScheduler{TIME}
	queue :: PriorityQueue{Function, TIME}
	now :: TIME
end

PQScheduler{TIME}() where {TIME} = PQScheduler{TIME}(PriorityQueue{Function, TIME}(), TIME(0))


Base.isempty(scheduler::PQScheduler{TIME}) where {TIME} = isempty(scheduler.queue)

"add a single item"
function schedule!(todo, at, scheduler)
	scheduler.queue[todo] = at
end


time_now(scheduler) = scheduler.now
time_next(scheduler) = isempty(scheduler) ? scheduler.now : peek(scheduler.queue)[2]


"add a single item at `wait` time from now"
function schedule_in!(todo, wait, scheduler)
	t = time_now(scheduler) + wait
	schedule!(todo, t, scheduler)
end


"run the next action"
function next!(scheduler)
	if isempty(scheduler)
		return
	end

	f = dequeue!(scheduler.queue)
	f()
end

"run actions up to `time`"
function upto!(scheduler, time)
	while !isempty(scheduler) && time_next(scheduler) > time
		next!(scheduler)
	end
	scheduler
end


end
