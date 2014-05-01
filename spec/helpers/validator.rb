require 'multi_json'

module ValidatorHelpers

  def self.included(base)
    base.send(:extend, ClassMethods)
  end

  def read(dir, filename)
    path = File.join(dir, "#{filename}.json")
    if File.exists?(path)
      begin
        MultiJson.load(File.read(path))
      rescue MultiJson::ParseError => e
        fail("JSON parse error when loading #{path}")
      end
    else
      pending("missing #{filename}.json fixture")
    end
  end

  def definition(dir)
    read(dir, 'definition')
  end

  def api(dir)
    read(dir, 'api')
  end

  def errors(dir)
    read(dir, 'errors').map do |error|
      error.is_a?(Hash) ? match(error['match']) : error
    end
  end

  module ClassMethods

    def test_name(dir)
      File.basename(dir).sub(/^\d+_/, '').gsub('_', ' ')
    end

    def example_directory?(path)
      File.directory?(path) &&
      Dir.new(path).to_a[2..-1].none? { |f| File.directory?(File.join(path, f)) }
    end

    def example_tree
      tree = {}
      Dir.glob('spec/fixtures/resources/**/*').each do |dir|
        if example_directory?(dir)
          parts = dir.split('/')
          final = parts[3..-2].inject(tree) do |t, part|
            t[part] ||= {}
          end
          final[parts.last] = dir
        end
      end
      tree
    end

    def each_example(group, example, &block)
      example.each do |key, value|
        if value.is_a?(Hash)
          each_example(group.describe(key.sub(/^\d+_/, '')), value, &block)
        else
          yield(group, value)
        end
      end
    end

  end
end
