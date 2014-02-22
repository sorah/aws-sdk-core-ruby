module Aws
  class Resource
    class Definition

      # @param [Hash] source
      def initialize(source)
        @source = source
      end

      # @return [Hash]
      attr_reader :source

      # @param [Class<Resource>] namespace
      def apply(namespace)
        define_resources(namespace)
      end

      private

      def define_resources(namespace)
        @source['resources'].each do |name, definition|
          resource = define_resource(namespace, name, definition)
        end
        @source['resources'].each do |name, definition|
          resource = namespace.const_get(name)
          define_load(resource, definition['load'])
          define_create(name, namespace, resource, definition['create'])
          define_enumerate(pluralize(name), namespace, resource, definition['enumerate'])
          define_associations(namespace, resource, definition['associations'] || {})
          define_actions(resource, definition['actions'] || {})
          if resource.identifiers.count < 2
            define_reference(name, namespace, resource, {}) 
          end
        end
      end

      def define_resource(namespace, name, definition)
        resource_class = Resource.define(namespace.client_class)
        resource_class.resource_name = name
        definition['identifiers'].each do |identifier|
          resource_class.add_identifier(underscore(identifier))
        end
        namespace.const_set(name, resource_class)
      end

      def define_load(resource, definition)
        if definition
          resource.load_operation = LoadOperation.new(
            request: define_request(definition['request']),
            load_path: underscore(definition['shapePath'])
          )
        end
      end

      def define_create(name, namespace, resource, definition)
        if definition
          namespace.add_operation("create_#{underscore(name)}", CreateOperation.new(
            request: define_request(definition['request']),
            builder: define_builder(resource, definition['resource'])
          ))
        end
      end

      def define_enumerate(name, namespace, resource, definition)
        if definition
          namespace.add_operation(name, EnumerateOperation.new(
            request: define_request(definition['request']),
            builder: define_builder(resource, definition['resource'])
          ))
        end
      end

      def define_associations(namespace, resource, associations)
        associations.each do |name, association|
          case
          when association['has']
            method_name = :define_has_association
            reference_class = namespace.const_get(association['has'])
          when association['hasMany']
            method_name = :define_has_many_association
            reference_class = namespace.const_get(association['hasMany'])
          else
            "unknown association type #{association.inspect}"
            raise ArgumentError, msg
          end
          send(method_name, underscore(name), resource, reference_class, association)
        end
      end

      def define_has_association(name, resource, reference_class, definition)
        define_reference(name, resource, reference_class, definition['resource'])
      end

      def define_has_many_association(name, resource, reference_class, definition)
        define_create(singularize(name), resource, reference_class, definition['create'])
        define_enumerate(name, resource, reference_class, definition['enumerate'])
        if reference = definition['resource']
          define_reference(singularize(name), resource, reference_class, reference)
        end
      end

      def define_reference(name, resource, reference_class, definition)
        resource.add_operation(underscore(name), ReferenceOperation.new(
          builder: define_builder(reference_class, definition)
        ))
      end

      def define_actions(resource, actions)
        actions.each do |name, action|
          resource.add_operation(underscore(name), Operation.new(
            request: define_request(action['request'])
          ))
        end
      end

      def define_request(definition)
        Request.new(
          method_name: underscore(definition['operation']),
          params: request_params(definition['params'] || []))
      end

      def request_params(params)
        params.map do |definition|
          param_class =
            case definition['sourceType']
            when 'identifier' then RequestParams::Identifier
            when 'dataMember' then RequestParams::DataMember
            when 'string'     then RequestParams::String
            when 'integer'    then RequestParams::Integer
            else
              msg = "unhandled source type` #{definition['sourceType']}"
              raise ArgumentError, msg
            end
          source = definition['source']
          param_class.new(
            param_class.literal? ? source : underscore(source),
            underscore(definition['target'])
          )
        end
      end

      def define_builder(resource_class, definition)
        Resource::Builder.new(
          resource_class: resource_class,
          sources: builder_sources(definition['identifiers'] || []),
          load_path: underscore(definition['shapePath'])
        )
      end

      def builder_sources(sources)
        sources.map do |definition|
          source_class =
            case definition['sourceType']
            when 'identifier'       then BuilderSources::Identifier
            when 'dataMember'       then BuilderSources::DataMember
            when 'requestParameter' then BuilderSources::RequestParameter
            when 'responsePath'     then BuilderSources::ResponsePath
            else
              msg = "unhandled source type` #{definition['sourceType']}"
              raise ArgumentError, msg
            end
          source_class.new(
            underscore(definition['source']),
            underscore(definition['target'])
          )
        end
      end

      def underscore(str)
        if str
          str.gsub(/\w+/) { |part| Util.underscore(part) }
        end
      end

      def pluralize(str)
        underscore(str) + 's'
      end

      def singularize(str)
        case str
        when /(\w+)ies$/ then $1 + 'y'
        when /(\w+)en$/ then $1
        when /(\w+)es$/ then $1
        when /(\w+)s$/ then $1
        else
          raise "failed singular inflection of `#{str}'"
        end
      end

    end
  end
end
