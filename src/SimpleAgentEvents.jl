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

function build_spawn_func(func_name, model_name, pois_func_name, agent_type)
	:(
	function $(esc(model_name)).$func_name(agent::$(esc(agent_type)), sim)
		$(esc(model_name)).$pois_func_name(agent, sim)
	end
	)
end

pois_func_name() = :process_poisson
spawn_func_name() = :spawn

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

			const scheduler = SC.PQScheduler{Float64}()
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


macro add_processes(model_name, sim, agent_decl, decl)
	pois_func, spawn_func = gen_functions(model_name, sim, agent_decl, decl)

	Expr(:toplevel, pois_func, spawn_func)
end



end
