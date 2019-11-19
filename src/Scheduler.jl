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
#	println("<- ", at)
end


time_now(scheduler) = scheduler.now
time_next(scheduler) = isempty(scheduler) ? scheduler.now : peek(scheduler.queue)[2]


"add a single item at `wait` time from now"
function schedule_in!(todo, wait, scheduler)
	t = time_now(scheduler) + wait
	schedule!(todo, t, scheduler)
end


"run the next action"
function once!(scheduler)
#	println("! ", scheduler.now)

	if isempty(scheduler)
		return
	end

	a, t = peek(scheduler.queue)

	scheduler.now = t
	dequeue!(scheduler.queue)()
end


"run actions up to `time`"
function upto!(scheduler, time)
#	println("! ", scheduler.now, " ... ", time)

	while !isempty(scheduler)
		a, t = peek(scheduler.queue)
		if t > time
			break
		end

		scheduler.now = t
		dequeue!(scheduler.queue)()
	end

	scheduler.now = time

	scheduler
end


end
