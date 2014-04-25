module Aws
  class Resource
    module BuilderSources

      # Used by a {Builder} to extract resource identifiers from an AWS
      # response or from another resource object.
      #
      # This is the base class of each of the builder sources.  Each
      # source is responsible for extracting a single identifier.
      #
      # @see {Argument}
      # @see {Identifier}
      # @see {DataMember}
      # @see {RequestParameter}
      # @see {ResponsePath}
      #
      class Base

        include Options

        # @param [String] source
        # @param [Symbol] target
        def initialize(source, target)
          @source = source
          @target = target.to_sym
        end

        # @return [String]
        attr_reader :source

        # @return [Symbol]
        attr_reader :target

        # @return [Boolean]
        def plural?
          source.include?('[')
        end

        # @param [Hash] options
        # @return [String, Array<String>]
        def extract(options)
          raise NotImplementedError, 'must be defined in subclasses'
        end

      end

      class Argument < Base

        # @option [required, String] :argument
        def extract(options)
          option(:argument, options)
        end

      end

      # Extracts an identifier from a parent resource identifier.  Used
      # when building a {Resource} from the context of another resource.
      class Identifier < Base

        # @option [required, Resource] :resource
        def extract(options)
          resource(options).identifiers[source.to_sym]
        end

        private

        def resource(options)
          option(:resource, options)
        end

      end

      # Extracts an identifier from the data of a parent resource.  Used
      # when building a {Resource} from the context of another resource.
      class DataMember < Base

        # @option [required, Resource] :resource
        def extract(options)
          Jamespath.search(source, resource(options).data)
        end

        private

        def resource(options)
          option(:resource, options)
        end

      end

      # Extracts an identifier from the request parameters used to generate
      # a response.  Used when building a {Resource} object from the response
      # of an {Operation}.
      class RequestParameter < Base

        # @option [required, Seahorse::Client::Response] :response
        def extract(options)
          response(options).context.params[source.to_sym]
        end

        private

        def response(options)
          option(:response, options)
        end

      end

      # Extracts an identifier from the data of a response.  Used when
      # building a {Resource} object from the response of an {Operation}.
      class ResponsePath < Base

        # @option [required, Seahorse::Client::Response] :response
        def extract(options)
          Jamespath.search(source, response(options).data)
        end

        private

        def response(options)
          option(:response, options)
        end

      end
    end
  end
end
