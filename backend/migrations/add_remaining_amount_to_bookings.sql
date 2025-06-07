-- Add remaining_amount column to bookings table
ALTER TABLE lesbaza.bookings 
ADD COLUMN remaining_amount DECIMAL(10, 2) GENERATED ALWAYS AS (total_cost - COALESCE(total_paid, 0)) STORED;
