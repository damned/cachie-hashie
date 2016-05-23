require 'test/unit'
require 'pathname'
require 'json'
require 'date'

class JsonDataDirQuery
  attr_reader :dir
  def initialize(dir_path, options = { cache: false })
    @dir = Pathname.new dir_path
    @should_cache = options[:cache]
    @dir_cache = {}
  end
  def all
    Dir.glob((dir + '*.json').to_s).map do |f|
      if cache?
        data = @dir_cache[f]
        if data.nil?
          @dir_cache[f] = parse File.read(f)
          data = @dir_cache[f]
        end
        data
      else
        parse File.read(f)
      end
    end
  end

  def all_by_date(options = { desc: false })
    sorted = all.sort_by {|item|
      item[:date]
    }
    return sorted.reverse if options[:desc]
    sorted
  end
  private
  def cache?
    @should_cache
  end
  def parse(json)
    JSON.parse json, symbolize_names: true
  end
end

module Stopwatch
  def stopwatch(what)
    start = Time.now
    begin
      yield
    ensure
      duration = Time.now - start

      STDERR.puts "#{what} took: #{duration}s"
      duration
    end
  end
end

module QueryTests

  def test_fetch_all_data
    stopwatch 'fetch all data' do
      all = query.all

      expected = 900

      assert_equal(true, all.size > expected, "there should be at least #{expected} articles, currently: #{all.size}")
      assert_equal(true, all.any? {|article| article[:id] == 'qa-dead' }, 'should have is qa dead article')
    end
  end

  def test_orders_by_date
    stopwatch 'fetch all by date' do
      all = query.all_by_date desc: true

      today = DateTime.now

      assert_equal(true, all.size > 10, "there should be a few articles, currently: #{all.size}")

      first_article_date = DateTime.parse all.first[:date]
      second_article_date = DateTime.parse all[1][:date]

      assert_equal(true, first_article_date > today, "first article date #{first_article_date} should be after today")
      assert_equal(true, second_article_date < first_article_date, "second article date #{second_article_date} should be before first")
    end
  end

  ## check mem usage

  ## date parsing - keep generality... store queryable 'date' field as DateTime.parse ?

  ## file modification times? (copy files in setup)d
  ###  dirs don't get mod times recursively
  ###  dir mod times get updated for file change in dir
  


end

class TestQueryPerf < Test::Unit::TestCase
  include Stopwatch

  attr_reader :query

  def setup
    @query = JsonDataDirQuery.new '../tw.development.content/draft/en/articles'
  end

  include QueryTests

end

class TestQueryWithCachePerf < Test::Unit::TestCase
  include Stopwatch

  attr_reader :query

  def setup
    STDERR.puts 'with caching:'
    @query = JsonDataDirQuery.new '../tw.development.content/draft/en/articles', cache: true
    warm_up_cache
  end

  include QueryTests

  private

  def warm_up_cache
    stopwatch 'warmup' do
      query.all
    end
  end
end
