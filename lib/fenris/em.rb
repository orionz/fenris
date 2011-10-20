require 'eventmachine'

module Fenris
  module Connection
    def initialize
      @peer = []
    end

    def push(data)
      # this is the black magic to switch @peer between a connection and an array
      send_data data
    end

    def begin_ssl(opts, &blk)
      @post_ssl = blk
      start_tls :private_key_file => opts[:key_file], :cert_chain_file => opts[:cert_file], :verify_peer => true
    end

    def post_init
    end

    def validate_peer(&blk)
      @validator = blk;
    end

    def ssl_verify_peer(pem)
      @verify ||= @validator.call(pem)
    end

    def unbind
      @unbound = true
      puts "DEBUG: unbind #{@signature}"
      EM::stop if @signature < 3 ## this is for attach($stdin)
      @peer.close_connection_after_writing rescue nil
      close_connection
    end

    def ssl_handshake_completed
      @post_ssl.call
    end

    def proxy(peer)
      peer.close if @unbound
      @peer.each { |d| peer.push d}
      @peer = peer
    end

    def receive_data data
      @peer.push data
    end
  end

  module Base
    extend self

    def listen(client, from, to)
      return listen_stdio(client, from, to) if to == "--"
      EventMachine::__send__ *mkbinding(:start_server, from), Fenris::Connection do |consumer|
        client.log "New connection - begin ssl handshake"
        consumer.validate_peer { |pem| client.validate_peer pem  }
        consumer.begin_ssl :key_file =>  client.key_path , :cert_file => client.cert_path do
          client.log "SSL complete - open local connection"
          EventMachine::__send__ *mkbinding(:connect, to), Fenris::Connection do |provider|
            client.log "start proxying"
            provider.proxy consumer; consumer.proxy provider
          end
        end
      end
    end

    def listen_stdio(client, from, to)
      EventMachine::__send__ *mkbinding(:connect, to), Fenris::Connection do |provider|
        EventMachine::__send__ *mkbinding(:start_server, from), Fenris::Connection do |consumer|
          client.log "stdio connection - begin ssl handshake"
          consumer.validate_peer { |pem| client.validate_peer pem  }
          consumer.begin_ssl :key_file =>  client.key_path , :cert_file => client.cert_path do
            client.log "SSL complete - start proxying"
            provider.proxy consumer; consumer.proxy provider
          end
        end
      end
    end

    def provide(client, listen_port, to)
      at_exit { client.cleanup }

      EventMachine::run do
        client.save_keys
        client.update "0.0.0.0", listen_port
        from = "0.0.0.0:#{listen_port}"
        client.log "Serving port #{to} on #{from}"
        listen(client, from, to)
      end
    end

    def mkbinding(action, binding)
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

    ## really want to unify all these :(
    def consumer_connect(client, consumer, provider_name, provider)
      EventMachine::__send__ *mkbinding(:start_server, consumer), Fenris::Connection do |consumer|
        client.log "New connection: opening connection to the server"
        EventMachine::__send__ *mkbinding(:connect, provider), Fenris::Connection do |provider|
          client.log "Connection to the server made, starting ssl"
          provider.validate_peer { |pem| client.validate_peer pem, consumer, provider_name }
          provider.begin_ssl :key_file =>  client.key_path , :cert_file => client.cert_path do
            client.log "SSL complete - start proxying"
            provider.proxy consumer; consumer.proxy provider
          end
        end
      end
    end

    def consume(client, overide_provider = nil, override_binding = nil)
      at_exit { client.cleanup }

      client.save_keys

      abort "No providers" if client.providers.empty?

      providers = client.providers.reject { |p| overide_provider && p["name"] != overide_provider }

      abort "No provider named #{overide_provider}" if providers.empty?
      abort "Can only pass a binding for a single provider" if override_binding && providers.length != 1

      EventMachine::run do
        providers.each do |p|
          binding = override_binding || p["binding"]
          consumer_connect(client, binding, p["name"], "#{p["ip"]}:#{p["port"]}")
        end
      end
    end
  end
end


