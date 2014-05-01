require 'spec_helper'
require 'helpers/validator.rb'

module Aws
  class Resource
    describe DefinitionValidator do

      include ValidatorHelpers

      each_example(self, example_tree) do |group, dir|
        group.it(test_name(dir)) do
          validator = DefinitionValidator.new(definition(dir), api(dir))
          expect(validator.errors).to match(errors(dir))
        end
      end

    end
  end
end
