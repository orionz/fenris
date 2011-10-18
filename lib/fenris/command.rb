module Fenris
  module Command
    def self.run(command, arg=nil, name=nil)
      begin
        client = Fenris::Client.new(ENV['FENRIS_URL']);
        help = [ "Usage: fenris help\n",
                 "       fenris info\n",
                 "       fenris bind PROVIDER BINDING\n",
                 "       fenris add CONSUMER\n",
                 "       fenris remove CONSUMER\n",
                 "       fenris serve BINDING\n",
                 "       fenris connect [ USER [ BINDING ] ]" ]
        case command
          when "cert"
            puts client.cert.to_text
          when "bind"
            client.bind(arg,name)
          when "add"
            client.add(arg)
          when "remove"
            client.remove(arg)
          when "info"
            puts "INFO:"
            puts "     #{client.user["name"]} #{client.route}"
            unless client.consumers.empty?
              puts "CLIENTS:"
              client.consumers.each { |c| puts "    #{c["name"]} (#{c["binding"]})" }
            end
            unless client.providers.empty?
              puts "SERVICES:"
              client.providers.each { |c| puts "    #{c["binding"] || "unbound"} #{c["name"]} (#{c["provider"]}) #{c["ip"]} #{c["port"]}" }
            end
          when "serve"
            from = 10001
            to = arg
            Fenris::Base.serve(client, from, to)
          when "connect"
            Fenris::Base.connect(client, arg, name)
          else
            puts command.inspect
            puts help
        end
        exit
      end
    rescue SystemExit
    rescue RestClient::ResourceNotFound
      puts "Resource Not Found"
      exit
    end
  end
end
