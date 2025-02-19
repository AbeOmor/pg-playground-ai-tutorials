-- Description: This script creates the tables and loads the data into the tables.
-- It creates a table to store the twitter-posts data and loads the data from the twitter-posts.csv file into the table.

DROP TABLE IF EXISTS twitter_posts;
DROP TABLE IF EXISTS temp_twitter_posts;

--- Prepare data in advance (‘articles’ table with ‘articleID’ and ‘content’ columns) 

CREATE TABLE temp_twitter_posts(
    id BIGINT,
    user_posted TEXT,
    name TEXT,
    description TEXT,
    date_posted TIMESTAMPTZ,
    photos TEXT,
    videos TEXT,
    url TEXT,
    quoted_post JSONB,
    tagged_users JSONB,
    replies INT,
    reposts INT,
    likes INT,
    views INT,
    external_url TEXT,
    hashtags TEXT,
    followers INT,
    biography TEXT,
    posts_count INT,
    profile_image_link TEXT,
    following INT,
    is_verified BOOLEAN,
    quotes INT,
    bookmarks INT,
    parent_post_details JSONB
);

\COPY temp_twitter_posts
FROM 'twitter-posts.csv' -- https://raw.githubusercontent.com/luminati-io/Free-datasets/refs/heads/main/twitter-posts.csv
WITH (
  FORMAT csv,
  HEADER true,
  NULL '',
  FORCE_NULL (replies, reposts, likes, views, quotes, bookmarks)
);

CREATE TABLE twitter_posts(
    id BIGINT,
    user_posted TEXT,
    name TEXT,
    description TEXT,
    url TEXT
);

-- Insert data into the twitter table
INSERT INTO twitter_posts
SELECT
    id BIGINT,
    user_posted TEXT,
    name TEXT,
    description TEXT,
    url TEXT
FROM temp_twitter_posts;


--- Show how to embed content for each article 
-- Setup OpenAI
SELECT azure_ai.set_setting('azure_openai.endpoint', 'https://orcaspmopenai.openai.azure.com/');
SELECT azure_ai.set_setting('azure_openai.subscription_key', '');

-- ALTER TABLE twitter_posts DROP COLUMN description_vector 
-- Add embeddings to the table 
ALTER TABLE twitter_posts ADD COLUMN description_vector vector(1536);
UPDATE twitter_posts
SET description_vector = azure_openai.create_embeddings('text-embedding-3-small',  LEFT(description, 8000), max_attempts => 5, retry_delay_ms => 500)::vector
WHERE description_vector IS NULL;

--- Find similar articles 
WITH query_embedding AS (
  SELECT azure_openai.create_embeddings(
    'text-embedding-3-small',
    --(SELECT description FROM twitter_posts WHERE id = 1754919448543101419)
    'Microsoft Postgres is Awesome'
  )::vector AS embedded_query
),
embedding AS (
  SELECT 
    id,
    name,
    user_posted,
    url,
    description,
    description_vector,
    RANK() OVER (
      ORDER BY description_vector <=> (SELECT embedded_query FROM query_embedding)
    ) AS vector_rank
  FROM twitter_posts
)
SELECT id, name, user_posted, description, url
FROM embedding
ORDER BY vector_rank
LIMIT 10;


---------------

