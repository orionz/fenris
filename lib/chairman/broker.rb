require 'sinatra'

module Chairman
  class Broker < Sinatra::Base
    get "/" do
      { :users => @user.users, :subscribers => @user.subscribers, :services => @user.services }
    end

    put "/" do
      @user.update_attributes! params
    end

    get "/user" do
      @user.users
    end

    get "/user/:name" do |user|
      @user.users.find_by_name(user)
    end

    post "/user" do
      User.create! :master => @user, :name => params[:name]
    end

    delete "/user/:name" do |name|
    end

    post "/user/:name/service" do
      Service.create! :client => User.find_by_name(params[:client]), :server => @user, :name => params[:name]
    end

    put "/user/:user/service/:service" do |user,service|
      @user.users.find_by_name(user).services.find_by_name(service).update_attributes! params
    end
  end
end

