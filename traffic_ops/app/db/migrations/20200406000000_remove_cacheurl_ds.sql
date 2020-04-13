
-- +goose Up
-- SQL in section 'Up' is executed when this migration is applied
ALTER TABLE deliveryservice DROP COLUMN cacheurl;


-- +goose Down
-- SQL section 'Down' is executed when this migration is rolled back
ALTER TABLE deliveryservice ADD COLUMN cacheurl text;

