module Aws
  class Resource
    class CreateOperation

      include Options

      # @option options [required, Request] :request
      # @option options [required, Builder] :builder
      def initialize(options = {})
        @request = option(:request, options)
        @builder = option(:builder, options)
      end

      # @return [Request]
      attr_reader :request

      # @return [Builder]
      attr_reader :builder

      # @option options [required, Resource] :resource
      # @option options [Hash] :params ({})
      # @return [Resource, Array<Resource>]
      def invoke(options)
        response = @request.invoke(options)
        @builder.build(options.merge(response:response))
      end

    end
  end
end
