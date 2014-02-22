require 'json'
require 'json-schema'
require 'set'

class ExtendsResolver

  def self.resolve(hash)
    new.resolve(hash)
  end

  def resolve(hash)
    result = resolve_extends(hash, hash['definitions'] || {}, Set.new)
    result.delete('definitions')
    result
  end

  private

  def resolve_extends(obj, definitions, visited)
    case obj
    when Hash  then resolve_hash(obj, definitions, visited)
    when Array then resolve_list(obj, definitions, visited)
    else obj
    end
  end

  def resolve_hash(src, definitions, visited)
    hash = {}
    if extends = src['$extends']
      extends.each do |reference|
        check_for_recursion(reference, visited)
        hash.update(definition_for(reference, definitions))
      end
      visited += extends
    end
    hash.update(src)
    hash.delete("$extends")
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

json = File.read('apis/source/iam-2010-05-08.resources.json')
json = File.read('apis/source/s3-2006-03-01.resources.json')

errors = JSON::Validator.fully_validate('resources.schema.json', json)
if errors.empty?
  puts 'OK'
else
  puts errors
end
