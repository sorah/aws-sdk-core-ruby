require 'openssl'
require 'base64'

module Aws
  module Plugins

    # @seahorse.client.option [Boolean] :compute_checksums (true)
    #   When `true` a MD5 checksum will be computed for every request that
    #   sends a body.  When `false`, MD5 checksums will only be computed
    #   for operations that require them.  Checksum errors returned by Amazon
    #   S3 are automatically retried up to `:retry_limit` times.
    class S3Md5s < Seahorse::Client::Plugin

      # Amazon S3 requires these operations to have an MD5 checksum
      REQUIRED_OPERATIONS = [
        :delete_objects,
        :put_bucket_cors,
        :put_bucket_lifecycle,
        :put_bucket_policy,
        :put_bucket_tagging,
      ]

      # @api private
      class Handler < Seahorse::Client::Handler

        OneMB = 1024 * 1024

        def call(context)
          body = context.http_request.body
          if body.size > 0
            context.http_request.headers['Content-Md5'] ||= md5(body)
          end
          @handler.call(context)
        end

        def md5(body)
          md5 = OpenSSL::Digest::MD5.new
          while chunk = body.read(OneMB)
            md5.update(chunk)
          end
          body.rewind
          Base64.encode64(md5.digest).strip
        end

      end

      option(:compute_checksums, true)

      def add_handlers(handlers, config)
        options = {
          priority: 10, # set intentially low so the md5 is computed after
          step: :build, # the request is built but before it is signed
        }

        if !config.compute_checksums
          options[:operations] = REQUIRED_OPERATIONS
        end

        handlers.add(Handler, options)
      end

    end
  end
end
