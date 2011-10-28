require 'eventmachine'

module Fenris
  class Connection < EventMachine::Connection
    def self.mkbinding(action, binding)
      if binding =~ /^:?(\d+)$/
        [ action, "0.0.0.0", $1.to_i ]
      elsif binding =~ /^(.+):(\d+)/
        [ action, $1, $2.to_i ]
      elsif binding == "--"
        [ :attach, $stdin ]
      else
        [ action, binding ]
      end
    end

    def initialize(client = nil, options = {})
      @client = client
      ## TODO -- peer_to_be vs @peer is a poor name choice - refactor
      ## sometimes I call the proxying connection on the local box 'peer', sometimes I call the other fenris process 'peer' - confusing
      @binding      = options[:binding]
      @peer_to_be   = options[:peer]
      @peer_name    = options[:peer_name]
      @peer_binding = options[:peer_binding]
      @peer = []
    end

    def log msg
      @client.log msg if @client
    end

    def push(data)
      # this is the black magic to switch @peer between a connection and an array
      send_data data
    end

    def ssl_verify_peer(pem)
      @verify ||= @client.validate_peer pem, @peer_to_be, @peer_name
    end

    def unbind
      log "Connection closed"
      @unbound = true
      ## TODO clean up buffer vs peer vs peer_to_be
      (@peer_to_be || @peer).close_connection_after_writing rescue nil
      close_connection
      EventMachine::stop if @binding[0] == :attach
    end

    def ssl_handshake_completed
      @post_ssl.call
    end

    def proxy(peer, leader = true)
      peer.close if @unbound
      @peer.each { |d| peer.push d}
      @peer = peer
      @peer_to_be = nil
      if leader
        @peer.proxy(self, false)
        EventMachine::enable_proxy(self, @peer)
      end
    end

    def proxy_target_unbound
      unbind
    end

    def receive_data data
      @peer.push data
    end
  end

  class ProviderServer < Connection
    def self.begin(client, provider_binding, local_binding)
      client.log "Serving port #{local_binding} on #{provider_binding}"
      server_em = mkbinding(:start_server, provider_binding)
      local_em = mkbinding(:connect, local_binding)
      EventMachine::__send__ *server_em, self, client, :peer_binding => local_em, :binding => server_em
    end

    def post_init
      log "New connection - begin ssl handshake"
      start_tls :private_key_file => @client.my_key_path, :cert_chain_file => @client.my_cert_path, :verify_peer => true
    end

    def ssl_handshake_completed
      log "SSL complete - open local connection"
      EventMachine::__send__ *@peer_binding, ProviderLocal, @client, :peer => self, :binding => @peer_binding
    end
  end

  class ProviderLocal < Connection
    def post_init
      log "start proxying"
      @peer_to_be.proxy self
    end
  end

  class ConsumerLocal < Connection
    def self.begin(client, provider_binding, provider_name, consumer_binding)
      local_em = mkbinding(:start_server, consumer_binding)
      provider_em = mkbinding(:connect, provider_binding)
      client.log consumer_binding.inspect
      EventMachine::__send__ *local_em, self, client, :peer_name => provider_name, :peer_binding => provider_em, :binding => local_em
    end

    def post_init
      EventMachine::__send__ *@peer_binding, ConsumerProvider, @client, :peer_name => @peer_name, :peer => self, :binding => @peer_binding
    end
  end

  class ConsumerProvider < Connection
    def post_init
      log "Connection to the server made, starting ssl"
      start_tls :private_key_file => @client.my_key_path, :cert_chain_file => @client.cert_path(@peer_name), :verify_peer => true
    end

    def ssl_handshake_completed
      log "SSL complete - start proxying"
      @peer_to_be.proxy self
    end
  end
end
