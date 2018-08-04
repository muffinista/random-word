require 'set'
require 'pathname'
require 'json'

# Provides random, non-repeating enumerators of a large list of
# english words. For example"
#
#     RandomWord.adjs.next #=> "strengthened"
#
module RandomWord
  module EachRandomly
    attr_accessor :random_word_exclude_list
    attr_accessor :min_length
    attr_accessor :max_length

    def each_randomly(&blk)
      used = Set.new
      skipped = Set.new
      loop do
        idx = next_unused_idx(used)
        used << idx
        word = at(idx)
        if excluded?(word)
          skipped << idx
          next
        end
        yield word
        used.subtract(skipped)
        skipped.clear
      end

    rescue OutOfWords
      # we are done.
    end

    def set_constraints(opts = {})
      @min_length = opts[:not_shorter_than] || 1
      @max_length = opts[:not_longer_than] || Float::INFINITY
    end

    def rng=(r)
      @_rng = r
    end
    def rng
      @_rng ||= Random.new(Random.new_seed)
    end

    def self.extended(mod)
      mod.set_constraints
    end

    private

    
    def next_unused_idx(used)
      idx = rng.rand(length)
      try = 1
      while used.include?(idx)
        raise OutOfWords if try > 1000
        idx = rng.rand(length)
        try += 1
      end

      idx
    end

    def excluded?(word)
      exclude_list = Array(@random_word_exclude_list)
      exclude_list.any? {|r| r === word} || word.length < min_length || (!(max_length.nil?) && word.length > max_length)
    end

    class OutOfWords < Exception; end
  end

  class << self
    attr_accessor :word_list

    def exclude_list
      @exclude_list ||= []
    end

    def rng=(r)
      word_list.rng = r
    end

    # @return [Enumerator] Random noun enumerator
    def nouns(opts = {})
      @nouns ||= enumerator(load_word_list("nouns.json"), exclude_list)
      word_list.set_constraints(opts)
      @nouns
    end

    # @return [Enumerator] Random adjective enumerator
    def adjs(opts = {})
      @adjs ||= enumerator(load_word_list("adjs.json"), exclude_list)
      word_list.set_constraints(opts)
      @adjs
    end

    def words(opts={})
      @words ||= enumerator(load_word_list("adjs.json") + load_word_list("nouns.json"), exclude_list)
      word_list.set_constraints(opts)
      @words
    end

    
    # @return [Enumerator] Random phrase enumerator
    def phrases
      @phrases ||= Enumerator.new(Class.new do 
        def each()
          while true
            yield "#{RandomWord.adjs.next} #{RandomWord.nouns.next}"
          end
        end
      end.new)
    end

    # Create a random, non-repeating enumerator for a list of words
    # (or anything really).
    def enumerator(word_list, list_of_regexs_or_strings_to_exclude = [])
      @word_list = word_list
      word_list.extend EachRandomly
      word_list.random_word_exclude_list = list_of_regexs_or_strings_to_exclude
      word_list.enum_for(:each_randomly)
    end

    protected

    def load_word_list(name)
      filename = File.join Pathname(File.dirname(__FILE__)), "../data", name
      JSON.parse(File.read(filename))
    end
  end
end

