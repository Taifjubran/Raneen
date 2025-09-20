# Pagy initializer
require 'pagy/extras/overflow'

# Handle overflow by showing last page
Pagy::DEFAULT[:overflow] = :last_page

# Default items per page
Pagy::DEFAULT[:items] = 20

# Maximum items per page
Pagy::DEFAULT[:max_items] = 100