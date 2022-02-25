if ARGV.length == 0
  puts "Usage: ruby wordle-solver.rb 'ro*ate!'"
  puts '* means present somewhere, ! means present in position'
  puts 'Guess: roate'
  exit
end

ALL_SYSTEM_WORDS = '/usr/share/dict/words'
POSSIBLE_SOLUTIONS = './possible-solutions.txt'
POSSIBLE_GUESSES_LESS_SOLUTIONS = './possible-guesses-less-solutions.txt'

ALL_POSSIBLE_SOLUTIONS = File.read(POSSIBLE_SOLUTIONS).split(/\s+/).select{ |w| w.length == 5 }.map(&:downcase).uniq.sort
ALL_POSSIBLE_GUESSES = (File.read(POSSIBLE_GUESSES_LESS_SOLUTIONS).split(/\s+/).select{ |w| w.length == 5 }.map(&:downcase) + ALL_POSSIBLE_SOLUTIONS).uniq.sort

puts "Possible solution words read: #{ALL_POSSIBLE_SOLUTIONS.count}"
puts "Possible guess words read (plus solutions): #{ALL_POSSIBLE_GUESSES.count}"

class Guess
  attr_accessor :word

  def initialize(word:)
    self.word = word
  end

  def all_possible_responses
    responses = []
    Response::Slots::All.each do |slot_0|
      Response::Slots::All.each do |slot_1|
        Response::Slots::All.each do |slot_2|
          Response::Slots::All.each do |slot_3|
            Response::Slots::All.each do |slot_4|
              responses << Response.new(guess: self, slots: [slot_0, slot_1, slot_2, slot_3, slot_4])
            end
          end
        end
      end
    end

    responses
  end

  def average_set_size(possible_solutions:)
    responses_to_solutions = possible_solutions.reduce({}) do |hsh, word|
      response = Response.from_guess_and_solution(guess: self, solution: word)
      hsh[response] ||= []
      hsh[response] << word
      hsh
    end

    raise 'unexpected state' if possible_solutions.size != responses_to_solutions.values.map(&:size).sum

    return responses_to_solutions.values.map{|a| a.size * a.size}.sum / possible_solutions.size.to_f
  end

  def word_position_value(possible_solutions:)
    self.word.split('').map.with_index{ |c,i| possible_solutions.select{ |w| w[i] == c }.count }.sum
  end

  def to_s
    self.word
  end
end

class Response
  attr_accessor :guess, :slots

  module Slots
    NotPresent = 'not_present'
    PresentElsewhere = 'present_elsewhere'
    Correct = 'correct'
    All = Slots.constants(false).map { |c| Slots.const_get c }
  end

  def self.from_input(input:)
    characters = []
    slots = []
    input.split('').each_with_index do |c, i|
      next if c == '*'
      next if c == '!'

      characters << c
      if input[i+1] == '*'
        slots << Slots::PresentElsewhere
      elsif input[i+1] == '!'
        slots << Slots::Correct
      else
        slots << Slots::NotPresent
      end
    end

    return Response.new(guess: Guess.new(word: characters.join), slots: slots)
  end

  def initialize(guess:, slots:)
    self.guess = guess
    self.slots = slots
  end

  def allows?(word:)
    slots.each_with_index do |slot, index|
      if slot == Slots::NotPresent
        if word.include?(self.guess.word[index])
          if !self.to_s.include?("#{self.guess.word[index]}!") && !self.to_s.include?("#{self.guess.word[index]}*")
            return false
          end
        end
      elsif slot == Slots::PresentElsewhere
        return false if !word.include?(self.guess.word[index]) || word[index] == self.guess.word[index]
      else
        return false if word[index] != self.guess.word[index]
      end
    end

    return true
  end

  def allowed_set_size(possible_solutions:)
    possible_solutions.reduce(0) do |size, word|
      size += 1 if self.allows?(word: word)
      size
    end
  end

  def to_s
    self.guess.word.split('').zip(self.slots_as_input).join
  end

  def slots_as_input
    slots.map do |slot|
      if slot == Slots::NotPresent
        ''
      elsif slot == Slots::PresentElsewhere
        '*'
      else
        '!'
      end
    end
  end

  def self.from_guess_and_solution(guess:, solution:)
    slots = guess.word.split('').map.with_index do |char, index|
      if char == solution[index]
        Slots::Correct
      elsif solution.include?(char) && (index == 0 || !guess.word[0..(index - 1)].include?(char))
        Slots::PresentElsewhere
      else
        Slots::NotPresent
      end
    end

    return Response.new(guess: guess, slots: slots)
  end

  def ==(other)
    return self.to_s == other.to_s
  end

  def eql?(other)
    return self == other
  end

  def hash
    self.to_s.hash
  end
end

@possible_solution_words = ALL_POSSIBLE_SOLUTIONS.dup

ARGV.map(&:downcase).map(&:strip).each do |response|
  puts "Processing response: #{response}"
  response = Response.from_input(input: response)

  @possible_solution_words = @possible_solution_words.select do |word|
    response.allows?(word: word)
  end

  puts "New solution words count: #{@possible_solution_words.count}"

  if @possible_solution_words.count <= 0
    puts "No possible solution words left, double check: #{response}"
    exit
  end
end

if @possible_solution_words.size == 1
  puts "Guess: #{@possible_solution_words.first}"
  exit
elsif @possible_solution_words.size <= 10
  puts "Possible remaining solutions: #{@possible_solution_words.join(', ')}"
end

CORE_COUNT = 8
guesses_by_thread_index = {}

ALL_POSSIBLE_GUESSES.each_with_index do |guess_word, index|
  guesses_by_thread_index[index % (CORE_COUNT)] ||= []
  guesses_by_thread_index[index % (CORE_COUNT)] << guess_word
end

guesses_to_average_size = {}

threads = guesses_by_thread_index.keys.map do |thread_index|
  Thread.new do
    guesses_by_thread_index[thread_index].each do |guess|
      guesses_to_average_size[guess] = Guess.new(word: guess).average_set_size(possible_solutions: @possible_solution_words)
      print '.'
    end
  end
end

threads.each(&:join)

puts ''

my_best_guesses = nil
my_best_guesses_size = @possible_solution_words.size + 1

ALL_POSSIBLE_GUESSES.each do |guess_word|
  size = guesses_to_average_size[guess_word]

  if size <= my_best_guesses_size
    my_best_guesses = [] if size < my_best_guesses_size

    my_best_guesses_size = size

    my_best_guesses << guess_word

    # puts "#{'%.2f' % my_best_guesses_size}: #{my_best_guesses.join(', ')}"
  end
end
puts "Best guess possible remaining solutions size: #{my_best_guesses_size}"

my_best_guesses = my_best_guesses.map do |word|
  Guess.new(word: word)
end.sort_by do |guess|
  [
    @possible_solution_words.include?(guess.word) ? 0 : 1,
    -guess.word_position_value(possible_solutions: @possible_solution_words),
    guess.word,
  ]
end

puts "My Best guess: #{my_best_guesses.first}"
