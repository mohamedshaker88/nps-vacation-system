-- Migration: Add exchange off days fields to requests table
-- Run this script in your Supabase SQL Editor to add support for exchange requests

-- Add exchange fields to requests table
ALTER TABLE requests 
ADD COLUMN IF NOT EXISTS exchange_from_date DATE,
ADD COLUMN IF NOT EXISTS exchange_to_date DATE,
ADD COLUMN IF NOT EXISTS exchange_reason TEXT;

-- Add comments for documentation
COMMENT ON COLUMN requests.exchange_from_date IS 'Original off day date for exchange requests';
COMMENT ON COLUMN requests.exchange_to_date IS 'New off day date for exchange requests';
COMMENT ON COLUMN requests.exchange_reason IS 'Reason for exchanging off days';

-- Create index for better query performance on exchange requests
CREATE INDEX IF NOT EXISTS idx_requests_exchange_dates ON requests(exchange_from_date, exchange_to_date) WHERE exchange_from_date IS NOT NULL;

-- Verify the changes
SELECT 
  id, 
  employee_name,
  type,
  start_date,
  end_date,
  exchange_from_date,
  exchange_to_date,
  exchange_reason
FROM requests 
WHERE type = 'Exchange Off Days'
ORDER BY created_at DESC 
LIMIT 5; 