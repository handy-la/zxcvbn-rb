# frozen_string_literal: true

require 'i18n'

module Zxcvbn
  module Feedback
    DEFAULT_FEEDBACK = {
      "warning" => "",
      "suggestions" => [:few_words, :avoid_common_phrases, :no_need_symbols]
    }.freeze

    def self.get_feedback(score, sequence)
      if sequence.empty?
        # starting feedback
        return DEFAULT_FEEDBACK
      end

      # no feedback if score is good or great.
      if score > 2
        return {
          "warning" => "",
          "suggestions" => []
        }
      end

      longest_match = sequence.max_by { |match| match["token"].length }
      feedback = get_match_feedback(longest_match, sequence.size == 1)
      extra_feedback = :add_another_word
      if feedback
        feedback["suggestions"].unshift(extra_feedback)
        feedback["warning"] = "" if feedback["warning"].nil?
      else
        feedback = {
          "warning" => "",
          "suggestions" => [extra_feedback]
        }
      end
      feedback
    end

    def self.get_match_feedback(match, is_sole_match)
      case match["pattern"]
      when "dictionary"
        get_dictionary_match_feedback(match, is_sole_match)
      when "spatial"
        warning = if match["turns"] == 1
          :straight_rows_easy_guess
        else
          :short_keyboard_patterns_easy_guess
        end
        {
          "warning" => warning,
          "suggestions" => [:use_longer_keyboard_pattern]
        }
      when "repeat"
        warning = if match["base_token"].length == 1
          :repeats_easy_guess
        else
          :repeats_slightly_harder_guess
        end
        {
          "warning" => warning,
          "suggestions" => [:avoid_repeated_words]
        }
      when "sequence"
        {
          "warning" => :sequences_easy_guess,
          "suggestions" => [:avoid_sequences]
        }
      when "regex"
        if match["regex_name"] == "recent_year"
          {
            "warning" => :recent_years_easy_guess,
            "suggestions" => [:avoid_recent_years, :avoid_associated_years]
          }
        end
        # break
      when "date"
        {
          "warning" => :dates_easy_guess,
          "suggestions" => [:avoid_dates_associated_years]
        }
      end
    end

    def self.get_dictionary_match_feedback(match, is_sole_match)
      warning = if match["dictionary_name"] == "passwords"
        if is_sole_match && !match["l33t"] && !match["reversed"]
          if match["rank"] <= 10
            :top_10_common_password
          elsif match["rank"] <= 100
            :top_100_common_password
          else
            :very_common_password
          end
        elsif match["guesses_log10"] <= 4
          :similar_to_common_password
        end
      elsif match["dictionary_name"] == "english_wikipedia"
        :word_by_itself_easy_guess if is_sole_match
      elsif ["surnames", "male_names", "female_names"].include?(match["dictionary_name"])
        if is_sole_match
          :names_surnames_by_themselves_easy_guess
        else
          :common_names_surnames_easy_guess
        end
      else
        ""
      end
      suggestions = []
      word = match["token"]
      if word.match(Scoring::START_UPPER)
        suggestions << :capitalization_not_help_much
      elsif word.match(Scoring::ALL_UPPER) && word.downcase != word
        suggestions << :all_uppercase_almost_easy_guess
      end
      suggestions << :reversed_words_not_much_harder_guess if match["reversed"] && match["token"].length >= 4
      suggestions << :predictable_substitutions_not_help_much if match["l33t"]
      {
        "warning" => warning,
        "suggestions" => suggestions
      }
    end
  end
end
