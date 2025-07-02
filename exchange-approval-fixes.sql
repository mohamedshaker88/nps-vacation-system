-- Exchange Approval System and Fixes
-- Run this script in your Supabase SQL Editor

-- Add exchange approval fields to requests table
ALTER TABLE requests 
ADD COLUMN IF NOT EXISTS exchange_partner_id BIGINT REFERENCES employees(id),
ADD COLUMN IF NOT EXISTS exchange_partner_approved BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS exchange_partner_approved_at TIMESTAMP WITH TIME ZONE,
ADD COLUMN IF NOT EXISTS exchange_partner_notes TEXT;

-- Add index for better performance
CREATE INDEX IF NOT EXISTS idx_requests_exchange_partner ON requests(exchange_partner_id);

-- Function to get exchange requests that need partner approval
CREATE OR REPLACE FUNCTION get_pending_exchange_approvals(p_employee_id BIGINT)
RETURNS TABLE(
  request_id BIGINT,
  requester_name VARCHAR(255),
  requester_email VARCHAR(255),
  exchange_from_date DATE,
  exchange_to_date DATE,
  exchange_reason TEXT,
  request_created_at TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    r.id,
    e.name,
    e.email,
    r.exchange_from_date,
    r.exchange_to_date,
    r.exchange_reason,
    r.created_at
  FROM requests r
  JOIN employees e ON r.employee_id = e.id
  WHERE r.type = 'Exchange Off Days'
    AND r.exchange_partner_id = p_employee_id
    AND r.exchange_partner_approved = FALSE
    AND r.status = 'Pending'
  ORDER BY r.created_at DESC;
END;
$$ LANGUAGE plpgsql;

-- Function to approve/reject exchange request
CREATE OR REPLACE FUNCTION approve_exchange_request(
  p_request_id BIGINT,
  p_employee_id BIGINT,
  p_approved BOOLEAN,
  p_notes TEXT DEFAULT NULL
) RETURNS BOOLEAN AS $$
BEGIN
  -- Check if the employee is the exchange partner for this request
  IF NOT EXISTS (
    SELECT 1 FROM requests 
    WHERE id = p_request_id 
    AND exchange_partner_id = p_employee_id
    AND exchange_partner_approved = FALSE
  ) THEN
    RETURN FALSE;
  END IF;
  
  -- Update the exchange approval
  UPDATE requests 
  SET 
    exchange_partner_approved = p_approved,
    exchange_partner_approved_at = NOW(),
    exchange_partner_notes = p_notes
  WHERE id = p_request_id;
  
  -- If approved, also update the main request status to 'Partner Approved'
  -- If rejected, update to 'Rejected'
  IF p_approved THEN
    UPDATE requests 
    SET status = 'Partner Approved'
    WHERE id = p_request_id;
  ELSE
    UPDATE requests 
    SET status = 'Rejected'
    WHERE id = p_request_id;
  END IF;
  
  RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- Enhanced function to get available coverage (fix for exchange requests)
CREATE OR REPLACE FUNCTION get_available_coverage_for_exchange(
  p_date DATE,
  p_exclude_employee_id BIGINT DEFAULT NULL
) RETURNS TABLE(
  employee_id BIGINT,
  employee_name VARCHAR(255),
  employee_email VARCHAR(255),
  day_status VARCHAR(20)
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    e.id,
    e.name,
    e.email,
    get_employee_day_status(e.id, p_date) as day_status
  FROM employees e
  WHERE get_employee_day_status(e.id, p_date) = 'off'
    AND (p_exclude_employee_id IS NULL OR e.id != p_exclude_employee_id)
  ORDER BY e.name;
END;
$$ LANGUAGE plpgsql;

-- Function to validate exchange request
CREATE OR REPLACE FUNCTION validate_exchange_request(
  p_employee_id BIGINT,
  p_exchange_from_date DATE,
  p_exchange_to_date DATE,
  p_exchange_partner_id BIGINT
) RETURNS TABLE(
  is_valid BOOLEAN,
  error_message TEXT
) AS $$
DECLARE
  requester_status VARCHAR(20);
  partner_status VARCHAR(20);
BEGIN
  -- Check if requester has an off day on the from date
  requester_status := get_employee_day_status(p_employee_id, p_exchange_from_date);
  IF requester_status != 'off' THEN
    RETURN QUERY SELECT FALSE, 'You do not have an off day on the date you want to exchange from';
    RETURN;
  END IF;
  
  -- Check if partner has an off day on the to date
  partner_status := get_employee_day_status(p_exchange_partner_id, p_exchange_to_date);
  IF partner_status != 'off' THEN
    RETURN QUERY SELECT FALSE, 'The exchange partner does not have an off day on the requested date';
    RETURN;
  END IF;
  
  -- Check if dates are different
  IF p_exchange_from_date = p_exchange_to_date THEN
    RETURN QUERY SELECT FALSE, 'Exchange dates must be different';
    RETURN;
  END IF;
  
  -- Check if dates are in the future
  IF p_exchange_from_date <= CURRENT_DATE OR p_exchange_to_date <= CURRENT_DATE THEN
    RETURN QUERY SELECT FALSE, 'Exchange dates must be in the future';
    RETURN;
  END IF;
  
  -- All validations passed
  RETURN QUERY SELECT TRUE, 'Exchange request is valid';
END;
$$ LANGUAGE plpgsql;

-- Update the existing get_available_coverage function to use the new one
CREATE OR REPLACE FUNCTION get_available_coverage(p_date DATE)
RETURNS TABLE(
  employee_id BIGINT,
  employee_name VARCHAR(255),
  employee_email VARCHAR(255),
  day_status VARCHAR(20)
) AS $$
BEGIN
  RETURN QUERY
  SELECT * FROM get_available_coverage_for_exchange(p_date);
END;
$$ LANGUAGE plpgsql;

-- Add comments for documentation
COMMENT ON FUNCTION get_pending_exchange_approvals IS 'Gets exchange requests that need approval from a specific employee';
COMMENT ON FUNCTION approve_exchange_request IS 'Approves or rejects an exchange request by the exchange partner';
COMMENT ON FUNCTION get_available_coverage_for_exchange IS 'Gets available coverage for exchange requests with optional employee exclusion';
COMMENT ON FUNCTION validate_exchange_request IS 'Validates an exchange request before submission';

-- Create RLS policies for exchange partner access
CREATE POLICY "Employees can view exchange requests they are partners for" ON requests
  FOR SELECT USING (
    exchange_partner_id IN (
      SELECT id FROM employees WHERE email = current_user
    )
  );

CREATE POLICY "Employees can update exchange requests they are partners for" ON requests
  FOR UPDATE USING (
    exchange_partner_id IN (
      SELECT id FROM employees WHERE email = current_user
    )
  );

-- Insert sample data for testing (optional)
-- This will create some test exchange requests if needed
-- Uncomment the lines below if you want to test with sample data

/*
INSERT INTO requests (
  employee_id, type, start_date, end_date, reason, 
  exchange_from_date, exchange_to_date, exchange_reason,
  exchange_partner_id, status, created_at
) 
SELECT 
  e1.id, 'Exchange Off Days', '2024-01-15', '2024-01-15', 'Exchange request',
  '2024-01-15', '2024-01-22', 'Need to swap off days',
  e2.id, 'Pending', NOW()
FROM employees e1, employees e2 
WHERE e1.id != e2.id 
LIMIT 1;
*/ 