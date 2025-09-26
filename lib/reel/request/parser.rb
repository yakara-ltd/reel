module Reel
  class Request
    class Parser
      include HTTPVersionsMixin
      attr_reader :socket, :connection

      def initialize(connection)
        @parser      = HTTP::Parser.new(self)
        @connection  = connection
        @socket      = connection.socket
        @buffer_size = connection.buffer_size
        @currently_reading = @currently_responding = nil
        @pending_reads     = []
        @pending_responses = []

        reset
      end

      def add(data)
        @parser << data
      end
      alias_method :<<, :add

      def http_method
        @parser.http_method
      end

      def http_version
        # TODO: add extra HTTP_VERSION handler when HTTP/1.2 released
        @parser.http_version[1] == 1 ? HTTP_VERSION_1_1 : HTTP_VERSION_1_0
      end

      def url
        @parser.request_url
      end

      def current_request
        until @currently_responding || @currently_reading
          readpartial
        end
        @currently_responding || @currently_reading
      end

      def readpartial(size = @buffer_size)
        bytes = @socket.readpartial(size)
        @parser << bytes
      end

      #
      # HTTP::Parser callbacks
      #
      def on_headers_complete(headers)
        validate_headers!(headers)
        info = Info.new(http_method, url, http_version, headers)
        req  = Request.new(info, connection)

        if @currently_reading
          @pending_reads << req
        else
          @currently_reading = req
        end
      end

      # Send body directly to Reel::Response to be buffered.
      def on_body(chunk)
        @currently_reading.fill_buffer(chunk)
      end

      # Mark current request as complete, set this as ready to respond.
      def on_message_complete
        @currently_reading.finish_reading! if @currently_reading.is_a?(Request)

        if @currently_responding
          @pending_responses << @currently_reading
        else
          @currently_responding = @currently_reading
        end

        @currently_reading = @pending_reads.shift
      end

      def reset
        popped = @currently_responding

        if req = @pending_responses.shift
          @currently_responding = req
        elsif @currently_responding
          @currently_responding = nil
        end

        popped
      end

      private

      def validate_headers!(headers)
        # Prevent HTTP request smuggling via duplicate Content-Length headers
        content_length_count = 0
        transfer_encoding_value = nil

        transfer_encoding_values = []

        headers.each do |name, value|
          case name.downcase
          when 'content-length'
            content_length_count += 1
            if content_length_count > 1
              raise Reel::RequestError, "Multiple Content-Length headers"
            end
            # Validate Content-Length value is a valid non-negative integer
            unless value =~ /\A\d+\z/
              raise Reel::RequestError, "Invalid Content-Length header value"
            end
          when 'transfer-encoding'
            transfer_encoding_values << value
          end
        end

        # Check for multiple Transfer-Encoding headers
        if transfer_encoding_values.length > 1
          # Multiple TE headers - chunked should be the last one
          last_encoding = transfer_encoding_values.last.strip.downcase
          unless last_encoding == 'chunked'
            raise Reel::RequestError, "When multiple Transfer-Encoding headers present, chunked must be the final encoding"
          end
        end

        # Process the combined transfer encoding value
        transfer_encoding_value = transfer_encoding_values.first

        # Validate Transfer-Encoding header values
        if transfer_encoding_value
          # Split by comma and validate each encoding
          encodings = transfer_encoding_value.split(',').map(&:strip)
          encodings.each do |encoding|
            # Only allow standard HTTP/1.1 transfer encodings
            unless encoding =~ /\A(chunked|compress|deflate|gzip|identity)\z/i
              raise Reel::RequestError, "Invalid Transfer-Encoding: #{encoding}"
            end
          end

          # Ensure chunked is the last encoding if present
          if encodings.length > 1 && encodings.last.downcase != 'chunked'
            raise Reel::RequestError, "Transfer-Encoding chunked must be the final encoding"
          end
        end

        # Prevent conflicting Content-Length and Transfer-Encoding: chunked headers
        if content_length_count > 0 && transfer_encoding_value
          encodings = transfer_encoding_value.split(',').map(&:strip).map(&:downcase)
          if encodings.include?('chunked')
            raise Reel::RequestError, "Cannot have both Content-Length and Transfer-Encoding: chunked"
          end
        end
      end
    end
  end
end
