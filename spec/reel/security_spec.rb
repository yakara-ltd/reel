require 'spec_helper'

RSpec.describe "HTTP Request Smuggling Security" do
  before(:all) do
    Celluloid.boot
  end

  after(:all) do
    begin
      Celluloid.shutdown
    rescue => e
      # Ignore shutdown errors
    end
  end

  def with_reel(handler)
    host = "127.0.0.1"
    port = 12345  # Use a different port than the main tests to avoid conflicts
    server = Reel::Server::HTTP.new(host, port, &handler)
    begin
      yield TCPSocket.new(host, port), server
    ensure
      server.terminate if server && server.alive?
    end
  end

  describe "Content-Length header validation" do
    it "rejects requests with duplicate Content-Length headers" do
      with_reel(proc { |connection| connection.respond :ok, "Hello World" }) do |client, server|
        # Create malicious request with duplicate Content-Length headers
        malicious_request = [
          "POST / HTTP/1.1",
          "Host: example.com",
          "Content-Length: 10",
          "Content-Length: 5",
          "",
          "test data"
        ].join("\r\n")

        client.write(malicious_request)
        client.close_write
        # Try to read response - should get connection closed due to error
        expect { client.read }.to raise_error(StandardError)
      end
    end

    it "rejects requests with invalid Content-Length values" do
      with_reel(proc { |connection| connection.respond :ok, "Hello World" }) do |client, server|
        malicious_request = [
          "POST / HTTP/1.1",
          "Host: example.com",
          "Content-Length: -5",
          "",
          "test"
        ].join("\r\n")

        client.write(malicious_request)
        client.close_write
        expect { client.read }.to raise_error(StandardError)
      end
    end

    it "rejects requests with non-numeric Content-Length values" do
      with_reel(proc { |connection| connection.respond :ok, "Hello World" }) do |client, server|
        malicious_request = [
          "POST / HTTP/1.1",
          "Host: example.com",
          "Content-Length: abc",
          "",
          "test"
        ].join("\r\n")

        client.write(malicious_request)
        client.close_write
        expect { client.read }.to raise_error(StandardError)
      end
    end
  end

  describe "Transfer-Encoding header validation" do
    it "rejects requests with invalid Transfer-Encoding values" do
      with_reel(proc { |connection| connection.respond :ok, "Hello World" }) do |client, server|
        malicious_request = [
          "POST / HTTP/1.1",
          "Host: example.com",
          "Transfer-Encoding: malicious-encoding",
          "",
          "test data"
        ].join("\r\n")

        client.write(malicious_request)
        client.close_write
        expect { client.read }.to raise_error(StandardError)
      end
    end

    it "rejects requests where chunked is not the final encoding" do
      with_reel(proc { |connection| connection.respond :ok, "Hello World" }) do |client, server|
        # Test with chunked not being the final encoding - this should be rejected
        malicious_request = [
          "POST / HTTP/1.1",
          "Host: example.com",
          "Transfer-Encoding: chunked",
          "Transfer-Encoding: gzip",
          "",
          "test data"
        ].join("\r\n")

        client.write(malicious_request)
        client.close_write
        expect { client.read }.to raise_error(StandardError)
      end
    end

    it "accepts valid Transfer-Encoding values" do
      with_reel(proc { |connection| connection.respond :ok, "Hello World" }) do |client, server|
        # Test with valid single transfer encoding
        valid_request = [
          "POST / HTTP/1.1",
          "Host: example.com",
          "Transfer-Encoding: identity",
          "Content-Length: 5",
          "",
          "hello"
        ].join("\r\n")

        client.write(valid_request)
        client.close_write
        sleep(0.1)  # Give server time to process
        response = client.read
        expect(response).to include("200 OK")
      end
    end
  end

  describe "Content-Length and Transfer-Encoding conflict" do
    it "rejects requests with both Content-Length and Transfer-Encoding: chunked" do
      with_reel(proc { |connection| connection.respond :ok, "Hello World" }) do |client, server|
        malicious_request = [
          "POST / HTTP/1.1",
          "Host: example.com",
          "Content-Length: 10",
          "Transfer-Encoding: chunked",
          "",
          "5\r\nhello\r\n0\r\n\r\n"
        ].join("\r\n")

        client.write(malicious_request)
        client.close_write
        expect { client.read }.to raise_error(StandardError)
      end
    end

    it "allows Content-Length without Transfer-Encoding" do
      with_reel(proc { |connection| connection.respond :ok, "Hello World" }) do |client, server|
        # Test just Content-Length without Transfer-Encoding (this should always work)
        valid_request = [
          "POST / HTTP/1.1",
          "Host: example.com",
          "Content-Length: 5",
          "",
          "hello"
        ].join("\r\n")

        client.write(valid_request)
        client.close_write
        sleep(0.1)  # Give server time to process
        response = client.read
        expect(response).to include("200 OK")
      end
    end
  end

  describe "HTTP request smuggling attack prevention" do
    it "prevents CL.TE smuggling attacks" do
      with_reel(proc { |connection| connection.respond :ok, "Hello World" }) do |client, server|
        # Classic CL.TE request smuggling attempt
        smuggling_request = [
          "POST / HTTP/1.1",
          "Host: example.com",
          "Content-Length: 6",
          "Transfer-Encoding: chunked",
          "",
          "0\r\n\r\n"
        ].join("\r\n")

        client.write(smuggling_request)
        client.close_write
        expect { client.read }.to raise_error(StandardError)
      end
    end

    it "prevents TE.CL smuggling attacks" do
      with_reel(proc { |connection| connection.respond :ok, "Hello World" }) do |client, server|
        # TE.CL smuggling attempt with invalid transfer encoding
        smuggling_request = [
          "POST / HTTP/1.1",
          "Host: example.com",
          "Transfer-Encoding: xchunked",
          "Content-Length: 4",
          "",
          "test"
        ].join("\r\n")

        client.write(smuggling_request)
        client.close_write
        expect { client.read }.to raise_error(StandardError)
      end
    end
  end
end