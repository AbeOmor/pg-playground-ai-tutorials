-- Description: This script creates the tables and loads the data into the tables.
-- It creates a table to store the twitter-posts data and loads the data from the twitter-posts.csv file into the table.

DROP TABLE IF EXISTS walmart_products;
DROP TABLE IF EXISTS temp_walmart_products;

-- ...existing code...
CREATE TABLE temp_walmart_products (
    timestamp TIMESTAMPTZ,
    url TEXT,
    final_price NUMERIC(14,4),
    sku TEXT,
    currency TEXT,
    gtin TEXT,
    specifications JSONB,
    image_urls JSONB,
    top_reviews JSONB,
    rating_stars JSONB,
    related_pages JSONB,
    available_for_delivery BOOLEAN,
    available_for_pickup BOOLEAN,
    brand TEXT,
    breadcrumbs JSONB,
    category_ids TEXT,
    review_count INT,
    description TEXT,
    product_id TEXT,
    product_name TEXT,
    review_tags JSONB,
    category_url TEXT,
    category_name TEXT,
    category_path TEXT,
    root_category_url TEXT,
    root_category_name TEXT,
    upc TEXT,
    tags JSONB,
    main_image TEXT,
    rating REAL,
    unit_price TEXT,
    unit TEXT,
    aisle TEXT,
    free_returns TEXT,
    sizes JSONB,
    colors JSONB,
    seller TEXT,
    other_attributes JSONB,
    customer_reviews JSONB,
    ingredients TEXT,
    initial_price NUMERIC(14,2),
    discount TEXT,
    ingredients_full TEXT,
    categories JSONB
);

\COPY temp_walmart_products FROM 'walmart-products.csv' WITH (
  FORMAT csv,
  HEADER true,
  QUOTE '"',
  NULL '',
  FORCE_NULL (initial_price, final_price, review_count, rating)
);

CREATE TABLE walmart_products(
    product_id TEXT,
    product_name TEXT,  
    description TEXT,  
    final_price NUMERIC(14,4),
    url TEXT
);

-- Insert data into the twitter table
INSERT INTO walmart_products
SELECT
    product_id,
    product_name,  
    description,  
    final_price,
    url
FROM temp_walmart_products;


--- Show how to embed content for each article 
-- Setup OpenAI
SELECT azure_ai.set_setting('azure_openai.endpoint', 'https://orcaspmopenai.openai.azure.com/');
SELECT azure_ai.set_setting('azure_openai.subscription_key', '');


-- Add embeddings to the table 
ALTER TABLE walmart_products ADD COLUMN description_vector vector(1536);
UPDATE walmart_products
SET description_vector = azure_openai.create_embeddings('text-embedding-3-small', product_name || LEFT(description, 8000), max_attempts => 5, retry_delay_ms => 500)::vector
WHERE description_vector IS NULL;

--- Find similar articles 
WITH query_embedding AS (
  SELECT azure_openai.create_embeddings(
    'text-embedding-3-small',
    --(SELECT description FROM twitter_posts WHERE id = 1754919448543101419)
    'Mattress'
  )::vector AS embedded_query
),
embedding AS (
  SELECT 
    product_id,
    product_name,
    final_price,
    url,
    description,
    description_vector,
    RANK() OVER (
      ORDER BY description_vector <=> (SELECT embedded_query FROM query_embedding)
    ) AS vector_rank
  FROM walmart_products
)
SELECT product_id, product_name, final_price, description, url
FROM embedding
ORDER BY vector_rank
LIMIT 10;


---------------

