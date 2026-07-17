CREATE TABLE IF NOT EXISTS products (
    id SERIAL PRIMARY KEY,
    name VARCHAR(120) NOT NULL,
    price NUMERIC(10, 2) NOT NULL,
    stock INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMP DEFAULT NOW()
);

INSERT INTO products (name, price, stock) VALUES
    ('Wireless Mouse', 19.99, 150),
    ('Mechanical Keyboard', 79.99, 80),
    ('27" Monitor', 229.00, 40),
    ('USB-C Hub', 34.50, 200),
    ('Noise Cancelling Headphones', 149.00, 60)
ON CONFLICT DO NOTHING;
