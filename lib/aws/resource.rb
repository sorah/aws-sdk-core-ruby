module Aws
  class Resource

    autoload :Builder, "#{SRC}/resource/builder"
    autoload :BuilderSources, "#{SRC}/resource/builder_sources"
    autoload :Definition, "#{SRC}/resource/definition"
    autoload :DefinitionValidator, "#{SRC}/resource/definition_validator"
    autoload :Errors, "#{SRC}/resource/errors"
    autoload :Options, "#{SRC}/resource/options"
    autoload :Request, "#{SRC}/resource/request"
    autoload :RequestParams, "#{SRC}/resource/request_params"

    autoload :DataOperation, "#{SRC}/resource/data_operation"
    autoload :EnumerateDataOperation, "#{SRC}/resource/enumerate_data_operation"
    autoload :EnumerateResourceOperation, "#{SRC}/resource/enumerate_resource_operation"
    autoload :Operation, "#{SRC}/resource/operation"
    autoload :ResourceOperation, "#{SRC}/resource/resource_operation"
    autoload :ReferenceOperation, "#{SRC}/resource/reference_operation"

    # @option options [Seahorse::Client::Base] :client
    def initialize(options = {})
      @identifiers = extract_identifiers(options)
      @client = extract_client(options)
      @data = options[:data]
    end

    # @return [Seahorse::Client::Base]
    attr_accessor :client

    # @return [Hash<Symbol,String>]
    attr_accessor :identifiers

    # @return [Struct]
    attr_accessor :data

    # @return [Struct]
    def data
      load unless @data
      @data
    end

    # @return [Boolean] Returns `true` if {#data} has been loaded.
    def data_loaded?
      !@data.nil?
    end

    # Loads data for this resource.
    # @note Calling this method will send a request to AWS.
    # @return [self]
    def load
      if load_operation = self.class.load_operation
        @data = load_operation.invoke(resource:self)
        self
      else
        raise NotImplementedError, "load not defined for #{self.class.name}"
      end
    end
    alias reload load

    # @api private
    def inspect
      identifiers = self.identifiers.map do |name, value|
        "#{name}=#{value.inspect}"
      end.join(', ')
      "#<#{[self.class.name, identifiers].join(' ').strip}>"
    end

    private

    def cache(name, &block)
      if instance_variable_defined?("@#{name}")
        instance_variable_get("@#{name}")
      else
        instance_variable_set("@#{name}", yield)
      end
    end

    def extract_client(options)
      options[:client] || self.class.client_class.new
    end

    def extract_identifiers(options)
      self.class.identifiers.each.with_object({}) do |name, identifiers|
        if value = options[name]
          identifiers[name] = value
        else
          raise ArgumentError, "missing required option #{name.inspect}"
        end
      end
    end

    class << self

      # @return [String, nil] The resource name.
      attr_accessor :resource_name

      # @return [Class<Seahorse::Client::Base>, nil] When constructing
      #   a resource, the client will default to an instance of the
      #   this class.
      attr_accessor :client_class

      # @return [DataOperation, nil]
      attr_accessor :load_operation

      # @param [Class<Seahorse::Client::Base>] client_class
      # @param [Array<Symbol>] identifiers
      # @return [Class<Resource>] Returns a new resource subclass.
      def define(client_class, identifiers = [])
        klass = Class.new(self)
        klass.client_class = client_class
        identifiers.each do |identifier|
          klass.add_identifier(identifier)
        end
        klass
      end

      # @return [Array<Symbol>]
      # @see add_identifier
      # @see #identifiers
      def identifiers
        @identifiers.dup
      end

      # @param [Symbol] name
      # @return [void]
      def add_identifier(name)
        name = name.to_sym
        define_method(name) { @identifiers[name] }
        @identifiers << name
      end

      # @param [Symbol] name
      # @return [Operation] Returns the named operation.
      # @raise [Errors::UnknownOperationError]
      def operation(name)
        @operations[name.to_sym] or
          raise Errors::UnknownOperationError.new(name)
      end

      # @param [Symbol] method_name
      # @param [Operation] operation
      # @return [void]
      def add_operation(method_name, operation)
        operation.is_a?(ReferenceOperation) ?
          define_resource_getter(method_name, operation) :
          define_operation_method(method_name, operation)
        @operations[method_name.to_sym] = operation
      end

      # @return [Enumerable<Symbol,Operation>]
      def operations(&block)
        @operations.each(&block)
      end

      # @return [Array<Symbol>]
      def operation_names
        @operations.keys
      end

      # @api private
      def inherited(subclass)
        subclass.send(:instance_variable_set, "@identifiers", [])
        subclass.send(:instance_variable_set, "@operations", {})
      end

      private

      # @param [Symbol] method_name
      # @param [ReferenceOperation] operation
      def define_resource_getter(method_name, operation)
        if operation.builder.requires_argument?
          define_method(method_name) do |identifier|
            operation.invoke(resource:self, argument:identifier)
          end
        else
          define_method(method_name) do
            cache(method_name) { operation.invoke(resource:self) }
          end
        end
      end

      def define_operation_method(method_name, operation)
        define_method(method_name) do |params={}|
          operation.invoke(resource:self, params:params)
        end
      end

    end
  end
end
