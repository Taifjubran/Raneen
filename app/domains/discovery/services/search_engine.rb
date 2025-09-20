module Discovery
  module Services
    class SearchEngine
      def self.search(query:, filters: {}, page: 1, per_page: 20)
        validate_search_params!(query, filters, page, per_page)
        
        programs = Program.published
        programs = apply_text_search(programs, query) if query.present?
        programs = apply_filters(programs, filters) if filters.any?
        
        total_count = programs.count
        programs = programs.page(page).per(per_page)
        
        {
          programs: programs,
          total_count: total_count,
          page: page,
          per_page: per_page,
          total_pages: (total_count / per_page.to_f).ceil
        }
      end
      
      def self.featured_programs(limit: 10)
        Program.published
               .where('view_count > ?', 100)
               .order(view_count: :desc, published_at: :desc)
               .limit(limit)
      end
      
      def self.recent_programs(limit: 10)
        Program.published
               .order(published_at: :desc)
               .limit(limit)
      end
      
      private
      
      def self.validate_search_params!(query, filters, page, per_page)
        raise Discovery::ValidationError, "Page must be positive" if page < 1
        raise Discovery::ValidationError, "Per page must be between 1 and 100" unless (1..100).include?(per_page)
        raise Discovery::ValidationError, "Query too long" if query && query.length > 500
      end
      
      def self.apply_text_search(programs, query)
        programs.where(
          "title ILIKE ? OR description ILIKE ? OR category ILIKE ? OR array_to_string(tags, ' ') ILIKE ?",
          "%#{query}%", "%#{query}%", "%#{query}%", "%#{query}%"
        ).order(:title)
      end
      
      def self.apply_filters(programs, filters)
        programs = programs.where(kind: filters[:kind]) if filters[:kind].present?
        programs = programs.where(language: filters[:language]) if filters[:language].present?
        programs = programs.where(category: filters[:category]) if filters[:category].present?
        programs
      end
    end
  end
end