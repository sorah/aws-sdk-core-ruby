module Aws
  class Resource
    module RequestParams

      # Base class for all request parameter types.
      # @see {RequestParams::Identifier}
      # @see {RequestParams::DataMember}
      # @see {RequestParams::String}
      # @see {RequestParams::Integer}
      class Base

        # @param [String] target
        def initialize(target)
          case target
          when /^(\w+)$/
            @format = :simple
            @key = $1.to_sym
          when /^(\w+)\.(\w+)$/
            @format = :nested
            @key1, @key2 = $1.to_sym, $2.to_sym
          when /^(\w+)\[\]$/
            @format = :list
            @key = $1.to_sym
          when /^(\w+)\[(\d+)\]\.(\w+)$/
            @format = :list_member
            @key1, @index, @key2 = $1.to_sym, $2.to_i, $3.to_sym
          when /^(\w+)\[(\d+)\]\.(\w+)\[\]$/
            @format = :nested_list
            @key1, @index, @key2 = $1.to_sym, $2.to_i, $3.to_sym
          else
            raise ArgumentError, "invalid target epxression #{target.inspect}"
          end
        end

        # @return [String] target
        attr_reader :target

        # @param [Hash] params
        # @param [Object] value
        # @return [Hash] Returns the modified params hash.
        def apply(params, value)
          send(@format, params, value)
          params
        end

        private

        # @example
        #   "param_name"
        # @example
        #   "bucket"
        def simple(params, value)
          params[@key] = value
        end

        # @example:
        #   "nested.param"
        # @example
        #   "create_bucket_configuration.location_constraint"
        def nested(params, value)
          params[@key1] ||= {}
          params[@key1][@key2] = value
        end

        # @example
        #   "param_names[]"
        # @example
        #   "instance_ids[]"
        def list(params, value)
          params[@key] ||= []
          params[@key] << value
        end

        # @example
        #   "params[0].name"
        # @example:
        #   "filters[0].name"
        def list_member(params, value)
          params[@key1] ||= []
          params[@key1][@index] ||= {}
          params[@key1][@index][@key2] = value
        end

        # @example
        #   "params[0].names[]"
        # @example:
        #   "filters[0].values[]"
        def nested_list(params, value)
          params[@key1] ||= []
          params[@key1][@index] ||= {}
          params[@key1][@index][@key2] ||= []
          params[@key1][@index][@key2] << value
        end

      end

      class Identifier < Base

        # @param [String] identifier_name
        # @param (see Base#initialize)
        def initialize(identifier_name, target)
          @identifier_name = identifier_name.to_sym
          super(target)
        end

        # @param [Symbol] identifier_name
        attr_reader :identifier_name

        # @param [Hash] params_hash
        # @option [requried, Resource] :resource
        def apply(params_hash, options)
          value = options[:resource].identifiers[identifier_name]
          super(params_hash, value)
        end

        # @api private
        def self.literal?
          false
        end

      end

      class DataMember < Base

        # @param [String] member_name
        # @param (see Base#initialize)
        def initialize(member_name, target)
          @member_name = member_name
          super(target)
        end

        # @return [String]
        attr_reader :member_name

        # @param [Hash] params_hash
        # @option [requried, Resource] :resource
        def apply(params_hash, options)
          value = options[:resource].data[member_name.to_sym]
          super(params_hash, value)
        end

        # @api private
        def self.literal?
          false
        end

      end

      class String < Base

        # @param [String] value
        # @param (see Base#initialize)
        def initialize(value, target)
          @value = value
          super(target)
        end

        # @return [String]
        attr_reader :value

        # @param [Hash] params_hash
        def apply(params_hash, options = {})
          super(params_hash, value)
        end

        # @api private
        def self.literal?
          true
        end

      end

      class Integer < Base

        # @param [String] value
        # @param (see Base#initialize)
        def initialize(value, target)
          @value = value.to_i
          super(target)
        end

        # @return [Integer]
        attr_reader :value

        # @param [Hash] params_hash
        def apply(params_hash, options = {})
          super(params_hash, value)
        end

        # @api private
        def self.literal?
          true
        end

      end
    end
  end
end
