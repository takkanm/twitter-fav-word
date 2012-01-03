# coding: utf-8
require 'twitter'
require 'natto'

DEFAULT_FAV_COUNT = 500

class Favorite
  def initialize(user)
    @user = user
  end

  def tweets(count = DEFAULT_FAV_COUNT)
    get_tweets(count)[0...count]
  end

  def get_tweets(count)
    request_count = (count / 17).succ

    (1..request_count).inject([]) {|tweets, i|
      tweets + Twitter.favorites(id: @user, page: i).map(&:text)
    }
  end
end

class NattoWord
  attr_reader :original_form, :part, :original_reading, :default_form, :text

  def initialize(text, natto_line)
    @text = text
    @original_form , natto_form = *(natto_line.split(/\t/))

    natto_info = natto_form.split(/,/)
    @part = natto_info[0]
    @original_reading = natto_info[-1]
    @default_form = natto_info[-3] == '*' ? @original_form : natto_info[-3]
  end

  def noun_or_verb_or_adjective?
    noun? || verb? || adjective?
  end

  def noun_or_adjective?
    noun? || adjective?
  end

  def noun_or_adjective_or_adjective_verb?
    noun? || adjective? || adjective_verb?
  end

  def noun?
    @part == '名詞'
  end

  def verb?
    @part == '動詞'
  end

  def adjective?
    @part == '形容詞'
  end

  def adjective_verb?
    @part == '形容動詞'
  end
end

class Tweet
  @natto = Natto::MeCab.new

  def self.natto
    @natto
  end

  def initialize(text)
    @text = text
  end

  def uniq_nattolize_words
    nattolize_words.inject({}) {|words, nattolize_word|
      words[nattolize_word.original_form] = nattolize_word
      words
    }.values
  end

  def nattolize_words
    nattolize.map {|natto_word_text|
      NattoWord.new(@text, natto_word_text)
    }
  end

  def nattolize
    Tweet.natto.parse(@text).split(/\n/).delete_if {|natto_line| natto_line == 'EOS' }
  end
end

class FavWordsCollecter
  attr_reader :words

  def initialize(name, count = DEFAULT_FAV_COUNT)
    @name = name
    @count = count
  end

  def run
    @words = collect
  end

  def collect
    fav_words.inject({}) {|grouped_words, natto_word|
      if collect_target?(natto_word)
        grouped_words[natto_word.default_form] ||= []
        grouped_words[natto_word.default_form] << natto_word
      end

      grouped_words
    }
  end

  def fav_words
    Favorite.new(@name).tweets(@count).inject([]) {|fav_words, t|
      tweet = Tweet.new(t)
      fav_words + tweet.nattolize_words
    }
  end

  def collect_target?(natto_word)
    natto_word.noun_or_adjective_or_adjective_verb?
  end
end

if $0 == __FILE__
  if ARGV.size == 1
    fav_words = FavWordsCollecter.new(ARGV.shift)
    puts fav_words.run.map {|k,v| [k, v.size] }.sort{|a,b| a[1] <=> b[1] }.reverse.inspect
  else
    puts "usage: ruby ./#{$0} twitter_id"
  end
end
