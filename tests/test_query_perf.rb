require 'test/unit'
require 'pathname'
require 'json'
require 'date'


class CachieHash

end

class FileBackedHash

end


class JsonDataDirQuery
  attr_reader :dir, :dir_cache
  def initialize(dir_path, options = { cache: false })
    @dir = Pathname.new dir_path
    @should_cache = options[:cache]
    @dir_cache = {}
    @dir_mtime_cache = {}
  end
  def all
    check_mtime = true
    Dir.glob((dir + '*.json').to_s).map do |f|
      mtime = File.stat(f).mtime if check_mtime
      if cache?
        data = dir_cache[f]
        if data.nil?
          @dir_mtime_cache[f] = mtime
          data = parse File.read(f)
          dir_cache[f] = data
        else
          if (check_mtime && @dir_mtime_cache[f] != mtime)
            puts "WOWSERS: #{f}"
            @dir_mtime_cache[f] = mtime
            data = parse File.read(f)
            dir_cache[f] = data
          end
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

require 'knjrbfw'

module Sizeable
  def size_up(o, name = 'object')

    analyzer = Knj::Memory_analyzer::Object_size_counter.new(o)

    puts "#{name} size: #{analyzer.calculate_size}"
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

  def test_changes_order_when_insert_more_recent_article
    stopwatch 'fetch all by date' do
      today = DateTime.now

      all = query.all_by_date desc: true

      first_article_date = DateTime.parse all.first[:date]

      first_article_path = test_data.single_item_path(all.first[:id])
      first_article_with_mods = all.first.dup
      first_article_with_mods[:date] = '2018-03-02T05:00:00+00:00'

      puts "WOOGA: #{first_article_path}"

      File.write first_article_path, first_article_with_mods.to_json

      STDERR.puts "**** wrote revised article date"

      revised_all = query.all_by_date desc: true

      revised_first_article_date = DateTime.parse revised_all.first[:date]

      assert_equal(true, revised_first_article_date > first_article_date, "first article date #{revised_first_article_date} should be after original #{first_article_date}")
    end
  end

end

require 'fileutils'

class JsonTestData
  def initialize(source_dir = '../tw.development.content/draft/en/articles')
    @source_dir = source_dir
  end

  def setup
    FileUtils.rm_rf test_dir
    FileUtils.mkdir_p test_dir
    `cp #{@source_dir}/* #{test_dir}`
    test_dir
  end

  def single_item_path(id)
    "#{test_dir}/#{id}.json"
  end

  def test_dir
    '/tmp/test_query_perf/json_data_dir'
  end
end

class TestQueryPerf < Test::Unit::TestCase
  include Stopwatch
  include Sizeable

  attr_reader :query, :test_data

  def setup
    @test_data = JsonTestData.new
    @query = JsonDataDirQuery.new test_data.setup
  end

  def teardown
    size_up query.dir_cache, 'query dir cache'
  end

  include QueryTests

end

class TestQueryWithCachePerf < Test::Unit::TestCase
  include Stopwatch
  include Sizeable

  attr_reader :query, :test_data

  def setup
    @test_data = JsonTestData.new
    STDERR.puts 'with caching:'
    @query = JsonDataDirQuery.new test_data.setup, cache: true

    warm_up_cache
  end

  def teardown
    size_up query.dir_cache, 'query dir cache'
  end

  include QueryTests

  private

  def warm_up_cache
    stopwatch 'warmup' do
      query.all
    end
  end
end

## check mem usage
### 950 articles:
### without body:  250kb ~ 0.25MB ~ 0.25 kb/a
### with body:    7600kb ~    8MB ~    8 kb/a

## date parsing - keep generality... store queryable 'date' field as DateTime.parse ?
### DateTime.parse works for both format date strings we use at mo
### use for query and fallback to string comp if doesn't parse?
### return data as original string
### ** caching for purposes of query as different layer ?

## file modification times? (copy files in setup)d
###  dirs don't get mod times recursively
###  dir mod times get updated for file change in dir - wrong! must have observed side effect of tools
###    therefore, need to check file mod times individually

