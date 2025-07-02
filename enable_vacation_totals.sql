-- Enable individual employee vacation entitlements
-- This allows each employee to have custom vacation allowances different from policy

-- Add the new columns to the employees table
ALTER TABLE employees 
ADD COLUMN IF NOT EXISTS annual_leave_total INTEGER DEFAULT 15,
ADD COLUMN IF NOT EXISTS sick_leave_total INTEGER DEFAULT 10;

-- Update existing employees to have proper default totals
UPDATE employees 
SET 
  annual_leave_total = COALESCE(annual_leave_total, 15),
  sick_leave_total = COALESCE(sick_leave_total, 10)
WHERE annual_leave_total IS NULL OR sick_leave_total IS NULL;

-- Ensure remaining balances don't exceed totals
UPDATE employees 
SET 
  annual_leave_remaining = LEAST(annual_leave_remaining, annual_leave_total),
  sick_leave_remaining = LEAST(sick_leave_remaining, sick_leave_total)
WHERE 
  annual_leave_remaining > annual_leave_total 
  OR sick_leave_remaining > sick_leave_total;

-- Add comments for documentation
COMMENT ON COLUMN employees.annual_leave_total IS 'Individual employee annual leave entitlement (can differ from policy)';
COMMENT ON COLUMN employees.sick_leave_total IS 'Individual employee sick leave entitlement (can differ from policy)';

-- Verify the changes
SELECT 
  id, 
  name, 
  email,
  annual_leave_remaining,
  annual_leave_total,
  sick_leave_remaining,
  sick_leave_total
FROM employees 
ORDER BY created_at DESC 
LIMIT 5; 