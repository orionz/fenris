require 'eventmachine'

module Chairman

  module Uber
    def initialize(client, ssl)
      @client, @ssl = client, ssl
    end
  end

  module ProxyConnection
    def initialize(client, ssl)
      @client, @ssl = client, ssl
    end

    def post_init
      if (@ssl)
        ## TODO 2
        start_tls :private_key_file => '/tmp/client.key', :cert_chain_file => '/tmp/client.crt', :verify_peer => true
      else
        @client.enable_proxy self
      end
    end

    def ssl_verify_peer(cert)
      ## TODO 1
      authority_key = OpenSSL::PKey::RSA.new File.read("/tmp/authority.pub")
      @verified ||= OpenSSL::X509::Certificate.new(cert).verify(authority_key)
    end

    def ssl_handshake_completed
      @client.enable_proxy self
    end

    def proxy_target_unbound
      close_connection
    end

    def unbind
      @client.close_connection_after_writing
    end
  end

  module ProviderSocket
    def initialize(host, port, ssl)
      @host, @port = host, port
      @ssl = ssl
      @q = []
    end

    def post_init
      if (@ssl)
        start_tls :private_key_file => '/tmp/server.key', :cert_chain_file => '/tmp/server.crt', :verify_peer => true
      else
        EventMachine::connect @host, @port, Chairman::ProxyConnection, self, true
      end
    end

    def ssl_verify_peer(cert)
      authority_key = OpenSSL::PKey::RSA.new File.read("/tmp/authority.pub")
      @verified ||= OpenSSL::X509::Certificate.new(cert).verify(authority_key)
    end

    def ssl_handshake_completed
      EventMachine::connect @host, @port, Chairman::ProxyConnection, self, false unless @unbound
    end

    def enable_proxy(dest)
      @q.each { |d| dest.send_data d }
      @q = []
      @target = dest
      EventMachine::enable_proxy dest, self unless @unbound
    end

    def receive_data data
      if @target
        @target.send_data data
      else
        @q << data
      end
    end

    def proxy_target_unbound
      close_connection
    end

    def unbind
      @unbound = true
      @client.close_connection_after_writing if @client
    end
  end

  module Base
    extend self

    def serve(client, from, to)
      EventMachine::run do
        client.update("0.0.0.0", from)
        puts "Serving port #{to} on #{from}"
        EventMachine::start_server "0.0.0.0", from, Chairman::ProviderSocket, "127.0.0.1", to, true
      end
    end

    def connect(client, dir)
      Dir.chdir(dir)

      at_exit do
        client.cleanup
      end

      EventMachine::run do
        client.providers.each do |provider|
          puts "Making socket '#{provider["binding"]}'."
          puts provider.inspect
          if provider["ip"]
            EventMachine::start_unix_domain_server provider["binding"], Chairman::ProviderSocket, provider["ip"], provider["port"].to_i, false
          end
        end
      end
    end
  end
end


