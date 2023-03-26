# frozen_string_literal: true

require "test_helper"
require_relative "../../../schemas/introspection"

describe "GraphQL::Stitching::Shaper, grooming" do
  def test_prunes_stitching_fields
    schema_sdl = "type Test { req: String! opt: String } type Query { test: Test }"
    shaper = GraphQL::Stitching::Shaper.new(
      supergraph: supergraph_from_schema(schema_sdl),
      request: GraphQL::Stitching::Request.new("{ test { __typename req opt } }"),
    )
    raw = {
      "test" => {
        "_STITCH_req" => "yes",
        "_STITCH_typename" => "Test",
        "__typename" => "Test",
        "req" => "yes",
        "opt" => nil,
      }
    }
    expected = {
      "test" => {
        "__typename" => "Test",
        "req" => "yes",
        "opt" => nil,
      }
    }

    assert_equal expected, shaper.perform!(raw)
  end

  def test_adds_missing_fields
    schema_sdl = "type Test { req: String! opt: String } type Query { test: Test }"
    shaper = GraphQL::Stitching::Shaper.new(
      supergraph: supergraph_from_schema(schema_sdl),
      request: GraphQL::Stitching::Request.new("{ test { req opt } }"),
    )
    raw = {
      "test" => {
        "_STITCH_req" => "yes",
        "_STITCH_typename" => "Test",
        "req" => "yes",
      }
    }
    expected = {
      "test" => {
        "req" => "yes",
        "opt" => nil,
      }
    }

    assert_equal expected, shaper.perform!(raw)
  end

  def test_grooms_through_inline_fragments
    schema_sdl = "type Test { req: String! opt: String } type Query { test: Test }"
    shaper = GraphQL::Stitching::Shaper.new(
      supergraph: supergraph_from_schema(schema_sdl),
      request: GraphQL::Stitching::Request.new("{ test { ... on Test { ... on Test { req opt } } } }"),
    )
    raw = {
      "test" => {
        "_STITCH_req" => "yes",
        "_STITCH_typename" => "Test",
        "req" => "yes",
      }
    }
    expected = {
      "test" => {
        "req" => "yes",
        "opt" => nil,
      }
    }

    assert_equal expected, shaper.perform!(raw)
  end

  def test_grooms_through_fragment_spreads
    schema_sdl = "type Test { req: String! opt: String } type Query { test: Test }"
    query = %|
      query { test { ...Test2 } }
      fragment Test1 on Test { req opt }
      fragment Test2 on Test { ...Test1 }
    |
    shaper = GraphQL::Stitching::Shaper.new(
      supergraph: supergraph_from_schema(schema_sdl),
      request: GraphQL::Stitching::Request.new(query),
    )
    raw = {
      "test" => {
        "_STITCH_req" => "yes",
        "_STITCH_typename" => "Test",
        "req" => "yes",
      }
    }
    expected = {
      "test" => {
        "req" => "yes",
        "opt" => nil,
      }
    }

    assert_equal expected, shaper.perform!(raw)
  end

  def test_renames_root_query_typenames
    schema_sdl = "type Query { field: String }"
    source = %|
      fragment RootAttrs on Query { typename2: __typename }
      query {
        __typename
        ...on Query { typename1: __typename }
        ...RootAttrs
      }
    |
    shaper = GraphQL::Stitching::Shaper.new(
      supergraph: supergraph_from_schema(schema_sdl),
      request: GraphQL::Stitching::Request.new(source),
    )

    raw = { "__typename" => "QueryRoot", "typename1" => "QueryRoot", "typename2" => "QueryRoot" }
    expected = { "__typename" => "Query", "typename1" => "Query", "typename2" => "Query" }
    assert_equal expected, shaper.perform!(raw)
  end

  def test_renames_root_mutation_typenames
    schema_sdl = "type Mutation { field: String } type Query { field: String }"
    source = %|
      fragment RootAttrs on Mutation { typename2: __typename }
      mutation {
        __typename
        ...on Mutation { typename1: __typename }
        ...RootAttrs
      }
    |
    shaper = GraphQL::Stitching::Shaper.new(
      supergraph: supergraph_from_schema(schema_sdl),
      request: GraphQL::Stitching::Request.new(source),
    )

    raw = { "__typename" => "MutationRoot", "typename1" => "MutationRoot", "typename2" => "MutationRoot" }
    expected = { "__typename" => "Mutation", "typename1" => "Mutation", "typename2" => "Mutation" }
    assert_equal expected, shaper.perform!(raw)
  end

  def test_handles_introspection_types
    schema_sdl = "type Test { req: String! opt: String } type Query { test: Test }"
    schema = GraphQL::Schema.from_definition(schema_sdl)
    shaper = GraphQL::Stitching::Shaper.new(
      supergraph: supergraph_from_schema(schema),
      request: GraphQL::Stitching::Request.new(INTROSPECTION_QUERY),
    )

    raw = schema.execute(query: INTROSPECTION_QUERY).to_h
    assert shaper.perform!(raw)
  end
end
