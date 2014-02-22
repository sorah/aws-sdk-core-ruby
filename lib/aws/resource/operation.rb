module Aws
  class Resource
    class Operation

      include Options

      # @option options [required, Request] :request
      def initialize(options = {})
        @request = option(:request, options)
      end

      # @return [Request]
      attr_reader :request

      # @option options [required, Resource] :resource
      # @option options [Hash] :params ({})
      # @return [Seahorse::Client::Response] Returns a low-level client
      #   response.
      def invoke(options)
        @request.invoke(options)
      end

    end
  end
end
