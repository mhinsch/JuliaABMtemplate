module SimpleAgentEvents

export @processes, @add_processes, Scheduler


using MacroTools
using Distributions
using StaticArrays

include("Scheduler.jl")


# TODO
# useful return values in process_*
# include line numbers in error messages
# fixed waiting times (dirac)
# in which module should rand. println, etc. be executed?

"Internal use only. Parse a @processes declaration."
function parse_declarations(lines)
	pois = []

	for line in lines
		# filter out line numbers
		if typeof(line) == LineNumberNode
			continue
		end

		if ! iscall(line, :~) || length(line.args) < 2
			error("event declaration expected: @<DISTR>(<RATE>) ~ <COND> => <ACTION>")
		end

		args = rmlines(line.args)

		distr = args[2]
		distr_name = distr.args[1]
		action = args[3]

		if distr_name == Symbol("@poisson")
			push!(pois, (distr, action))
# TODO
#		elseif distr_name == Symbol("@dirac")
#			push!(dir, (distr, action))
		else
			error("unknown distribution $(distr_name)")
		end
	end

	pois
end


# add all poisson events
"Internal use only. Build the function body for the main scheduling function."
function build_poisson_function(poisson_actions, func_name, model_name, agent_name, agent_type, sim)

	# general bits of the function body
	func = :(function $(esc(model_name)).$func_name($(esc(agent_name)) :: $(esc(agent_type)), $(esc(sim)))
			rates = zeros(MVector{$(length(poisson_actions))})
		end)

	func_body = func.args[2].args

	action_ifs = []

	i = 1
	for (d, a) in poisson_actions
		if !iscall(a, :(=>))
			error("event declaration expected: @<DISTR>(<RATE>) ~ COND => ACTION")
		end

		rate = d.args[3]

		cond_act = rmlines(a.args)
		condition = cond_act[2]
		action = cond_act[3]

		# condition check
		check = :(if $(esc(condition))
				rates[$i] = $(esc(rate))
			end)
		push!(func_body, check)

		# check if selected, execute
		ai = :(
			if rnd < rates[$i]
#				println("@ ", w_time, " -> ", $(string(action)))

				$(esc(model_name)).schedule_in!($(esc(agent_name)), w_time) do $(esc(agent_name))::$(esc(agent_type))
					active = $(esc(action))

					for obj in active 
						# should not be needed as queue as well as actions are unique in 
						# agents
						# $(esc(:unschedule!))($(esc(:scheduler))($(esc(sim))), obj)
						$(esc(model_name)).$func_name(obj, $sim)
					end
				end

				return
			end;

			# we might want to check if this is optimal
			rnd -= rates[$i]
			)
		push!(action_ifs, ai)

		i += 1
	end

	# bits between conditions and selection
	push!(func_body, :(rate = $(esc(:sum))(rates);
		if rate == 0.0
			return
		end;
		w_time = rand(Exponential(1.0/rate));
		rnd = rand() * rate
		))

	append!(func_body, action_ifs)

	# if we didn't select *any* action something went wrong
	push!(func_body, :(println("No action selected! ", rnd, " ", rate);return))

	func
end

"Internal use only. Build the spawn function."
function build_spawn_func(func_name, model_name, pois_func_name, agent_type)
	:(
	function $(esc(model_name)).$func_name(agent::$(esc(agent_type)), sim)
		$(esc(model_name)).$pois_func_name(agent, sim)
	end
	)
end

pois_func_name() = :process_poisson
spawn_func_name() = :spawn


"Internal use only. Build the scheduling and spawn functions from the declaration."
function gen_functions(model_name, sim, agent_decl, decl)
	# some superficial sanity checks
	@capture(agent_decl, agent_name_ :: agent_type_) ||
		error("@processes expects an agent declaration as 3rd argument")

	if typeof(decl) != Expr || decl.head != :block
		error("@processes expects a declaration block as 4th argument")
	end

	# sort by distributions
	pois = parse_declarations(decl.args)

	# *** scheduling function
	pois_func = build_poisson_function(pois, pois_func_name(), model_name, agent_name, agent_type, sim)

	# *** and we also need a function to get an agent started
	spawn_func = build_spawn_func(spawn_func_name(), model_name, pois_func_name(), agent_type)

	pois_func, spawn_func
