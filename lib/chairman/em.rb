require 'eventmachine'

module Chairman
  module Connection
    def debug(msg)
      @client.debug(msg)
    end

    def log(msg)
      @client.log(msg)
    end

    def initialize(client,options)
      @client = client
      @ssl  = !!options[:ssl]
      @peer = options[:peer]
      @host = options[:host]
      @port = options[:port]
      @q    = []
    end

    def post_init
        log "new connection"
        if @ssl
          debug 'starting TLS'
          start_tls :private_key_file => @client.key_path, :cert_chain_file => @client.cert_path, :verify_peer => true
        elsif @peer
          debug 'proxying to peer'
          @peer.enable_proxy self
        else
          log "connecting to ssl://#{@host}:#{@port}"
          EventMachine::connect @host, @port, Chairman::Connection, @client, :peer => self, :ssl => true
        end
    end

    def get_cert(pem)
      cert = OpenSSL::X509::Certificate.new(pem)
      log "received remote cert  #{@client.digest cert} #{cert.subject}"
      cert 
    end
    def ssl_verify_peer(pem)
      @cert   ||= get_cert(pem)
      @verify ||= @cert.verify @client.broker.public_key
    end

    def proxy_target_unbound
      debug "proxy target is unbound"
      close_connection
    end

    def unbind
      @unbound = true
      if @peer
        log "connection closed remotely"
        @peer.close_connection_after_writing
      else
        log "connection closed locally"
      end
    end

    def ssl_handshake_completed
      if (@peer)
        debug "enable proxy"
        @peer.enable_proxy self
      elsif not @unbound
        log "connecting to tcp://#{@host}:#{@port}"
        EventMachine::connect @host, @port, Chairman::Connection, @client, :peer => self, :ssl => false
      else
        debug "handshake complete but socket already unbound"
      end
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
  end

  module Base
    extend self

    def serve(client, from, to)
      at_exit do
        client.cleanup
      end

      EventMachine::run do
        client.save_keys
        client.update "0.0.0.0", from
        client.log "Serving port #{to} on #{from}"
        EventMachine::start_server "0.0.0.0", from, Chairman::Connection, client, :host => "127.0.0.1", :port => to, :ssl => true
      end
    end

    def connect(client)
      at_exit do
        client.cleanup
      end

      EventMachine::run do
        client.save_keys
        client.providers.each do |provider|
          client.log "Making socket '#{provider["binding"]}'."
          if provider["ip"]
            EventMachine::start_unix_domain_server provider["binding"], Chairman::Connection, client, :host => provider["ip"], :port => provider["port"].to_i, :ssl => false
          end
        end
      end
    end
  end
end


