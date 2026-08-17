defmodule OpenApiSpex.SchemaResolverTest do
  use ExUnit.Case

  alias OpenApiSpex.{
    Info,
    MediaType,
    OpenApi,
    Operation,
    PathItem,
    Reference,
    RequestBody,
    Response,
    Schema,
    SchemaResolver
  }

  describe "resolve_schema_modules/1" do
    test "resolves schemas in OpenApi spec" do
      spec = %OpenApi{
        info: %Info{
          title: "Test",
          version: "1.0.0"
        },
        paths: %{
          "/api/users" => %PathItem{
            get: %Operation{
              responses: %{
                200 => %Response{
                  description: "Success",
                  content: %{
                    "application/json" => %MediaType{
                      schema: OpenApiSpexTest.Schemas.UsersResponse
                    }
                  }
                }
              }
            },
            post: %Operation{
              description: "Create a user",
              operationId: "UserController.create",
              requestBody: %RequestBody{
                content: %{
                  "application/json" => %MediaType{
                    schema: OpenApiSpexTest.Schemas.UserRequest
                  }
                }
              },
              responses: %{
                201 => %Response{
                  description: "Created",
                  content: %{
                    "application/json" => %MediaType{
                      schema: OpenApiSpexTest.Schemas.UserResponse
                    }
                  }
                }
              }
            }
          },
          "/api/users/{id}/payment_details" => %PathItem{
            get: %Operation{
              responses: %{
                200 => %Response{
                  description: "Success",
                  content: %{
                    "application/json" => %MediaType{
                      schema: OpenApiSpexTest.Schemas.PaymentDetails
                    }
                  }
                }
              }
            }
          },
          "/api/users/{id}/friends" => %PathItem{
            get: %Operation{
              parameters: [
                %OpenApiSpex.Parameter{
                  name: :id,
                  in: :path,
                  schema: %Schema{type: :integer}
                }
              ],
              responses: %{
                200 => %Response{
                  description: "Success",
                  content: %{
                    "application/json" => %MediaType{
                      schema: %Schema{
                        type: :array,
                        items: OpenApiSpexTest.Schemas.User
                      }
                    }
                  }
                }
              }
            }
          },
          "/api/users/subscribe" => %PathItem{
            post: %Operation{
              description: "Subscribe to user updates",
              operationId: "UserController.subscribe",
              requestBody: %RequestBody{
                required: true,
                content: %{
                  "application/json" => %MediaType{
                    schema: OpenApiSpexTest.Schemas.UserSubscribeRequest
                  }
                }
              },
              callbacks: %{
                "user_updated" => %{
                  "{$request.body#/callback_url}" => %PathItem{
                    post: %Operation{
                      description: "Provided endpoint for sending updates",
                      requestBody: %RequestBody{
                        required: true,
                        content: %{
                          "application/json" => %MediaType{
                            schema: OpenApiSpexTest.Schemas.UserResponse
                          }
                        }
                      },
                      responses: %{
                        200 => %Response{
                          description: "Your server returns this code if it accepts the callback"
                        }
                      }
                    }
                  }
                }
              },
              responses: %{
                201 => %Response{
                  description: "Webhook created"
                }
              }
            }
          },
          "/api/appointsments" => %PathItem{
            post: %Operation{
              description: "Create a new pet appointment",
              operationId: "PetAppointmentController.create",
              requestBody: %RequestBody{
                required: true,
                content: %{
                  "application/json" => %MediaType{
                    schema: OpenApiSpexTest.Schemas.PetAppointmentRequest
                  }
                }
              },
              responses: %{
                201 => %Response{
                  description: "Appointment created"
                }
              }
            }
          },
          "/api/credit-cards" => %PathItem{
            post: %Operation{
              description: "Add a new credit card number",
              operationId: "CreditCardController.create",
              requestBody: %RequestBody{
                required: true,
                content: %{
                  "application/json" => %MediaType{
                    schema: {OpenApiSpexTest.Schemas.FuncRefs, :credit_card_number}
                  }
                }
              },
              responses: %{
                201 => %Response{
                  description: "Number added"
                }
              }
            }
          }
        }
      }

      resolved = OpenApiSpex.resolve_schema_modules(spec)

      assert %Reference{"$ref": "#/components/schemas/UsersResponse"} =
               resolved.paths["/api/users"].get.responses[200].content["application/json"].schema

      assert %Reference{"$ref": "#/components/schemas/UserResponse"} =
               resolved.paths["/api/users"].post.responses[201].content["application/json"].schema

      assert %Reference{"$ref": "#/components/schemas/UserRequest"} =
               resolved.paths["/api/users"].post.requestBody.content["application/json"].schema

      assert "#/components/schemas/TrainingAppointment" =
               resolved.components.schemas["PetAppointmentRequest"].discriminator.mapping[
                 "training"
               ]

      assert "#/components/schemas/GroomingAppointment" =
               resolved.components.schemas["PetAppointmentRequest"].discriminator.mapping[
                 "grooming"
               ]

      assert "#/components/schemas/NailClippingAppointment" =
               resolved.components.schemas["PetAppointmentRequest"].discriminator.mapping[
                 "nail_clipping"
               ]

      assert %{
               "UserRequest" => %Schema{},
               "UserResponse" => %Schema{},
               "User" => %Schema{},
               "UserSubscribeRequest" => %Schema{},
               "PaymentDetails" => %Schema{},
               "CreditCardPaymentDetails" => %Schema{},
               "DirectDebitPaymentDetails" => %Schema{},
               "PetAppointmentRequest" => %Schema{},
               "TrainingAppointment" => %Schema{},
               "GroomingAppointment" => %Schema{},
               "CreditCardNumber" => %Schema{}
             } = resolved.components.schemas

      get_friends = resolved.paths["/api/users/{id}/friends"].get

      assert %Reference{"$ref": "#/components/schemas/User"} =
               get_friends.responses[200].content["application/json"].schema.items
    end

    test "raises informative error when schema :properties is not a map" do
      spec = %OpenApi{
        info: %Info{
          title: "Test",
          version: "1.0.0"
        },
        paths: %{
          "/api/users" => %PathItem{
            get: %Operation{
              responses: %{
                200 => %Response{
                  description: "Success",
                  content: %{
                    "application/json" => %MediaType{
                      schema: %Schema{
                        type: :object,
                        properties: Invalid
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }

      assert_raise RuntimeError, "Expected :properties to be a map. Got: Invalid", fn ->
        OpenApiSpex.resolve_schema_modules(spec)
      end
    end

    test "raises error when schema cannot be resolved" do
      spec = %OpenApi{
        info: %Info{
          title: "Test",
          version: "1.0.0"
        },
        paths: %{
          "/api/users" => %PathItem{
            get: %Operation{
              responses: %{
                200 => %Response{
                  description: "Success",
                  content: %{
                    "application/json" => %MediaType{
                      schema: %{}
                    }
                  }
                }
              }
            }
          }
        }
      }

      error_message = """
      Cannot resolve schema %{}.

      Must be one of:

      - schema module, or schema struct
      - list of schema modules, or schema structs
      - boolean
      - nil
      - reference
      """

      assert_raise RuntimeError, error_message, fn ->
        OpenApiSpex.resolve_schema_modules(spec)
      end
    end

    defmodule Duplicates.UsersResponse do
      require OpenApiSpex

      OpenApiSpex.schema(%{
        description: "A duplicate",
        type: :object,
        properties: %{
          unexpected: %Schema{type: :string}
        }
      })
    end

    test "resolution ignores schemas with duplicate title" do
      spec = %OpenApi{
        info: %Info{
          title: "Test",
          version: "1.0.0"
        },
        paths: %{
          "/api/users" => %PathItem{
            get: %Operation{
              responses: %{
                200 => %Response{
                  description: "Success",
                  content: %{
                    "application/json" => %MediaType{
                      schema: OpenApiSpexTest.Schemas.UsersResponse
                    }
                  }
                }
              }
            }
          },
          "/api/clones" => %PathItem{
            get: %Operation{
              responses: %{
                200 => %Response{
                  description: "Success",
                  content: %{
                    "application/json" => %MediaType{
                      schema: Duplicates.UsersResponse
                    }
                  }
                }
              }
            }
          }
        }
      }

      assert %{
               components: %{
                 schemas: %{
                   "UsersResponse" => %OpenApiSpex.Schema{
                     description: "A duplicate",
                     "x-struct": OpenApiSpex.SchemaResolverTest.Duplicates.UsersResponse
                   }
                 }
               }
             } = resolved = OpenApiSpex.resolve_schema_modules(spec)

      assert Map.keys(resolved.components.schemas) == ["UsersResponse"]
    end
  end

  describe "add_schemas/2" do
    @empty_spec %OpenApi{
      info: %Info{
        title: "Test",
        version: "1.0.0"
      },
      paths: %{},
      components: %{schemas: %{}}
    }

    defmodule SomeSchema do
      def schema do
        %Schema{
          type: :object,
          title: "SomeSchema",
          properties: %{name: %Schema{type: :string}}
        }
      end
    end

    test "Schema module" do
      spec = SchemaResolver.add_schemas(@empty_spec, [SomeSchema])

      assert spec.components.schemas == %{
               "SomeSchema" => SomeSchema.schema()
             }
    end

    defmodule ArraySchema do
      def schema do
        %Schema{
          type: :type,
          title: "ArraySchema",
          items: SomeSchema
        }
      end
    end

    test "Schema module of type:array with module-referenced items" do
      spec = SchemaResolver.add_schemas(@empty_spec, [ArraySchema])

      assert %{
               "ArraySchema" => array_schema,
               "SomeSchema" => some_schema
             } = spec.components.schemas

      assert some_schema == SomeSchema.schema()
      assert array_schema.title == "ArraySchema"

      assert array_schema.items == %OpenApiSpex.Reference{
               "$ref": "#/components/schemas/SomeSchema"
             }
    end
  end

  describe "titled schemas embedded inline" do
    defmodule InlineSlug do
      def schema do
        %Schema{type: :string, title: "InlineSlug", format: :uuid}
      end
    end

    defmodule InlineInner do
      def schema do
        %Schema{type: :object, title: "InlineInner", properties: %{slug: InlineSlug}}
      end
    end

    defmodule InlineViaFunction do
      def inner,
        do: %Schema{
          type: :object,
          title: "InlineViaFunction.Inner",
          properties: %{slug: InlineSlug}
        }
    end

    @empty_spec %OpenApi{
      info: %Info{title: "Test", version: "1.0.0"},
      paths: %{},
      components: %{schemas: %{}}
    }

    test "resolves nested schema modules of a titled schema embedded as a struct" do
      # The wrapper embeds the %Schema{} struct itself rather than referencing the module,
      # so InlineInner is registered while being resolved rather than via the module clause.
      wrapper = %Schema{
        type: :object,
        title: "InlineWrapper",
        properties: %{inner: InlineInner.schema()}
      }

      spec = SchemaResolver.add_schemas(@empty_spec, [wrapper])

      assert %{"InlineInner" => inner} = spec.components.schemas

      assert inner.properties.slug == %Reference{"$ref": "#/components/schemas/InlineSlug"},
             "components.schemas kept the pre-resolution copy of InlineInner"

      assert Map.has_key?(spec.components.schemas, "InlineSlug")
    end

    test "resolves nested schema modules of a titled schema returned by a plain function" do
      wrapper = %Schema{
        type: :object,
        title: "InlineWrapperViaFunction",
        properties: %{inner: InlineViaFunction.inner()}
      }

      spec = SchemaResolver.add_schemas(@empty_spec, [wrapper])

      assert %{"InlineViaFunction.Inner" => inner} = spec.components.schemas
      assert inner.properties.slug == %Reference{"$ref": "#/components/schemas/InlineSlug"}
    end

    test "resolving twice is a no-op once nested modules are resolved" do
      wrapper = %Schema{
        type: :object,
        title: "InlineWrapperIdempotent",
        properties: %{inner: InlineInner.schema()}
      }

      once =
        SchemaResolver.add_schemas(
          %OpenApi{
            info: %Info{title: "Test", version: "1.0.0"},
            paths: %{},
            components: %OpenApiSpex.Components{schemas: %{}}
          },
          [wrapper]
        )

      twice = SchemaResolver.resolve_schema_modules(once)

      assert once.components.schemas == twice.components.schemas
    end
  end

  describe "titled inline schemas are stored fully resolved in components.schemas" do
    defmodule LeafSchema do
      def schema do
        %Schema{title: "Leaf", type: :string}
      end
    end

    test "nested titled inline schema in a components entry has its module atoms resolved" do
      spec = %OpenApi{
        info: %Info{title: "Test", version: "1.0.0"},
        paths: %{},
        components: %OpenApiSpex.Components{
          schemas: %{
            "Root" => %Schema{
              title: "Root",
              type: :object,
              properties: %{
                child: %Schema{
                  title: "AChild",
                  type: :object,
                  properties: %{leaf: LeafSchema}
                }
              }
            }
          }
        }
      }

      resolved = SchemaResolver.resolve_schema_modules(spec)

      assert %Schema{properties: %{leaf: %Reference{"$ref": "#/components/schemas/Leaf"}}} =
               resolved.components.schemas["AChild"]

      assert {:ok, %{leaf: "x"}} =
               OpenApiSpex.Cast.cast(
                 resolved.components.schemas["AChild"],
                 %{"leaf" => "x"},
                 resolved.components.schemas
               )
    end

    defmodule DoublyNestedParent do
      # Inner title ("AInner") iterates before outer title ("ZOuter") in the
      # components map, so the second resolver sweep heals "AInner" first and
      # then re-encounters its raw copy while resolving "ZOuter".
      def schema do
        %Schema{
          title: "Parent",
          type: :object,
          properties: %{
            outer: %Schema{
              title: "ZOuter",
              type: :object,
              properties: %{
                inner: %Schema{
                  title: "AInner",
                  type: :object,
                  properties: %{leaf: LeafSchema}
                }
              }
            }
          }
        }
      end
    end

    test "doubly nested titled inline schema resolved via paths stays resolved" do
      spec = %OpenApi{
        info: %Info{title: "Test", version: "1.0.0"},
        paths: %{
          "/things" => %PathItem{
            get: %Operation{
              operationId: "ThingController.show",
              responses: %{
                200 => %Response{
                  description: "Success",
                  content: %{
                    "application/json" => %MediaType{schema: DoublyNestedParent}
                  }
                }
              }
            }
          }
        },
        components: %OpenApiSpex.Components{schemas: %{}}
      }

      resolved = SchemaResolver.resolve_schema_modules(spec)

      assert %Schema{properties: %{leaf: %Reference{"$ref": "#/components/schemas/Leaf"}}} =
               resolved.components.schemas["AInner"]

      assert {:ok, %{leaf: "x"}} =
               OpenApiSpex.Cast.cast(
                 resolved.components.schemas["AInner"],
                 %{"leaf" => "x"},
                 resolved.components.schemas
               )
    end
  end
end
