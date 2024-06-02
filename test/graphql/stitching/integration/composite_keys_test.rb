# frozen_string_literal: true

require "test_helper"
require_relative "../../../schemas/composite_keys"

describe 'GraphQL::Stitching, composite keys' do
  def setup
    @supergraph = compose_definitions({
      "storefronts" => Schemas::CompositeKeys::Storefronts,
      "products" => Schemas::CompositeKeys::Products,
    })
  end

  def test_queries_using_composite_keys
    result = plan_and_execute(@supergraph, "{ result: storefrontsProductById(id: \"1\") { location name } }")

    assert_equal "Toronto", result.dig("data", "result", "location")
    assert_equal "iPhone", result.dig("data", "result", "name")
  end
end
