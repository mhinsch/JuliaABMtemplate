module Jeeps


using Base.Iterators


export default!, par!, ParSpace
export points_on_axis, points_in_space, nth_point
export get_values, get_col_names_types 
export to_cmdl_args, apply_values!, add_to_df!, create_df_cols!, create_df!



abstract type ParAxis end

"An axis of the parameter space that spans values of a single parameter."
struct SingleParAxis{V_ITER} <: ParAxis
	name :: Symbol
	values :: V_ITER
end

"Generates an iterator across all values on the axis returning a tuple (name, value)."
points_on_axis(pc :: SingleParAxis) = zip(repeated(pc.name), pc.values)


"An axis of the parameter space that can simultaneously span values of multiple parameters. Optionally labels for each combination of values can be provided."
struct MultiParAxis{N_ITER, V_ITER} <: ParAxis
	names :: N_ITER
	values :: V_ITER
	keys :: Vector{Symbol}
end


"Generates an iterator across all values on the axis. If keys were provided a tuple (key, (names...), (values...)) is returned otherwise just ((names...), (values...))."
points_on_axis(pc :: MultiParAxis) = isempty(pc.keys) ?
	zip(repeated(pc.names), pc.values) :
	zip(pc.keys, repeated(pc.names), pc.values)


"Set the default value of parameter `name` in ParSpace `j` to `value`."
default!(j, name, value) = par!(j, name, [value])

"Add an axis to the parameter space."
function par! end


function par!(j, name::Symbol, values)
	pc = SingleParAxis(name, values)
	par!(j, pc)
	nothing
end

function par!(j, names, values)
	pc = MultiParAxis(names, values, Symbol[])
	par!(j, pc)
end

function par!(j, nams, vals::Dict)
	pc = MultiParAxis(nams, collect(values(vals)), collect(Symbol.(keys(vals))))
	par!(j, pc)
end


function par!(j, nams, vals::NamedTuple)
	pc = MultiParAxis(nams, collect(values(vals)), collect(keys(vals)))
	par!(j, pc)
end



	
struct ParSpace
	pcs :: Vector{ParAxis}
end


function ParSpace(combis...; defaults=[])
	j = ParSpace([])
	for d in defaults
		default!(j, d[1], d[2])
	end
	for c in combis
		par!(j, c...)
	end
	j
end


points_in_space(j :: ParSpace) = product(points_on_axis.(j.pcs)...)

function nth_point(j :: ParSpace, n)
	i = 1
	for p in points_in_space(j)
		if i == n
			return p
		end
		i += 1
	end
	nothing
end


par!(j, pc) = push!(j.pcs, pc)


# plain version
to_cmdl_arg(arg :: Tuple{Symbol, VAL}, prefix, sep = " ") where {VAL} =
	"$(prefix)$(arg[1])$sep\"$(arg[2])\" "

apply_value!(params, arg :: Tuple{Symbol, VAL}) where {VAL}  =
	setproperty!(params, arg[1], arg[2])

get_values(arg :: Tuple{Symbol, VAL}) where {VAL} = [arg[2]]

get_col_names_types(pc :: SingleParAxis{VI}) where {VI} =
	[(pc.name, eltype(pc.values))]

# multi par version
function to_cmdl_arg(arg :: Tuple{ITER1, ITER2}, prefix, sep = " ") where {ITER1, ITER2}
	ret = ""
	for (name, value) in zip(arg...)
		ret *= to_cmdl_arg((name, value), prefix, sep)
	end
	ret
end

function to_cmdl_arg(arg :: Tuple{Symbol, ITER1, ITER2}, prefix, sep = " ") where {ITER1, ITER2}
    to_cmdl_arg((arg[2], arg[3]), prefix, sep)
end

function apply_value!(params, arg :: Tuple{ITER1, ITER2}) where {ITER1, ITER2}
	for (name, value) in zip(arg...)
		apply_value!(params, (name, value))
	end
end

function apply_value!(params, arg :: Tuple{Symbol, ITER1, ITER2}) where {ITER1, ITER2}
	apply_value!(params, (arg[2], arg[3]))
end

get_values(arg :: Tuple{ITER1, ITER2}) where {ITER1, ITER2} =
	collect(arg[2])

function get_values(arg :: Tuple{Symbol, ITER1, ITER2}) where {ITER1, ITER2}
	ret = []
	push!(ret, arg[1])
	append!(ret, collect(arg[3]))
	ret
end

function get_col_names_types(pc :: MultiParAxis{NI, VI}) where {NI, VI}
	if isempty(pc.keys)
		[ (n, eltype(typeof(v))) for (n, v) in zip(pc.names, pc.values) ]
	else
		nvs = [ (n, eltype(typeof(v))) for (n, v) in zip(pc.names, pc.values) ]
		[(Symbol(join(pc.names, "__")), Symbol) ; nvs]
	end 
end


# entire param combi
function to_cmdl_args(pc, prefix, sep = " ")
	cmdl = ""
	for arg in pc
		cmdl *= to_cmdl_arg(arg, prefix, sep)
	end
	cmdl
end

function apply_values!(params, pc)
	for arg in pc
		apply_value!(params, arg)
	end
	params
end

function get_pc_values(pc)
	ret = []
	for arg in pc
		append!(ret, get_values(arg))
	end
	ret
end

add_to_df!(df, pc) = push!(df, get_pc_values(pc))


function to_cmdl_args(j :: ParSpace, prefix, sep = " ")
	ret = String[]
	for pc in points_in_space(j)
		cmdl = ""
		for arg in pc
			cmdl *= to_cmdl_arg(arg, prefix, sep)
		end
		push!(ret, cmdl)
	end
	ret
end

function get_col_names_types(j :: ParSpace)
	ret = Tuple{Symbol, Type}[]
	for pc in j.pcs
		append!(ret, get_col_names_types(pc))
	end
	ret
end


function create_df_cols!(j :: ParSpace, df)
	cnt = get_col_names_types(j)
	for nt in cnt
		df[!, nt[1]] = Vector{nt[2]}()
	end
	df
end

function create_df!(j :: ParSpace, df)
	create_df_cols!(j, df)
	for pc in points_in_space(j)
		add_to_df!(pc, df)
	end
	df
end


end
