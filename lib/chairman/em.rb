require 'eventmachine'

module Chairman
  module ProxyConnection
    def initialize(client)
      @client = client
    end

    def post_init
      @client.enable_proxy self
    end

    def proxy_target_unbound
      close_connection
    end

    def unbind
      @client.close_connection_after_writing
    end
  end
end

module Chairman
  module ClientSocket
    def initialize(host, port)
      @host, @port = host, port
    end

    def post_init
      EventMachine::connect @host, @port, Chairman::ProxyConnection, self
    end

    def receive_data data
    end
  end
end

module Chairman
  module ServiceSocket
    def initialize(host, port)
      @host, @port = host, port
      @q = []
    end

    def enable_proxy(dest)
      @q.each { |d| dest.send_data d }
      @q = []
      @target = dest
      EventMachine::enable_proxy dest, self
    end

    def post_init
      EventMachine::connect @host, @port, Chairman::ProxyConnection, self
    end

    def receive_data data
      if @target
        @target.send_data data
      else
        @q << data
      end
    end
  end
end

module Chairman
  module Base
    extend self

    def url
      ENV['CHAIRMAN_URL'] || (raise "define CHAIRMAN_URL")
    end

    def serve(client, from, to)
      EventMachine::run do
        client.update("0.0.0.0", from)
        puts "Serving port #{to} on #{from}"
        EventMachine::start_server "0.0.0.0", from, Chairman::ServiceSocket, "127.0.0.1", to
      end
    end

    def connect(client, dir)
      Dir.chdir(dir)

      at_exit do
        client.services.each do |service|
          puts "Deleting socket '#{service.name}'."
          File.delete service.name if File.exists? service.name
        end
      end

      EventMachine::run do
        client.services.each do |service|
          puts "Making socket '#{service["name"]}'."
          EventMachine::start_unix_domain_server service["name"], Chairman::ClientSocket, service["server_ip"], service["server_port"].to_i
        end
      end
    end

  end
end


