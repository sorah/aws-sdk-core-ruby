require 'json'
require 'set'

class ResourceLinter

  DEFINITION_KEYS = %w(resources definitions)

  RESOURCE_KEYS = %w(
    dataType identifiers
    create load enumerate
    actions associations
  )

  RESOURCE_CREATE_KEYS = %w(operation path data resourceIdentifiers)

  RESOURCE_LOAD_KEYS = %w(operation params dataPath)

  class FormatError < StandardError; end

  class JSONPath

    def initialize(keys = [])
      @keys = keys
    end

    def resolve(hash, &block)
      yield(@keys.inject(hash) { |h, key| h[key] })
    end

    def +(key)
      self.class.new(@keys + [key])
    end

    def to_s
      'json' + @keys.map{ |key| "[#{key.inspect}]" }.join
    end

  end

  def self.lint(json)
    new.lint(json)
  end

  def lint(json)
    @definition = ExtendsResolver.resolve(JSON.load(json))
    #puts JSON.pretty_generate(@definition['resources']['Object'], indent: '  ')
    lint_definition(@definition)
  end

  private

  def at(path, &block)
    path.resolve(@definition, &block)
  end

  def lint_definition(definition)
    path = JSONPath.new
    require_keys(DEFINITION_KEYS, definition, path) do |key|
      send("lint_#{key.downcase}", definition[key], path + key)
    end
  end

  def lint_resources(resources, path)
    resources.keys.each do |resource_name|
      require_upper_camel_case(resource_name, path + resource_name)
      lint_resource(path + resource_name)
    end
  end

  def lint_resource(path)
    at(path) do |resource|
      require_keys(RESOURCE_KEYS, resource, path) do |key|
        send("lint_resource_#{key.downcase}", resource[key], path + key)
      end
    end
  end

  def lint_resource_datatype(data_type, path)
    require_type(String, data_type, path)
    # TODO : validate the datatype has been defined in the Coral model
  end

  def lint_resource_identifiers(identifiers, path)
    require_type(Array, identifiers, path)
    identifiers.each.with_index do |identifier_name, n|
      require_upper_camel_case(identifier_name, path + n)
    end
  end

  def lint_resource_create(rules, path)
    require_type([Hash, nil], rules, path)
    if rules
      require_keys(RESOURCE_CREATE_KEYS, rules, path) do |key|
        send("lint_resource_create_#{key.downcase}", rules[key], path + key)
      end
    end
  end

  def lint_resource_create_operation(operation_name, path)
    require_valid_operation_name(operation_name, path)
  end

  def lint_resource_create_path(jamespath, path)
    require_type([String, nil], jamespath, path)
  end

  def lint_resource_create_data(value, path)
    require_boolean(value, path)
  end

  def lint_resource_create_resourceidentifiers(identifiers, path)
    require_valid_identifier_sources(identifiers, %w(param path), path)
  end

  def lint_resource_load(rules, path)
    require_type([Hash, nil], rules, path)
    if rules
      require_keys(RESOURCE_LOAD_KEYS, rules, path) do |key|
        send("lint_resource_load_#{key.downcase}", rules[key], path + key)
      end
    end
  end

  def lint_resource_load_operation(operation_name, path)
    require_valid_operation_name(operation_name, path)
  end

  def lint_resource_load_params(params, path)
  end

  def lint_resource_load_datapath(jmespath, path)
  end

  def lint_resource_enumerate(enumerate_rules, path)
    require_type([Hash, nil], enumerate_rules, path)
    # TODO : not finished
  end

  def lint_resource_actions(actions, path)
    require_type(Hash, actions, path)
    # TODO : not finished
  end

  def lint_resource_associations(associations, path)
    require_type(Hash, associations, path)
    # TODO : not finished
  end

  def lint_definitions(definitions, path)
    # definitions pre-resolved by the $extends resolver, we don't need
    # to descend into the nested structure
    require_type(Hash, definitions, path)
  end

  def require_keys(keys, hash, path, &block)
    keys.each do |key|
      unless hash.key?(key)
        msg = "missing required #{key.inspect} entry at #{path}; "
        raise FormatError, msg
      end
    end
    hash.keys.each do |key|
      unless keys.include?(key)
        msg = "unexpected key #{key.inspect} at #{path}; "
        msg << "valid keys include: #{keys.map(&:inspect).join(', ')}"
        raise FormatError, msg
      end
      yield(key) if block_given?
    end
  end

  def require_type(klasses, obj, path)
    klasses = [klasses] unless klasses.is_a?(Array)
    unless klasses.any? { |klass| klass === obj }
      expected_klass = klasses.map { |k| k.nil? ? 'nil' : k.name }.join(' or ')
      msg = "expected #{expected_klass} value at #{path}, got #{obj.class.name}"
      raise FormatError, msg
    end
  end

  def require_boolean(value, path)
    unless [true, false].include?(value)
      msg = "expected an boolean at #{path}, got #{value.inspect}"
      raise FormatError.new(msg)
    end
  end

  def require_upper_camel_case(string, path)
    unless string.match(/^([A-Z][a-z]+)+$/)
      msg = "expected an UpperCamelString at #{path}, got `#{string}'"
      raise FormatError.new(msg)
    end
  end

  def require_valid_operation_name(operation_name, path)
    require_upper_camel_case(operation_name, path)
    # TODO : validate operation name is defined in model
  end

  def require_valid_operation_path(jamespath, path)
    require_type(String, jamespath, path)
    # TODO : validate jamespath expression is well formed
    # TODO : validate jamespath expression resolves in model
  end

  def require_valid_identifier_sources(identifiers, sources, path)
    # TODO : validate each identifier is defined in the resource identifiers
    # TODO : validate each identifier sources from a valid source
    # TODO : validate "param" sourced identifiers exist in model operation input
    # TODO : validate "path" sourced identifiers exist in model operation output
    # TODO : validate "identifier" sourced identifiers are defined as identifiers
    # TODO : validate "data" sourced identifiers are defined a dataType members
  end

end

class ExtendsResolver

  def self.resolve(hash)
    new.resolve(hash)
  end

  def resolve(hash)
    resolve_extends(hash, hash['definitions'] || {}, Set.new)
  end

  private

  def resolve_extends(obj, definitions, visited)
    case obj
    when Hash  then resolve_hash(obj, definitions, visited)
    when Array then resolve_list(obj, definitions, visited)
    else obj
    end
  end

  def resolve_hash(hash, definitions, visited)
    hash = hash.dup
    if extends = hash.delete('$extends')
      extends.each do |reference|
        check_for_recursion(reference, visited)
        hash.update(definition_for(reference, definitions))
      end
      visited += extends
    end
    hash.each_with_object({}) do |(k,v), h|
      h[k] = resolve_extends(v, definitions, visited)
    end
  end

  def resolve_list(array, definitions, visited)
    array.map { |value| resolve_extends(value, definitions, visited) }
  end

  def check_for_recursion(ref, visited)
    if visited.include?(ref)
      msg = "recursive references: #{visited.map(&:inspect).join(', ')}"
      raise ArgumentError, msg
    end
  end

  def definition_for(ref, definitions)
    if definitions[ref].is_a?(Hash)
      definitions[ref]
    else
      msg = "expected json[\"definitions\"][#{ref.inspect}] to be a Hash"
      raise ArgumentError, msg
    end
  end

end

ResourceLinter.lint(File.read('./apis/source/s3-2006-03-01.resources.json'))
