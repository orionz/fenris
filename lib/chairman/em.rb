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
        elsif @host && @port
          log "connecting to ssl://#{@host}:#{@port}"
          EventMachine::connect @host, @port, Chairman::Connection, @client, :peer => self, :ssl => true
        else
          log "no remote service to connect to - closing connection #{@host} #{@port}"
          close_connection_after_writing
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
      at_exit { client.cleanup }

      EventMachine::run do
        client.save_keys
        client.update "0.0.0.0", from
        client.log "Serving port #{to} on #{from}"
        EventMachine::start_server "0.0.0.0", from, Chairman::Connection, client, :host => "127.0.0.1", :port => to, :ssl => true
      end
    end

    def tcp_server(host, port, client, provider)
      client.log "Listening on '#{host}:#{port}' for #{provider["name"]}."
      client.log "- #{provider.inspect}"
      EventMachine::start_server host, port, Chairman::Connection, client, :host => provider["ip"], :port => provider["port"].to_i
    end

    def unix_socket_server(path, client, provider)
      client.log "Listening on unix socket '#{path}' for #{provider["name"]}."
      EventMachine::start_unix_domain_server path, Chairman::Connection, client, :host => provider["ip"], :port => provider["port"].to_i
    end

    def stdin_server(client, provider)
      EventMachine::attach $stdin, Chairman::Connection, client, :host => provider["ip"], :port => provider["port"].to_i
    end

    def run(binding, client, provider)
      puts "run #{binding.inspect} #{client} #{provider["name"]}"
      ## This could be better
      if binding =~ /^:?(\d)+$/
        tcp_server "0.0.0.0", $1.to_i, client, provider
      elsif binding =~ /^(.+):(\d+)/
        tcp_server $1, $2.to_i, client, provider
      elsif binding == "--"
        stdin_server client, provider
      else
        unix_socket_server binding, client, provider
      end
    end

    def connect(client, provider = nil, binding = nil)
      at_exit { client.cleanup }

      EventMachine::run do
        client.save_keys

        abort "No providers" if client.providers.empty?

        providers = client.providers.reject { |p| provider && p["name"] != provider }

        abort "No provider named #{provider}" if providers.empty?
        abort "Can only pass a binding for a single provider" if binding && providers.length != 1

        providers.each { |p| run (binding || p["binding"]), client, p }
      end
    end
  end
end


