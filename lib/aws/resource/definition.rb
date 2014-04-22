require 'set'

module Aws
  class Resource

    # Given a resource definition document, a {Definition} can build a set
    # of related resource classes.
    class Definition

      # @param [Hash] source
      def initialize(source)
        @source = source
      end

      # @return [Hash]
      attr_reader :source

      # @param [String] service_name
      # @param [Class<Seahorse::Client::Base>] client_class
      # @return [Class<Resource>] Returns the service resource class.
      def define_service(service_name, client_class)
        service = define_resource_classes(service_name.to_s, client_class)
        define_operations(service)
        define_subresources(service)
        service
      end

      private

      # Defines and returns a resource class for the service.  It additionally
      # defines a resource class for each resource definition.  These are
      # added to the service as constants.
      #
      #     SvcClass
      #     SvcClass::Resource1
      #     SvcClass::Resource2
      #
      # @param [String] service_name
      # @param [Class<Seahorse::Client::Base>] client_class
      # @return [Class<Resource>] Returns the service resource class.
      def define_resource_classes(service_name, client_class)
        service = resource_class(service_name, client_class, svc_definition)
        each_resource do |name, definition|
          resource_class = resource_class(name, client_class, definition)
          service.const_set(name, resource_class)
        end
        service
      end

      # Defines a new resource class.  This specifies the client class,
      # and the identifiers, but it does NOT apply any operations.
      # @param [String] name
      # @param [Class<Seahorse::Client::Base>] client_class
      # @return [Class<Resource>] Returns the new resource class.
      def resource_class(name, client_class, definition)
        resource_class = Resource.define(client_class)
        resource_class.resource_name = name
        (definition['identifiers'] || []).each do |identifier|
          resource_class.add_identifier(underscore(identifier))
        end
        resource_class
      end

      # Populates a resource class with operations.  These are extracted
      # from the resource definition of actions and associations.
      # @param [Class<Resource>] service The service resource class.
      # @return [void]
      def define_operations(service)
        define_resource_operations(service, service, svc_definition)
        each_resource do |name, definition|
          define_resource_operations(service, service.const_get(name), definition)
        end
      end

      # Populates a resource class with operations.  These are extracted
      # from the resource definition of actions and associations.
      # @param [Class<Resource>] service The service or namespace.  All
      #   resources referenced in the definition must be defined as
      #   constants on the service.
      # @param [Class<Resource>] resource
      # @param [Hash] definition
      # @return [void]
      def define_resource_operations(service, resource, definition)
        define_load(resource, definition['load'])
        define_actions(service, resource, definition['actions'] || {})
        define_has_many(service, resource, definition['hasMany'] || {})
        define_has_some(service, resource, definition['hasSome'] || {})
        define_has_one(service, resource, definition['hasOne'] || {})
      end

      def define_subresources(service)
        top_level_resources = Set.new(@source['resources'].keys)
        each_resource do |parent_name, definition|
          parent = service.const_get(parent_name)
          sub_resources = definition['subResources'] || {}
          (sub_resources['resources'] || []).each do |child_name|
            top_level_resources.delete(child_name)
            child = service.const_get(child_name)
            method_name = underscore(child_name.sub(/^#{parent_name}/, ''))
            parent.add_operation(method_name, ReferenceOperation.new(
              builder: Builder.new(
                resource_class: child,
                sources: sub_resources['identifiers'].map { |source, target|
                  BuilderSources::Identifier.new(
                    underscore(source),
                    underscore(target)
                  )
                }
              )
            ))
          end
        end
        top_level_resources.each do |name|
          resource_class = service.const_get(name)
          if resource_class.identifiers.count > 1
            raise "top level resource with plural identifiers: #{name}"
          else
            service.add_operation(underscore(name), ReferenceOperation.new(
              builder: Builder.new(resource_class: resource_class)
            ))
          end
        end
      end

      def define_load(resource, definition)
        if definition
          resource.load_operation = DataOperation.new(
            request: define_request(definition['request']),
            path: underscore(definition['path'])
          )
        end
      end

      def define_actions(service, resource, actions)
        actions.each do |name, action|
          type = operation_type(action)
          send("define_#{type}", service, resource, name, action)
        end
      end

      def define_operation(service, resource, name, definition)
        resource.add_operation(underscore(name), Operation.new(
          request: define_request(definition['request'])
        ))
      end

      def define_data_operation(service, resource, name, definition)
        resource.add_operation(underscore(name), DataOperation.new(
          request: define_request(definition['request']),
          path: underscore(definition['path'])
        ))
      end

      def define_resource_operation(service, resource, name, definition)
        resource.add_operation(underscore(name), ResourceOperation.new(
          request: define_request(definition['request']),
          builder: define_builder(service, definition['resource'])
        ))
      end

      def define_enumerate_resource_operation(service, resource, name, definition)
        resource.add_operation(underscore(name), EnumerateResourceOperation.new(
          request: define_request(definition['request']),
          builder: define_builder(service, definition['resource']))
        )
      end

      def define_request(definition)
        Request.new(
          method_name: underscore(definition['operation']),
          params: request_params(definition['params'] || [])
        )
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
              msg = "unhandled param source type `#{definition['sourceType']}'"
              raise ArgumentError, msg
            end
          source = definition['source']
          param_class.new(
            param_class.literal? ? source : underscore(source),
            underscore(definition['target'])
          )
        end
      end

      def define_has_many(service, resource, has_many)
        has_many.each do |name, definition|
          define_enumerate_resource_operation(service, resource, name, definition)
        end
      end

      def define_has_some(service, resource, has_some)
        has_some.each do |name, definition|
          resource.add_operation(underscore(name), ReferenceOperation.new(
            builder: define_builder(service, definition['resource'])
          ))
        end
      end

      def define_has_one(service, resource, has_one)
        has_one.each do |name, definition|
          resource.add_operation(underscore(name), ReferenceOperation.new(
            builder: define_builder(service, definition['resource'])
          ))
        end
      end

      def define_builder(service, definition)
        Resource::Builder.new(
          resource_class: service.const_get(definition['type']),
          sources: builder_sources(definition['identifiers'] || []),
          load_path: underscore(definition['path'])
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
              msg = "unhandled identifier source type `#{definition['sourceType']}'"
              raise ArgumentError, msg
            end
          source_class.new(
            underscore(definition['source']),
            underscore(definition['target'])
          )
        end
      end

      def operation_type(action)
        case action.keys
        when ['request', 'resource'] then :resource_operation
        when ['request', 'path']     then :data_operation
        when ['request']             then :operation
        else
          msg = "unhandled operation: #{action.inspect}"
          raise Errors::DefinitionError, msg
        end
      end

      def svc_definition
        @source['service']
      end

      def each_resource(&block)
        @source['resources'].each(&block)
      end

      def underscore(str)
        if str
          str.gsub(/\w+/) { |part| Util.underscore(part) }
        end
      end

      def pluralize(str)
        underscore(str) + 's'
      end

    end
  end
end
