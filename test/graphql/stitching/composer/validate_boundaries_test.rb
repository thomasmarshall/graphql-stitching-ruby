# frozen_string_literal: true

require "test_helper"

describe 'GraphQL::Stitching::Composer, validate boundaries' do

  def test_validates_only_one_boundary_query_per_type_location_key
    a = %{
      interface I { id:ID! }
      type T implements I { id:ID! name:String }
      type Query {
        t(id: ID!):T @boundary(key: "id")
        i(id: ID!):I @boundary(key: "id")
      }
    }
    b = %{type T { id:ID! size:Float } type Query { b:T }}

    assert_error("Multiple boundary queries for `T.id` found in a", ValidationError) do
      compose_definitions({ "a" => a, "b" => b })
    end
  end

  def test_permits_multiple_boundary_query_keys_per_type_location
    a = %{
      type T { upc:ID! name:String }
      type Query { a(upc:ID!):T @boundary(key: "upc") }
    }
    b = %{
      type T { id:ID! upc:ID! }
      type Query {
        b1(upc:ID!):T @boundary(key: "upc")
        b2(id:ID!):T @boundary(key: "id")
      }
    }
    c = %{
      type T { id:ID! size:Int }
      type Query { c(id:ID!):T @boundary(key: "id") }
    }

    assert compose_definitions({ "a" => a, "b" => b, "c" => c })
  end

  def test_validates_at_least_one_boundary_per_type_location
    a = %{type T { id:ID! name:String } type Query { a(id: ID!):T @boundary(key: "id") }}
    b = %{type T { id:ID! size:Float } type Query { b:T }}

    assert_error("A boundary query is required for `T` in b", ValidationError) do
      compose_definitions({ "a" => a, "b" => b })
    end
  end

  def test_permits_no_boundary_query_for_key_only_types
    a = %{type T { id:ID! name:String } type Query { a(id: ID!):T @boundary(key: "id") }}
    b = %{type T { id:ID! } type Query { b:T }}

    assert compose_definitions({ "a" => a, "b" => b })
  end

  def test_validates_bidirection_types_are_mutually_accessible
    a = %{
      type T { upc:ID! name:String }
      type Query { a(upc:ID!):T @boundary(key: "upc") }
    }
    b = %{
      type T { id:ID! weight:Int }
      type Query { b(id:ID!):T @boundary(key: "id") }
    }
    c = %{
      type T { id:ID! size:Int }
      type Query { c(id:ID!):T @boundary(key: "id") }
    }

    assert_error("Cannot route `T` boundaries in a", ValidationError) do
      compose_definitions({ "a" => a, "b" => b, "c" => c })
    end
  end

  def test_validates_outbound_types_can_access_all_bidirection_types
    a = %{
      type T { upc:ID! }
      type Query { a:T }
    }
    b = %{
      type T { upc:ID! name:String }
      type Query { b(upc:ID!):T @boundary(key: "upc") }
    }
    c = %{
      type T { id:ID! size:Int }
      type Query { c(id:ID!):T @boundary(key: "id") }
    }

    assert_error("Cannot route `T` boundaries in a", ValidationError) do
      compose_definitions({ "a" => a, "b" => b, "c" => c })
    end
  end

  def test_permits_shared_types_across_locations_with_matching_compositions
    a = %{type T { id:ID! name: String } type Query { a:T }}
    b = %{type T { id:ID! name: String } type Query { b:T }}

    assert compose_definitions({ "a" => a, "b" => b })
  end

  def test_validates_shared_types_across_locations_must_have_matching_compositions
    a = %{type T { id:ID! name: String extra: String } type Query { a:T }}
    b = %{type T { id:ID! name: String } type Query { b:T }}

    assert_error("Shared type `T` must have consistent fields", ValidationError) do
      assert compose_definitions({ "a" => a, "b" => b })
    end
  end
end
