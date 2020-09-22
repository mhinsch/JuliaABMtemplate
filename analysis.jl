### import analysis library

using Util.Observation
using Util.StatsAccumulator



### setup some handy shortcuts

const MV = MVAcc{Float64}		# mean, variance
const MM = MaxMinAcc{Float64}	# min, max
const I = Iterators



### helper functions for output

import Util.Observation.prefixes    # we need this so we can add a method to prefixes
# these are used to construct the column names in the output file
prefixes(::Type{<:MV}) = ["mean", "var"]
prefixes(::Type{<:MM}) = ["max", "min"]
prefixes(::Type{<:CountAcc}) = ["#"]

# teach Julia how to print CountAcc, MM and MV objects
Base.show(out::IO, acc :: MM) = print(out, acc.max, "\t", acc.min)
Base.show(out::IO, acc :: CountAcc) = print(out, acc.n)
function Base.show(out::IO, acc :: MV)
	res = result(acc)
	print(out, res[1], "\t", res[2])
end



### declare analysis
# this generates two functions:
# print_header_<name>(<file>)
# print_stats_<name>(<file>, <model>)
# where <name> is the first argument to the @observe macro

@observe stat_log model begin
	@show "time" time_now(model.scheduler)

	@for a in model.pop begin
		@stat("n_susceptible", 	CountAcc) <| (a.status == susceptible)
		@stat("n_infected", 	CountAcc) <| (a.status == infected)
		@stat("n_immune", 		CountAcc) <| (a.status == immune)
		@stat("n_dead", 		CountAcc) <| (a.status == dead)
	end

	@for a in I.filter(ag->ag.status==infected, model.pop) begin
		@stat("inf_contacts", MV, MM) <| Float64(length(a.contacts))
		@stat("inf_periph", MV, MM) <| sqrt((a.x-0.5)^2 + (a.y-0.5)^2)
	end

	# counting could also have been done like this:
	# @show "n_susceptible"	count(ag -> ag.status == susceptible, model.pop)
end

