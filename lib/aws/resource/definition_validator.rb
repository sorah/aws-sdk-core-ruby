require 'multi_json'
require 'json-schema'

module Aws
  class Resource
    class DefinitionValidator

      ID_DUPLICATED = "Resource '%s' has duplicate identifiers."

      ID_PREFIXED = "Resource '%s' identifier '%s' should not be prefixed by the resource name."

      ID_REQUIRES_SHAPE = "Resource '%s' identifier '%s' has a memberName but 'shape' is not set."

      ID_NOT_FOUND = "Resource '%s' identifier '%s' has the memberName '%s' which is not a member of the shape '%s'."

      SHAPE_UNDEFINED = "Resource '%s' references an undefined shape '%s'."

      SHAPE_NOT_STRUCTURE = "Resource '%s' has a non-structure shape '%s'."

      LOAD_REQUIRES_SHAPE = "Resource '%s' has defined 'load' but has not defined 'shape'."

      LOAD_OPERATION_NOT_FOUND = "Resource '%s' load operation '%s' does not exist in the API."

      LOAD_PATH_BAD = "Resource '%s' defines a 'load' path that does not resolve to a '%s'."

      OPERATION_DOES_NOT_ACCEPT_INPUT = '%s request defines params when the operation does not accept input.'

      INVALID_PARAM_TARGET = '%s request defines a param target of "%s" which is invalid.'

      PARAM_SOURCE_BAD = "%s request defines a param with sourceType '%s'; %s may not source dataMembers."

      PARAM_TYPE_BAD = "%s request defines a param with target '%s' and sourceType '%s' which resolves to a '%s' shape."

      SCHEMA_PATH = File.expand_path(File.join([
        File.dirname(__FILE__), '..', '..', '..', 'resources.schema.json'
      ]))

      # @param [Hash] definition
      # @param [Hash] api
      def initialize(definition, api)
        @definition = definition
        @api = api
        @errors = []
        validate_against_schema
        validate_against_api if @errors.empty?
      end

      # @return [Array<String>]
      attr_reader :errors

      private

      def validate_against_schema
        schema = MultiJson.load(File.read(SCHEMA_PATH))
        @errors = JSON::Validator.fully_validate(schema, @definition)
      end

      def validate_against_api
        validate_service
        validate_resources
      end

      def validate_service
        validate_service_actions
        validate_service_has_many
      end

      def validate_service_actions
        each_service_action do |action|
        end
      end

      def validate_service_has_many
        each_service_has_many do |name, has_many|
        end
      end

      def validate_resources
        each_resource do |resource_name, definition|
          validate_resource_identifiers(resource_name, definition)
          validate_resource_shape(resource_name, definition)
          validate_resource_load(resource_name, definition)
        end
      end

      def validate_resource_identifiers(name, resource)
        if resource['identifiers']
          validate_resource_identifiers_uniq(name, resource)
          validate_resource_identifiers_not_prefixed(name, resource)
          validate_resource_identifiers_member_names(name, resource)
        end
      end

      def validate_resource_identifiers_uniq(name, resource)
        names = resource['identifiers'].map { |i| i['name'] }
        unless names == names.uniq
          @errors << ID_DUPLICATED % [name]
        end
      end

      def validate_resource_identifiers_not_prefixed(name, resource)
        resource['identifiers'].each do |identifier|
          if identifier['name'].match(/^#{name}/)
            @errors << ID_PREFIXED % [name, identifier['name']]
          end
        end
      end

      def validate_resource_identifiers_member_names(name, resource)
        resource['identifiers'].each do |identifier|
          if identifier['memberName']
            validate_resource_identifier_member_name(name, resource, identifier)
          end
        end
      end

      def validate_resource_identifier_member_name(name, resource, identifier)
        msg = ID_REQUIRES_SHAPE % [name, identifier['name']]
        require_shape(resource, msg) do |shape|
          if shape['members'] && shape['members'][identifier['memberName']].nil?
            @errors << ID_NOT_FOUND % [name, identifier['name'], identifier['memberName'], resource['shape']]
          end
        end
      end

      def validate_resource_shape(name, resource)
        if shape_name = resource['shape']
          shape = @api['shapes'][shape_name]
          if shape.nil?
            @errors << SHAPE_UNDEFINED % [name, resource['shape']]
          elsif shape['type'] != 'structure'
            @errors << SHAPE_NOT_STRUCTURE % [name, resource['shape']]
          end
        end
      end

      def validate_resource_load(name, resource)
        if resource['load']
          require_shape(resource) do
            request = resource['load']['request']
            validate_resource_load_request(name, resource, request)
          end
        end
      end

      def validate_resource_load_request(name, resource, request)
        if operation = @api['operations'][request['operation']]
          validate_resource_load_request_params(name, resource, request, operation)
          validate_resource_load_path(name, resource, operation)
        else
          @errors << LOAD_OPERATION_NOT_FOUND % [name, request['operation']]
        end
      end

      def validate_resource_load_request_params(name, resource, request, operation)
        if params = request['params']
          prefix = "Resource '%s' load" % [name]
          if operation['input']
            input_shape = @api['shapes'][operation['input']['shape']]
            params.each do |param|
              if param['sourceType'] == 'dataMember'
                @errors << PARAM_SOURCE_BAD % [prefix, 'dataMember', 'load operations']
              elsif shape_name = resolve_param_path(operation['input'], param['target'])
                validate_static_param_types(prefix, shape_name, param)
              else
                @errors << INVALID_PARAM_TARGET % [prefix, param['target']]
              end
            end
          else
            @errors << OPERATION_DOES_NOT_ACCEPT_INPUT % [prefix]
          end
        end
      end

      def validate_resource_load_path(name, resource, operation)
        path = resource['load']['path']
        unless resource['shape'] == resolve_param_path(operation['output'], path)
          @errors << LOAD_PATH_BAD % [name, resource['shape']]
        end
      end

      def validate_static_param_types(prefix, shape_name, param)
        if scalar_param?(param)
          shape = @api['shapes'][shape_name]
          unless shape['type'] == param['sourceType']
            @errors << PARAM_TYPE_BAD % [prefix, param['target'], param['sourceType'], shape['type']]
          end
        end
      end

      def scalar_param?(param)
        !['identifier', 'dataMember', 'resource'].include?(param['sourceType'])
      end

      def resolve_param_path(start, path)
        if path == '$'
          start['shape']
        else
          ref = path.scan(/\w+|\[.*?\]/).inject(start) do |ref, part|
            shape = @api['shapes'][ref['shape']]
            if part[0] == '['
              return nil unless shape['type'] == 'list'
              shape['member']
            else
              return nil unless shape['type'] == 'structure'
              shape['members'][part]
            end
          end
          ref && ref['shape']
        end
      end

      def require_shape(resource, error_msg = nil, &block)
        shape = @api['shapes'][resource['shape']]
        if shape
          yield(shape)
        else
          @errors << error_msg if error_msg
        end
      end

      def require_operation(request, &block)
        if operation = @api['operations'][request['operation']]
          yield(operation)
        end
      end

      def each_service_action(&block)
        service = @definition['service'] || {}
        actions = service['actions'] || {}
        actions.each(&block)
      end

      def each_service_has_many(&block)
        service = @definition['service'] || {}
        has_many = service['hasMany'] || {}
        has_many.each(&block)
      end

      def each_resource(&block)
        @definition['resources'].each(&block)
      end

      def shape_for(resource, &block)
        if shape_name = resource['shape']
          shape = @api['shapes'][shape_name]
          raise 
          yield(shape) if block_given?
          shape
        end
      end

    end
  end
end
