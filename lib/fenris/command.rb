module Fenris
  module Command
    def self.run(command, *args)
      arg, name = args
      begin
        url = ENV['FENRIS_URL'] || "https://#{ENV['FENRIS_KEY']}@#{ENV['FENRIS_HOST'] || 'broker.fenris.cc'}/"
        client = Fenris::Client.new(url)
        help = [ "Usage: fenris help\n",
                 "       fenris info\n",
                 "       fenris bind PROVIDER BINDING\n",
                 "       fenris useradd NAME\n",
                 "       fenris userdel NAME\n",
                 "       fenris users\n",
                 "       fenris rekey\n",
                 "       fenris add CONSUMER\n",
                 "       fenris remove CONSUMER\n",
                 "       fenris exec COMMAND\n",
                 "       fenris provide BINDING\n",
                 "       fenris consume [ USER [ BINDING ] ]" ]
        case command
          when "users"
            client.users.each do |u|
              puts u["name"]
            end
          when "userdel"
            client.userdel(arg)
          when "useradd"
            client.useradd(arg)
          when "rekey"
            puts client.rekey
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
              client.providers.each { |c| puts "    #{c["binding"] || "unbound"} #{c["name"]} (#{c["description"]}) #{c["location"]}" }
            end
          when "provide"
            external = "#{Socket.gethostname}:#{10001}"
            internal = arg
            Fenris::Base.provide(client, external, internal)
          when "consume"
            Fenris::Base.consume(client, arg, name)
          when "exec"
            Fenris::Base.exec(client, *args)
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
