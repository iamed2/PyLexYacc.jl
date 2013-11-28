module PyLexYacc
	export rule, lexer, parser, parse, parserule, skip, lineno, set_lineno, lexpos, lexspan,
		token, skip

	import Base: getindex, setindex!, length, get, keys, values, isempty, show, error

	using PyCall

	@pyimport ply.lex as lex
	@pyimport ply.yacc as yacc

	const AttrDict = pyimport("attrdict")["AttrDict"]  # wrapper that allows attribute access


	const vars = pyeval("vars", PyObject)  # gets public attributes from an object
	const str = pyeval("str", PyObject)  # gets a string representation of the object

	# PLY relies on reflection an rule functions must have cPython function attributes 
	# and a docstring (__doc__ property). This lambda wrapper enables this.
	const funfactory = pyeval("lambda y: lambda x: y(x)", PyObject)


	# YaccProduction wrapper type
	type YaccProduction
		t::PyObject
	end

	# index methods map 1-indexing to 0-indexing
	getindex(p::YaccProduction, i::Integer) = p.t[:__getitem__](i-1)
	getindex(p::YaccProduction, r::Range) = p.t[:__getslice__](r.start-1, r.start-1+r.len)
	setindex!(p::YaccProduction, value, i::Integer) = p.t[:__setitem__](i-1, value)

	# map methods as functions
	length(p::YaccProduction) = p.t[:__len__]()
	lineno(p::YaccProduction, n::Integer) = p.t[:lineno](n)
	set_lineno(p::YaccProduction, n::Integer, lineno::Integer) = p.t[:set_lineno](n, lineno)
	setlineno! = set_lineno
	linespan(p::YaccProduction, n::Integer) = tuple(p.t[:linespan](n))
	lexpos(p::YaccProduction, n::Integer) = p.t[:lexpos](n)
	lexspan(p::YaccProduction, n::Integer) = p.t[:lexspan](n)
	error(p::YaccProduction) = p.t[:error]()


	# Wrapper type that enables field access by string index
	abstract PyObjectDictWrapper<:Associative{String,Any}

	getindex(tok::PyObjectDictWrapper, key::String) = tok.o[symbol(key)]
	setindex!(tok::PyObjectDictWrapper, value, key::String) = tok.o[symbol(key)] = value
	get(tok::PyObjectDictWrapper, key::String) = getindex(tok, key)
	function get(tok::PyObjectDictWrapper, key::String, default)
		skey = symbol(key)
		if haskey(tok.o, skey)
			return getindex(tok, key)
		else
			return default
		end
	end
	haskey(tok::PyObjectDictWrapper, key::String) = haskey(pycall(vars, PyAny, tok.o), key)
	keys(tok::PyObjectDictWrapper) = keys(pycall(vars, PyAny, tok.o))
	values(tok::PyObjectDictWrapper) = values(pycall(vars, PyAny, tok.o))
	isempty(tok::PyObjectDictWrapper) = isempty(pycall(vars, PyAny, tok.o))
	show(io::IO, tok::PyObjectDictWrapper) = show(io, pycall(str, PyAny, tok.o))


	# LexToken wrapper type
	type LexToken<:PyObjectDictWrapper
		o::PyObject
	end


	# Lexer wrapper type
	type Lexer<:PyObjectDictWrapper
		o::PyObject
	end

	# map methods as functions
	token(lex::Lexer) = LexToken(lex.o[:token]())
	skip(lex::Lexer, n::Integer) = lex.o[:skip](n)


	function rule(fn::Function)
		function wrapper(x)  # wraps input and unwraps output
			ret = fn(LexToken(x), Lexer(x[:lexer]))
			if isa(ret, LexToken)
				return ret.o
			else
				return ret
			end
		end
		return pycall(funfactory, PyObject, wrapper)
	end

	function rule(fn::Function, pattern::String)
		rule_func = rule(fn)
		rule_func[:__doc__] = pattern
		return rule_func
	end

	function parserule(fn::Function)
		return pycall(funfactory, PyObject, x->fn(YaccProduction(x)))  # wraps input
	end

	function parserule(fn::Function, pattern::String)
		rule_func = parserule(fn)
		rule_func[:__doc__] = pattern  # add docstring
		return rule_func
	end


	# Get a module as a symbol dict. Should be a convert method?
	function Dict(m::Module)
		return (Symbol=>Any)[name=>getfield(m, name) for name in names(m, true, false)]
	end


	function lexer(tokrules::Associative; kwargs...)
		# first argument to lex.lex() is the module containing the rules
		return lex.lex(pycall(AttrDict, PyObject, tokrules); kwargs...)
	end

	# Allow rules to be specified as a symbol dict or a module.
	lexer(m::Module; kwargs...) = lexer(Dict(m); kwargs...)


	function parser(parserules::Associative, start::String; kwargs...)
		# module is *not* first argument, and "module" cannot be used as a kwarg in Julia
		# here is some magic to make it work.
		push!(kwargs, (:module, pycall(AttrDict, PyObject, parserules)))
		return pywrap(yacc.yacc(;start=start, kwargs...))
	end

	parser(parserules::Associative; kwargs...) = parser(parserules, parserules[:start]; kwargs...)

	# Allow rules to be specified as a symbol dict or a module.
	parser(m::Module; kwargs...) = parser(Dict(m), m.start; kwargs...)
	parser(m::Module, start::String; kwargs...) = parser(Dict(m), start; kwargs...)


	function parse(parser, lexer, string; kwargs...)
		return parser.parse(string; lexer=lexer, kwargs...)
	end
end