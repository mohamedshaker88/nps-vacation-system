-- Add vacation total columns to employees table
-- This allows individual employees to have different total vacation allowances

ALTER TABLE employees 
ADD COLUMN IF NOT EXISTS annual_leave_total INTEGER DEFAULT 15,
ADD COLUMN IF NOT EXISTS sick_leave_total INTEGER DEFAULT 10;

-- Update existing employees to have default totals if they don't have them
UPDATE employees 
SET 
  annual_leave_total = COALESCE(annual_leave_total, 15),
  sick_leave_total = COALESCE(sick_leave_total, 10)
WHERE annual_leave_total IS NULL OR sick_leave_total IS NULL;

-- Add comments to document the new columns
COMMENT ON COLUMN employees.annual_leave_total IS 'Total annual leave allowance for this employee (can be different from policy default)';
COMMENT ON COLUMN employees.sick_leave_total IS 'Total sick leave allowance for this employee (can be different from policy default)'; 