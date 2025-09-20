module Discovery
  module Services
    class ContentFilter
      def self.filter_by_criteria(programs, criteria)
        filtered_programs = programs
        
        if criteria[:language].present?
          filtered_programs = filtered_programs.where(language: criteria[:language])
        end
        
        if criteria[:kind].present?
          filtered_programs = filtered_programs.where(kind: criteria[:kind])
        end
        
        if criteria[:category].present?
          filtered_programs = filtered_programs.where(category: criteria[:category])
        end
        
        if criteria[:min_duration].present?
          filtered_programs = filtered_programs.where('duration_seconds >= ?', criteria[:min_duration])
        end
        
        if criteria[:max_duration].present?
          filtered_programs = filtered_programs.where('duration_seconds <= ?', criteria[:max_duration])
        end
        
        if criteria[:published_after].present?
          filtered_programs = filtered_programs.where('published_at >= ?', criteria[:published_after])
        end
        
        if criteria[:published_before].present?
          filtered_programs = filtered_programs.where('published_at <= ?', criteria[:published_before])
        end
        
        if criteria[:tags].present?
          tags = Array(criteria[:tags])
          filtered_programs = filtered_programs.where('tags && ARRAY[?]', tags)
        end
        
        filtered_programs
      end
      
      def self.available_filters
        {
          languages: Program.distinct.pluck(:language).compact.sort,
          kinds: Program.kinds.keys,
          categories: Program.distinct.pluck(:category).compact.sort,
          tags: Program.distinct.pluck(:tags).flatten.uniq.compact.sort
        }
      end
      
      def self.popular_categories(limit: 10)
        Program.published
               .group(:category)
               .where.not(category: nil)
               .order('COUNT(*) DESC')
               .limit(limit)
               .count
      end
    end
  end
end