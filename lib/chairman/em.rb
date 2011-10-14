require 'eventmachine'

module Chairman
  module Connection
    def debug(msg)
      puts "DEBUG: #{msg}" if ENV['DEBUG']
    end

    def initialize(client,options)
      debug "options #{options.inspect}"
      @client = client
      @ssl  = !!options[:ssl]
      @peer = options[:peer]
      @host = options[:host]
      @port = options[:port]
      @q    = []
    end

    def post_init
        if @ssl
          if @peer
            debug 'starting client TLS'
            start_tls :private_key_file => '/tmp/client.key', :cert_chain_file => '/tmp/client.crt', :verify_peer => true
          else
            debug 'starting server TLS'
            start_tls :private_key_file => '/tmp/server.key', :cert_chain_file => '/tmp/server.crt', :verify_peer => true
          end
        elsif @peer
          debug 'proxying to peer'
          @peer.enable_proxy self
        else
          debug "connecting to #{@host}:#{@port} - ssl"
          EventMachine::connect @host, @port, Chairman::Connection, @client, :peer => self, :ssl => true
        end
    end

    def ssl_verify_peer(cert)
      debug "about to verified: #{@verified}"
      authority_key = OpenSSL::PKey::RSA.new File.read("/tmp/authority.pub")
      @verified ||= OpenSSL::X509::Certificate.new(cert).verify(authority_key)
      debug "verified: #{@verified}"
      @verified
    end

    def proxy_target_unbound
      debug "proxy target is unbound"
      close_connection
    end

    def unbind
      @unbound = true
      if @peer
        debug "connection closed remotely"
        @peer.close_connection_after_writing
      else
        debug "connection closed locally"
      end
    end

    def ssl_handshake_completed
      if (@peer)
        debug "enable proxy"
        @peer.enable_proxy self
      elsif not @unbound
        debug "connecting to #{@host}:#{@port} - no ssl"
        EventMachine::connect @host, @port, Chairman::Connection, @client, :peer => self, :ssl => false
      else
        debug "handshake complete but socket already unbound"
      end
    end

    def enable_proxy(dest)
      debug "asked to enable proxy"
      @q.each { |d| dest.send_data d }
      @q = []
      @target = dest
      EventMachine::enable_proxy dest, self unless @unbound
    end

    def receive_data data
      debug "data -- #{data}"
      if @target
        @target.send_data data
      else
        @q << data
      end
    end
  end

  module Base
    extend self

    def serve(client, from, to)
      at_exit do
        client.cleanup
      end

      EventMachine::run do
        client.update("0.0.0.0", from)
        puts "Serving port #{to} on #{from}"
        EventMachine::start_server "0.0.0.0", from, Chairman::Connection, client, :host => "127.0.0.1", :port => to, :ssl => true
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
            EventMachine::start_unix_domain_server provider["binding"], Chairman::Connection, client, :host => provider["ip"], :port => provider["port"].to_i, :ssl => false
          end
        end
      end
    end
  end
end


