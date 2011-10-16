require 'eventmachine'

module Chairman
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
      @broker = opts[:broker]
      start_tls :private_key_file => opts[:key_file], :cert_chain_file => opts[:cert_file], :verify_peer => true
    end

    def post_init
    end

    def ssl_verify_peer(pem)
      @verify ||= OpenSSL::X509::Certificate.new(pem).verify @broker.public_key
    end

    def unbind
      @peer.close_connection_after_writing rescue nil
      close_connection
    end

    def ssl_handshake_completed
      @post_ssl.call
    end

    def proxy(peer)
      @peer.each { |d| peer.push d}
      @peer = peer
    end

    def receive_data data
      @peer.push data
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
        puts "DEBUG: #{mkbinding("0.0.0.0:#{from}")}"
        EventMachine::start_server *mkbinding("0.0.0.0:#{from}"), Chairman::Connection do |consumer|
          client.log "New connection - begin ssl handshake"
          consumer.begin_ssl :key_file =>  client.key_path , :cert_file => client.cert_path, :broker => client.broker do
            client.log "SSL complete - open local connection"
            EventMachine::connect *mkbinding("127.0.0.1:#{to}"), Chairman::Connection do |producer|
              client.log "start proxying"
              producer.proxy consumer
              consumer.proxy producer
            end
          end
        end
      end
    end

    def mkbinding(binding)
      if binding =~ /^:?(\d+)$/
        [ "0.0.0.0", $1.to_i ]
      elsif binding =~ /^(.+):(\d+)/
        [ $1, $2.to_i ]
      else
        [ binding ]
      end
    end

    def consumer_connect(client, consumer, provider)
      EventMachine::start_server *mkbinding(consumer), Chairman::Connection do |consumer|
#      EventMachine::attach $stdin, Chairman::Connection do |consumer|
        client.log "New connection: opening connection to the server"
        EventMachine::connect *mkbinding(provider), Chairman::Connection do |provider|
          client.log "Connection to the server made, starting ssl"
          provider.begin_ssl :key_file =>  client.key_path , :cert_file => client.cert_path, :broker => client.broker do
            client.log "SSL complete - start proxying"
            provider.proxy consumer
            consumer.proxy provider
          end
        end
      end
    end

    def connect(client, provider = nil, binding = nil)
      at_exit { client.cleanup }

      client.save_keys

      abort "No providers" if client.providers.empty?

      providers = client.providers.reject { |p| provider && p["name"] != provider }

      abort "No provider named #{provider}" if providers.empty?
      abort "Can only pass a binding for a single provider" if binding && providers.length != 1

      EventMachine::run do
        providers.each do |p|
          consumer_connect(client, (binding || p["binding"]), "#{p["ip"]}:#{p["port"]}")
        end
      end
    end
  end
end


