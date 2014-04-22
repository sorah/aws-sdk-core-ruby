module Aws
  class Resource
    class EnumerateDataOperation

      include Options

      # @option options [required, Request] :request
      # @option options [required, String<JMESPath>] :path
      def initialize(options = {})
        @request = option(:request, options)
        @path = option(:path, options)
      end

      # @return [Request]
      attr_reader :request

      # @return [String<JMESPath>]
      attr_reader :path

      # @option options [required, Resource] :resource
      # @option options [Hash] :params ({})
      # @return [Enumerator]
      def invoke(options)
        enum_for(:each_value, options)
      end

      private

      def each_value(options, &block)
        @request.invoke(options).each do |response|
          Jamespath.search(@path, response.data).each(&block)
        end
      end

    end
  end
end
