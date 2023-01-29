# frozen_string_literal: true

module Schemas
  module ThreeLocations
    PRODUCTS = [
      { upc: '1', name: 'iPhone', price: 699.99, manufacturer_id: '1' },
      { upc: '2', name: 'Apple Watch', price: 399.99, manufacturer_id: '1' },
      { upc: '3', name: 'Super Baking Cookbook', price: 15.99, manufacturer_id: '2' },
      { upc: '4', name: 'Best Selling Novel', price: 7.99, manufacturer_id: '2' },
      { upc: '5', name: 'iOS Survival Guide', price: 24.99, manufacturer_id: '1' },
    ]

    class Boundary < GraphQL::Schema::Directive
      graphql_name "boundary"
      locations FIELD_DEFINITION
      argument :key, String
      repeatable true
    end

    class Products < GraphQL::Schema
      module Node
        include GraphQL::Schema::Interface

        field :upc, ID, null: false
      end

      class ShippingOption < GraphQL::Schema::Enum
        value "STANDARD"
        value "EXPRESS"
      end

      class Product < GraphQL::Schema::Object
        implements Node
        description "products desc"

        field :upc, ID, null: false, description: "products desc"

        field :name, String, null: false

        field :price, Float, null: false

        field :manufacturer, "TestSchema::Basic::Products::Manufacturer", null: false

        def manufacturer
          { id: object[:manufacturer_id] }
        end

        field :shipping, [ShippingOption], null: false
      end

      class Manufacturer < GraphQL::Schema::Object
        field :id, ID, null: false

        field :products, [Product], null: false

        def products
          PRODUCTS.select { _1[:manufacturer_id] == object[:id] }
        end
      end

      class Widget < GraphQL::Schema::Union
        possible_types Product
      end

      class ProductHandle < GraphQL::Schema::InputObject
        description "Handle reference for a product"
        argument :handle, String, "The handle"
      end

      class RootQuery < GraphQL::Schema::Object
        field :thing1, Widget, null: true

        field :product, Product, null: false do
          directive Boundary, key: "upc"
          argument :upc, ID, required: true
        end

        field :product_by_handle, Product, null: true do
          argument :handle, ProductHandle, required: true
        end

        def product(upc:)
          PRODUCTS.find { _1[:upc] == upc }
        end
      end

      query RootQuery
    end

    STOREFRONTS = [
      { id: '1', name: 'eShoppe', product_upcs: ['1', '2'] },
      { id: '2', name: 'BestBooks Online', product_upcs: ['3', '4', '5'] },
    ]

    class Storefronts < GraphQL::Schema
      class Product < GraphQL::Schema::Object
        description "storefronts desc"

        field :upc, ID, null: false, description: "storefronts desc"
      end

      class Storefront < GraphQL::Schema::Object
        field :id, ID, null: false
        field :name, String, null: false
        field :products, [Product], null: false

        def products
          object[:product_upcs].map { |upc| { upc: upc } }
        end
      end

      class Query < GraphQL::Schema::Object
        field :storefront, Storefront, null: true do
          directive Boundary, key: "id"
          argument :id, ID, required: true
        end

        def storefront(id:)
          STOREFRONTS.find { _1[:id] == id }
        end
      end

      query Query
    end

    MANUFACTURERS = [
      { id: '1', name: 'Apple', address: '123 Main' },
      { id: '2', name: 'Macmillan', address: '456 Market' },
    ]

    class Manufacturers < GraphQL::Schema
      class Manufacturer < GraphQL::Schema::Object
        field :id, ID, null: false
        field :name, String, null: false
        field :address, String, null: false
      end

      class Widget < GraphQL::Schema::Union
        possible_types Manufacturer
      end

      class Query < GraphQL::Schema::Object
        field :thing2, Widget, null: true

        field :manufacturer, Manufacturer, null: true do
          directive Boundary, key: "id"
          directive Boundary, key: "upc"
          argument :id, ID, required: true
        end

        def manufacturer(id:)
          MANUFACTURERS.find { _1[:id] == id }
        end
      end

      query Query
    end
  end
end