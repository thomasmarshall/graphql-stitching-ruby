# frozen_string_literal: true

module Schemas
  module CompositeKeys
    class Boundary < GraphQL::Schema::Directive
      graphql_name "stitch"
      locations FIELD_DEFINITION
      argument :key, String
      repeatable true
    end

    PRODUCTS = [
      { id: '1', shop_id: '123', handle: 'iphone', name: 'iPhone', location: 'Toronto' },
    ].freeze

    # Storefronts

    class Storefronts < GraphQL::Schema
      class Product < GraphQL::Schema::Object
        field :id, ID, null: false
        field :shop_id, ID, null: false
        field :handle, String, null: false
        field :location, String, null: false
      end

      class Query < GraphQL::Schema::Object
        field :storefronts_product_by_id, Product, null: false do
          directive Boundary, key: "id"
          argument :id, ID, required: true
        end

        def storefronts_product_by_id(id:)
          PRODUCTS.find { _1[:id] == id }
        end
      end

      query Query
    end

    # Products

    class Products < GraphQL::Schema
      class Product < GraphQL::Schema::Object
        field :id, ID, null: false
        field :name, String, null: false
      end

      class Query < GraphQL::Schema::Object
        field :products_product_by_composite_key, Product, null: false do
          directive Boundary, key: "shopId handle"
          argument :shop_id, ID, required: true
          argument :handle, String, required: true
        end

        def products_product_by_composite_key(shop_id:, handle:)
          PRODUCTS.find { _1[:shop_id] == shop_id && _1[:handle] == handle }
        end
      end

      query Query
    end
  end
end
