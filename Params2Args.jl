module Params2Args

export fields_as_args!, create_from_args, @create_from_args

using ArgParse
using REPL


"add all fields of a type as command line arguments"
function fields_as_args!(arg_settings, t :: Type)
	fields = fieldnames(t)
	for f in fields
		fdoc =  REPL.stripmd(REPL.fielddoc(t, f))
		add_arg_table!(arg_settings, ["--" * String(f)], Dict(:help => fdoc))
	end
end

"create object from command line arguments, using module mod as context"
function create_from_args(args, t :: Type, mod)
	par_expr = Expr(:call, t.name.name)

	fields = fieldnames(t)

	for key in eachindex(args)
		if args[key] == nothing || !(key in fields)
			continue
		end
		val = parse(fieldtype(t, key), args[key])
		push!(par_expr.args, Expr(:kw, key, val))
	end

	mod.eval(par_expr)
end

"create object from command line arguments in current module"
macro create_from_args(arguments, t)
	:(create_from_args($(esc(arguments)), $(esc(t)), $(__module__)))
end

end
