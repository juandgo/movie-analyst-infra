-- Schema reconstructed from schema.png, with the column name taken from the code:
-- seeds.js and /movies use movies.release_year (the PNG shows "release").
CREATE TABLE IF NOT EXISTS publications (
  name   VARCHAR(250) NOT NULL,
  avatar VARCHAR(250),
  PRIMARY KEY (name)
);

CREATE TABLE IF NOT EXISTS reviewers (
  name        VARCHAR(255) NOT NULL,
  publication VARCHAR(250),
  avatar      VARCHAR(250),
  PRIMARY KEY (name),
  FOREIGN KEY (publication) REFERENCES publications (name)
);

CREATE TABLE IF NOT EXISTS movies (
  title        VARCHAR(250) NOT NULL,
  release_year VARCHAR(250),
  score        INT,
  reviewer     VARCHAR(250),
  publication  VARCHAR(250),
  PRIMARY KEY (title),
  FOREIGN KEY (reviewer) REFERENCES reviewers (name)
);
