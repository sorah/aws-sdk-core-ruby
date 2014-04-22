module Aws
  class Resource
    class EnumerateResourceOperation

      include Options

      # @option options [required, Request] :request
      # @option options [required, Builder] :builder
      def initialize(options = {})
        @request = option(:request, options)
        @builder = option(:builder, options)
        raise ArgumentError, 'expected a plural builder' unless @builder.plural?
      end

      # @return [Request]
      attr_reader :request

      # @return [Builder]
      attr_reader :builder

      # @option options [required, Resource] :resource
      # @option options [Hash] :params ({})
      # @return [Enumerator]
      def invoke(options)
        enum_for(:each_resource, options)
      end

      private

      def each_resource(options, &block)
        @request.invoke(options).each do |response|
          @builder.build(options.merge(response:response), &block)
        end
      end

    end
  end
end
