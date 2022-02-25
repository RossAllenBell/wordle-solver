puts 'THIS IS A NON-OPTIMAL SOLUTION'

ALL_SYSTEM_WORDS = '/usr/share/dict/words'
POSSIBLE_SOLUTIONS = './possible-solutions.txt'
POSSIBLE_GUESSES_LESS_SOLUTIONS = './possible-guesses-less-solutions.txt'

ALL_POSSIBLE_SOLUTIONS = File.read(POSSIBLE_SOLUTIONS).split(/\s+/).select{ |w| w.length == 5 }.map(&:downcase).uniq
ALL_POSSIBLE_GUESSES = (File.read(POSSIBLE_GUESSES_LESS_SOLUTIONS).split(/\s+/).select{ |w| w.length == 5 }.map(&:downcase) + ALL_POSSIBLE_SOLUTIONS).uniq

puts "Possible solution words read: #{ALL_POSSIBLE_SOLUTIONS.count}"
puts "Possible guess words read (plus solutions): #{ALL_POSSIBLE_GUESSES.count}"

def word_letter_value(word)
  word.split('').uniq.map{ |c| letter_counts[c] || 0 }.sum
end

def word_position_value(word)
  word.split('').map.with_index{ |c,i| @possible_solution_words.select{ |w| w[i] == c }.count }.sum
end

def letter_counts
  @_letter_counts ||= begin
    counts = {}
    @possible_solution_words.each{ |w| w.split('').each{ |c| counts[c] ||= 1; counts[c] += 1 } }
    counts
  end
end

@possible_solution_words = ALL_POSSIBLE_SOLUTIONS.dup

ARGV.map(&:downcase).map(&:strip).each do |clue|
  puts "Processing clue: #{clue}"
  letter_position = 0
  clue.split('').map.with_index.each do |c, i|
    next if c == '*'
    next if c == '!'

    if clue[i+1] == '*'
      @possible_solution_words = @possible_solution_words.select{ |w| w.include?(c) }
      @possible_solution_words = @possible_solution_words.reject{ |w| w[letter_position] == c }
    elsif clue[i+1] == '!'
      @possible_solution_words = @possible_solution_words.select{ |w| w[letter_position] == c }
    else
      @possible_solution_words = @possible_solution_words.reject{ |w| w.include?(c) }
    end

    letter_position += 1
  end
  puts "New solution words count: #{@possible_solution_words.count}"

  if @possible_solution_words.count <= 0
    puts "No possible solution words left, double check: #{clue}"
    exit
  end
end

word_values = {}

ALL_POSSIBLE_GUESSES.each do |word|
  word_values[word] = word_letter_value(word)
end

probably_not_the_best_guesses_score = word_values.values.max
probably_not_the_best_guesses = word_values.to_a.select{ |w,s| s == probably_not_the_best_guesses_score }.map(&:first).sort
puts "Best guesses by letter values: #{probably_not_the_best_guesses.join(', ')}"

probably_not_the_best_guesses_by_position = {}
# probably_not_the_best_guesses.each do |word|
['aesir', 'arise', 'raise', 'reais', 'serai'].each do |word|
  probably_not_the_best_guesses_by_position[word] = word_position_value(word)
end
probably_not_the_best_guesses_by_position_score = probably_not_the_best_guesses_by_position.values.max
probably_not_the_best_guesses_by_position = probably_not_the_best_guesses_by_position.to_a.select{ |w,s| s == probably_not_the_best_guesses_by_position_score }.map(&:first).sort

puts "(Probably not the) best guesses by letter positions: #{probably_not_the_best_guesses_by_position.join(', ')}"

if ARGV.length == 0
  puts 'Provide clue input like: ro*ate! (* means present somewhere, ! means present in position)'
end
