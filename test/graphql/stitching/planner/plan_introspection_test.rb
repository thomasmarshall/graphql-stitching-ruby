# frozen_string_literal: true

require "test_helper"
require_relative "../../../schemas/example"
require_relative "../../../schemas/introspection"

describe "GraphQL::Stitching::Planner, introspection" do
  def test_plans_full_introspection_query
    a = "type Apple { name: String } type Query { a:Apple }"
    b = "type Banana { name: String } type Query { b:Banana }"
    supergraph = compose_definitions({ "a" => a, "b" => b })

    plan = GraphQL::Stitching::Planner.new(
      supergraph: supergraph,
      request: GraphQL::Stitching::Request.new(INTROSPECTION_QUERY, operation_name: "IntrospectionQuery"),
    ).perform

    assert_equal 1, plan.ops.length
    assert_equal "__super", plan.ops.first.location
  end

  def test_stitches_introspection_with_other_locations
    a = "type Apple { name: String } type Query { a:Apple }"
    b = "type Banana { name: String } type Query { b:Banana }"
    supergraph = compose_definitions({ "a" => a, "b" => b })

    plan = GraphQL::Stitching::Planner.new(
      supergraph: supergraph,
      request: GraphQL::Stitching::Request.new("{ __schema { queryType { name } } a { name } }"),
    ).perform

    assert_equal 2, plan.ops.length

    assert_keys plan.ops[0].as_json, {
      location: "__super",
      selections: %|{ __schema { queryType { name } } }|,
    }

    assert_keys plan.ops[1].as_json, {
      location: "a",
      selections: %|{ a { name } }|,
    }
  end
end
