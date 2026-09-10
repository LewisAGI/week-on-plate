-- Creator vs buyer. Existing rows default to buyer; seed then promotes the demo creator.
ALTER TABLE users ADD COLUMN role TEXT NOT NULL DEFAULT 'buyer';

UPDATE users SET role = 'creator' WHERE id = 'usr_demo_creator' OR email = 'creator@weekonplate.demo';
UPDATE users SET role = 'buyer' WHERE id = 'usr_demo_buyer' OR email = 'buyer@weekonplate.demo';
