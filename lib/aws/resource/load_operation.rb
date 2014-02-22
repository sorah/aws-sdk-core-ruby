require 'jamespath'

module Aws
  class Resource
    class LoadOperation

      include Options

      # @option options [required, Request] :request
      # @option options [required, String<JAMESPath>] :load_path
      def initialize(options = {})
        @request = option(:request, options)
        @load_path = option(:load_path, options)
      end

      # @return [Request]
      attr_reader :request

      # @return [String<JAMESPath>]
      attr_reader :load_path

      # @option options [required, Resource] :resource
      # @option options [Hash] :params ({})
      # @return [Resource] Returns the given `resource`.
      def invoke(options)
        resource = option(:resource, options)
        resource.data = extract(@request.invoke(options))
        resource
      end

      private

      def extract(resp)
        @load_path == '$' ? resp.data : Jamespath.search(@load_path, resp.data)
      end

    end
  end
end
