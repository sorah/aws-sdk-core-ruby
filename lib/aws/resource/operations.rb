module Aws
  class Resource
    module Operations

      # Basic operations make an API request using the resource client,
      # returning the client response.
      class Basic

        include Options

        # @option options [required, Request] :request
        def initialize(options = {})
          @request = option(:request, options)
        end

        # @return [Request]
        attr_reader :request

        # @option options [required, Resource] :resource
        # @option options [Hash] :params ({})
        # @return [Seahorse::Client::Response]
        def invoke(options)
          @request.invoke(options)
        end

      end

      class Data < Basic

        # @option options [required, Request] :request
        # @option options [required, String<JMESPath>] :path
        def initialize(options = {})
          @path = option(:path, options)
          super
        end

        # @return [String<JMESPath>]
        attr_reader :path

        # @option options [required, Resource] :resource
        # @option options [Hash] :params ({})
        # @return [Object] Returns the value resolved to by #{path}.
        def invoke(options)
          extract(super)
        end

        private

        def extract(resp)
          @path == '$' ? resp.data : Jamespath.search(@path, resp.data)
        end

      end

      class EnumerateData < Data

        # @option options [required, Resource] :resource
        # @option options [Hash] :params ({})
        # @return [Enumerator]
        def invoke(options)
          enum_for(:each_value, options)
        end

        private

        def each_value(options, &block)
          @request.invoke(options).each do |response|
            extract(response).each(&block)
          end
        end

      end

      class Resource < Basic

        # @option options [required, Request] :request
        # @option options [required, Builder] :builder
        def initialize(options = {})
          @builder = option(:builder, options)
          super
        end

        # @return [Builder]
        attr_reader :builder

        # @option options [required, Resource] :resource
        # @option options [Hash] :params ({})
        # @return [Resource, Array<Resource>]
        def invoke(options)
          @builder.build(options.merge(response:super))
        end

      end

      class EnumerateResource < Resource

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

      class Reference

        include Options

        # @option options [required, Builder] :builder
        def initialize(options = {})
          @builder = option(:builder, options)
        end

        # @return [Builder]
        attr_reader :builder

        # @option options [required, Resource] :resource
        # @option options [required, String] :argument
        # @return [Resource]
        def invoke(options)
          @builder.build(options)
        end

      end

    end
  end
end
