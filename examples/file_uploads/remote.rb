# frozen_string_literal: true

require 'rackup'
require 'json'
require 'graphql'
require_relative './helpers'

class RemoteApp
  def call(env)
    params = apollo_upload_server_middleware_params(env)
    result = RemoteSchema.execute(
      query: params["query"],
      variables: params["variables"],
      operation_name: params["operationName"],
    )

    [200, {"content-type" => "application/json"}, [JSON.generate(result)]]
  end
end

Rackup::Handler.default.run(RemoteApp.new, :Port => 3001)
