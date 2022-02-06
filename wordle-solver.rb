if ARGV.length == 0
  puts "Usage: ruby wordle-solver.rb 'ra*ise!'"
  puts '* means present somewhere, ! means present in position'
  puts 'Guess: raise'
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

  def largest_allowed_set_size(possible_solutions:, stop_after:)
    self.all_possible_responses.reduce(0) do |size, response|
      size = [response.allowed_set_size(possible_solutions: possible_solutions, stop_after: stop_after), size].max
      break size if size > stop_after
      size
    end
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

  def allowed_set_size(possible_solutions:, stop_after:)
    possible_solutions.reduce(0) do |size, word|
      size += 1 if self.allows?(word: word)
      break size if size > stop_after
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

best_guesses = nil
best_guesses_size = @possible_solution_words.size + 1

ALL_POSSIBLE_GUESSES.each do |guess_word|
  size = Guess.new(word: guess_word).largest_allowed_set_size(possible_solutions: @possible_solution_words, stop_after: best_guesses_size)

  if size <= best_guesses_size
    best_guesses = [] if size < best_guesses_size

    best_guesses_size = size

    best_guesses << guess_word

    if size > 10
      puts ''
      puts "#{best_guesses_size}: #{best_guesses.join(', ')}"
    end
  end

  print '.'
end
puts ''
puts "Best guess possible remaining solutions size: #{best_guesses_size}"

best_guesses = best_guesses.map do |word|
  Guess.new(word: word)
end.sort_by do |guess|
  [-guess.word_position_value(possible_solutions: @possible_solution_words), guess.word]
end

puts "Best guess using letter positions: #{best_guesses.first}"