end


"Generate event-based scheduling for a model.

`@processes(model_name, sim, agent_decl, decl)`

# Arguments
- `model_name`: The name of the model and of the module to be generated.
- `sim`: An arbitrary object. Can be used to e.g. keep parameters, random number generators or context information.
- `agent_decl`: The *fully typed* declaration (`anObj :: AType`) of the objects to be scheduled.
- `decl`: A block containing action declarations (see below).

# Details
`@processes` will parse the action declarations and generate a module
`model_name` containing the functions and objects necessary to start and run the model.

## Action syntax
An action declaration has the form:

`@<DISTR>(<RATE>) ~ <COND> => <ACTION>`

with:

- `<DISTR>`: The distribution of the waiting time. Currently only `poisson` is supported.
- `<RATE>`: An arbitrary expression evaluating to a number. This expression will be executed *every time* this action is scheduled.
- `<COND>`: A boolean expression. Only when this expression is true *at the time of scheduling* will the action be executed.
- `<ACTION>`: The action to be executed. This can be any expression that is syntactically valid on the right hand side of an assignment. The expression has to return an iterable object containing all objects that need to be rescheduled as a consequence of the action *including the current object itself*. If the returned iterable is empty no objects will be scheduled.

## Generated module

The generated module will contain a `PQScheduler` object and all functions
defined for `PQScheduler` redefined to remove the `scheduler` argument (the
scheduler object defined in the module will automatically be filled in).

The module also exports a function `spawn` that will add an object to the scheduling.

# Example

```Julia
mutable struct Agent
	x :: Float64
end

struct Param
	p :: Float64
end

function update!(a, p)
	a.x += p.p
	[a]
end

@processes Test par agent::Agent begin
	@poisson(1.0)	~ agent.x<10.0		=> update!(agent, par)
	@poisson(agent.x * 2)	~ true				=> 
		begin 
			a.x = 0
			[x] 
		end
end

p = Param(1.0)
a = Agent(0.0)

Test.spawn(a, p)

for i in 1:10
	Test.next!()
end
```
"
macro processes(model_name, sim, agent_decl, decl)
	pois_func, spawn_func = gen_functions(model_name, sim, agent_decl, decl)

	pfn = pois_func_name()
	sfn = spawn_func_name()

	# the entire bunch of code
	mod = :(module $(esc(model_name)) 
			using SimpleAgentEvents
			import SimpleAgentEvents.Scheduler
			const SC = SimpleAgentEvents.Scheduler

			export $(esc(pfn)), $(esc(sfn))

			const scheduler = SC.PQScheduler2{Float64}()
			$(esc(:isempty))() = SC.isempty(scheduler)
			$(esc(:schedule!))(fun, obj, at) = SC.schedule!(fun, obj, at, scheduler)
			$(esc(:time_now))() = SC.time_now(scheduler)
			$(esc(:time_next))() = SC.time_next(scheduler)
			$(esc(:schedule_in!))(fun, obj, t) = SC.schedule_in!(fun, obj, t, scheduler)
			$(esc(:next!))() = SC.next!(scheduler)
			$(esc(:upto!))(atime) = SC.upto!(scheduler, atime)
			$(esc(:unschedule!))(obj) = SC.unschedule!(obj, scheduler) 
			$(esc(:reset!))() = SC.reset!(scheduler)
			$(esc(:scheduler))() = scheduler
		end)

	mod_body = mod.args[3].args
	push!(mod_body, esc(Expr(:function, pfn)))
	push!(mod_body, esc(Expr(:function, sfn)))

	Expr(:toplevel, mod, pois_func, spawn_func)
end

"Add additional processes (potentially with different agent types) to an existing scheduling module.
For details see the documentation of `@processes`."
macro add_processes(model_name, sim, agent_decl, decl)
	pois_func, spawn_func = gen_functions(model_name, sim, agent_decl, decl)

	Expr(:toplevel, pois_func, spawn_func)
end



end
