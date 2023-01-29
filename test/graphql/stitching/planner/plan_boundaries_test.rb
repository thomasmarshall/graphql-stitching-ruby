# frozen_string_literal: true

require "test_helper"

describe "GraphQL::Stitching::Plan, boundaries" do

  def setup
    @storefronts = "
      type Storefront {
        id: ID!
        name: String!
        products: [Product]!
      }
      type Product {
        upc: ID!
      }
      type Query {
        storefront(id: ID!): Storefront
      }
    "

    @products = "
      type Product {
        upc: ID!
        name: String!
        price: Float!
        manufacturer: Manufacturer!
      }
      type Manufacturer {
        id: ID!
        name: String!
        products: [Product]!
      }
      type Query {
        product(upc: ID!): Product @boundary(key: \"upc\")
        productsManufacturer(id: ID!): Manufacturer @boundary(key: \"id\")
      }
    "

    @manufacturers = "
      type Manufacturer {
        id: ID!
        name: String!
        address: String!
      }
      type Query {
        manufacturer(id: ID!): Manufacturer @boundary(key: \"id\")
      }
    "

    @graph_context = compose_definitions({
      "storefronts" => @storefronts,
      "products" => @products,
      "manufacturers" => @manufacturers,
    })
  end

  def test_collects_unique_fields_across_boundary_locations
    document = "
      query {
        storefront(id: \"1\") {
          name
          products {
            name
            manufacturer {
              address
              products {
                name
              }
            }
          }
        }
      }
    "

    plan = GraphQL::Stitching::Plan.new(
      graph_context: @graph_context,
      document: GraphQL.parse(document),
    ).plan

    assert_equal 3, plan.operations.length

    first = plan.operations[0]
    assert_equal "storefronts", first.location
    assert_equal "query", first.operation_type
    assert_equal [], first.insertion_path
    assert_equal "{ storefront(id: \"1\") { name products { _STITCH_upc: upc } } }", first.selection_set
    assert_nil first.after_key

    second = plan.operations[1]
    assert_equal "products", second.location
    assert_equal "query", second.operation_type
    assert_equal ["storefront", "products"], second.insertion_path
    assert_equal "{ name manufacturer { products { name } _STITCH_id: id } }", second.selection_set
    assert_equal first.key, second.after_key
    # @todo - check boundary?

    third = plan.operations[2]
    assert_equal "manufacturers", third.location
    assert_equal "query", third.operation_type
    assert_equal ["storefront", "products", "manufacturer"], third.insertion_path
    assert_equal "{ address }", third.selection_set
    assert_equal second.key, third.after_key
    # @todo - check boundary?
  end

  def test_collects_common_fields_from_first_available_location
    document1 = "{         manufacturer(id: \"1\") { name products { name } } }"
    document2 = "{ productsManufacturer(id: \"1\") { name products { name } } }"

    plan1 = GraphQL::Stitching::Plan.new(
      graph_context: @graph_context,
      document: GraphQL.parse(document1),
    ).plan

    plan2 = GraphQL::Stitching::Plan.new(
      graph_context: @graph_context,
      document: GraphQL.parse(document2),
    ).plan

    assert_equal 2, plan1.operations.length
    assert_equal 1, plan2.operations.length

    p1_first = plan1.operations[0]
    assert_equal "manufacturers", p1_first.location
    assert_equal "query", p1_first.operation_type
    assert_equal [], p1_first.insertion_path
    assert_equal "{ manufacturer(id: \"1\") { name _STITCH_id: id } }", p1_first.selection_set
    assert_nil p1_first.after_key

    p1_second = plan1.operations[1]
    assert_equal "products", p1_second.location
    assert_equal "query", p1_second.operation_type
    assert_equal ["manufacturer"], p1_second.insertion_path
    assert_equal "{ products { name } }", p1_second.selection_set
    assert_equal p1_first.key, p1_second.after_key
    # @todo - check boundary?

    p2_first = plan2.operations[0]
    assert_equal "products", p2_first.location
    assert_equal "query", p2_first.operation_type
    assert_equal [], p2_first.insertion_path
    assert_equal "{ productsManufacturer(id: \"1\") { name products { name } } }", p2_first.selection_set
    assert_nil p2_first.after_key
  end
end