require 'restclient'
require 'json'
require 'openssl'

module Chairman
  class Client
    def initialize(url)
      @url = url
    end

    def update(ip, port)
      RestClient.put("#{@url}", { :ip => ip, :port => port }, :content_type => :json, :accept => :json)
    end
  
    def user
      @user ||= JSON.parse RestClient.get("#{@url}", :content_type => :json, :accept => :json)
    end

    def consumers
      @consumers ||= JSON.parse RestClient.get("#{@url}consumers", :content_type => :json, :accept => :json);
    end

    def providers
      @providers ||= JSON.parse RestClient.get("#{@url}providers", :content_type => :json, :accept => :json);
    end

    def route
      "#{user["ip"]}:#{user["port"]}" if user["ip"]
    end

    def remove(name)
      RestClient.delete("#{@url}consumers/#{name}");
    end

    def add(name)
      RestClient.post("#{@url}consumers", { :name => name }, :content_type => :json, :accept => :json);
    end

    def bind(name, binding)
      RestClient.put("#{@url}providers/#{name}", { :binding => binding }, :content_type => :json, :accept => :json);
    end

    def generate_csr
      subject = OpenSSL::X509::Name.parse "/DC=org/DC=chairman/CN=#{user[:name]}"
      digest = OpenSSL::Digest::SHA1.new
      req = OpenSSL::X509::Request.new
      req.version = 0
      req.subject = subject
      req.public_key = key.public_key
      req.sign(key, digest)
      req
    end

    def cleanup
      providers.each do |provider|
        puts "Deleting socket '#{provider["name"]}'."
        File.delete provider["name"] if File.exists? provider["name"]
      end
    end

    def handle_file name, action, &blk
      case [ action, File.exists?(name) ]
        when [ :write, false ]
          File.umask "0077"
          File.open(name, "w") do |f|
            data = blk.call
            f.write data
          end
          [ name, data ]
        when [ :delete, true ]
          File.delete name
          [name, nil]
      end
    end

    def broker_cert(action = :write)
      handle_file ".broker.cert", action { OpenSSL::X509::Certificate.new(RestClient.get("#{@url}cert")) }
    end

    def cert(action = :write)
      handle_file '.chairman.cert', action { OpenSSL::X509::Certificate.new RestClient.post("#{@url}cert", :csr => generate_csr) }
    end

    def key(action = :write)
      handle_file ".chairman.key", action { OpenSSL::PKey::RSA.new(2048) }
    end
  end
end
