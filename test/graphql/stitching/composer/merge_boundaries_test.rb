# frozen_string_literal: true

require "test_helper"

describe 'GraphQL::Stitching::Composer, merging boundary queries' do
  def test_merges_boundaries_with_multiple_keys
    a = %{
      type T { upc:ID! }
      type Query { a(upc:ID!):T @boundary(key: "upc") }
    }
    b = %{
      type T { id:ID! upc:ID! }
      type Query { b(id: ID, upc:ID):T @boundary(key: "id:id") @boundary(key: "upc:upc") }
    }
    c = %{
      type T { id:ID! }
      type Query { c(id:ID!):T @boundary(key: "id") }
    }

    supergraph = compose_definitions({ "a" => a, "b" => b, "c" => c })

    assert_boundary(supergraph, "T", location: "a", selection: "upc", field: "a", arg: "upc")
    assert_boundary(supergraph, "T", location: "b", selection: "upc", field: "b", arg: "upc")
    assert_boundary(supergraph, "T", location: "b", selection: "id", field: "b", arg: "id")
    assert_boundary(supergraph, "T", location: "c", selection: "id", field: "c", arg: "id")
  end

  def test_expands_interface_boundary_accessors_to_relevant_types
    a = %{
      interface Fruit { id:ID! }
      type Apple implements Fruit { id:ID! name:String }
      type Banana implements Fruit { id:ID! name:String }
      type Coconut implements Fruit { id:ID! name:String }
      type Query { fruit(id:ID!):Fruit @boundary(key: "id") }
    }
    b = %{
      type Apple { id:ID! color:String }
      type Banana { id:ID! color:String }
      type Query {
        a(id:ID!):Apple @boundary(key: "id")
        b(id:ID!):Banana @boundary(key: "id")
      }
    }

    supergraph = compose_definitions({ "a" => a, "b" => b })

    assert_equal 1, supergraph.boundaries["Fruit"].length
    assert_equal 2, supergraph.boundaries["Apple"].length
    assert_equal 2, supergraph.boundaries["Banana"].length
    assert_nil supergraph.boundaries["Coconut"]

    assert_boundary(supergraph, "Fruit", location: "a", selection: "id", field: "fruit", arg: "id")
    assert_boundary(supergraph, "Apple", location: "a", selection: "id", field: "fruit", arg: "id")
    assert_boundary(supergraph, "Banana", location: "a", selection: "id", field: "fruit", arg: "id")
    assert_boundary(supergraph, "Apple", location: "b", selection: "id", field: "a", arg: "id")
    assert_boundary(supergraph, "Banana", location: "b", selection: "id", field: "b", arg: "id")
  end

  def test_expands_union_boundary_accessors_to_relevant_types
    a = %{
      type Apple { id:ID! name:String }
      type Banana { id:ID! name:String }
      union Fruit = Apple | Banana
      type Query {
        fruit(id:ID!):Fruit @boundary(key: "id")
      }
    }
    b = %{
      type Apple { id:ID! color:String }
      type Coconut { id:ID! name:String }
      union Fruit = Apple | Coconut
      type Query {
        a(id:ID!):Apple @boundary(key: "id")
        c(id:ID!):Coconut
      }
    }

    supergraph = compose_definitions({ "a" => a, "b" => b })
    assert_equal 1, supergraph.boundaries["Fruit"].length
    assert_equal 2, supergraph.boundaries["Apple"].length
    assert_nil supergraph.boundaries["Banana"]
    assert_nil supergraph.boundaries["Coconut"]

    assert_boundary(supergraph, "Fruit", location: "a", selection: "id", field: "fruit", arg: "id")
    assert_boundary(supergraph, "Apple", location: "a", selection: "id", field: "fruit", arg: "id")
    assert_boundary(supergraph, "Apple", location: "b", selection: "id", field: "a", arg: "id")
  end

  private

  def assert_boundary(supergraph, type_name, location:, selection: nil, field: nil, arg: nil)
    boundary = supergraph.boundaries[type_name].find do |b|
      conditions = []
      conditions << (b["location"] == location)
      conditions << (b["selection"] == selection) if selection
      conditions << (b["field"] == field) if field
      conditions << (b["arg"] == arg) if arg
      conditions.all?
    end
    assert boundary, "No boundary found for #{[location, type_name, selection, field, arg].join(".")}"
  end
end