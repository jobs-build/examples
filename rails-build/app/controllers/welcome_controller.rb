class WelcomeController < ApplicationController
  # Root page — proves the whole stack works at runtime: Rails boots, ActiveRecord
  # talks to SQLite (User.count), and the zig-compiled bcrypt extension loads.
  def index
    render plain: "rails-build OK — Rails #{Rails.version}, users=#{User.count}, bcrypt-cost=#{BCrypt::Engine.cost}\n"
  end
end
