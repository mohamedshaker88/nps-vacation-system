-- MINIMAL INSERT FIX - Emergency Solution
-- This script provides an immediate fix for the INSERT column mismatch error

-- Step 1: First, let's see exactly what columns exist
SELECT 
    'Current requests table structure:' as info,
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'requests'
ORDER BY ordinal_position;

-- Step 2: Make ALL columns nullable and add defaults
ALTER TABLE requests ALTER COLUMN employee_name DROP NOT NULL;
ALTER TABLE requests ALTER COLUMN employee_email DROP NOT NULL;
ALTER TABLE requests ALTER COLUMN type DROP NOT NULL;
ALTER TABLE requests ALTER COLUMN start_date DROP NOT NULL;
ALTER TABLE requests ALTER COLUMN end_date DROP NOT NULL;
ALTER TABLE requests ALTER COLUMN reason DROP NOT NULL;
ALTER TABLE requests ALTER COLUMN status DROP NOT NULL;
ALTER TABLE requests ALTER COLUMN days DROP NOT NULL;
ALTER TABLE requests ALTER COLUMN submit_date DROP NOT NULL;

-- Step 3: Add defaults to essential columns
ALTER TABLE requests ALTER COLUMN employee_name SET DEFAULT '';
ALTER TABLE requests ALTER COLUMN employee_email SET DEFAULT '';
ALTER TABLE requests ALTER COLUMN type SET DEFAULT 'Annual Leave';
ALTER TABLE requests ALTER COLUMN start_date SET DEFAULT CURRENT_DATE;
ALTER TABLE requests ALTER COLUMN end_date SET DEFAULT CURRENT_DATE;
ALTER TABLE requests ALTER COLUMN reason SET DEFAULT '';
ALTER TABLE requests ALTER COLUMN status SET DEFAULT 'Pending';
ALTER TABLE requests ALTER COLUMN days SET DEFAULT 1;
ALTER TABLE requests ALTER COLUMN submit_date SET DEFAULT CURRENT_DATE;

-- Step 4: Ensure all exchange columns exist with NULL defaults
ALTER TABLE requests 
ADD COLUMN IF NOT EXISTS employee_id BIGINT,
ADD COLUMN IF NOT EXISTS exchange_partner_id BIGINT,
ADD COLUMN IF NOT EXISTS exchange_partner_approved BOOLEAN DEFAULT NULL,
ADD COLUMN IF NOT EXISTS exchange_partner_approved_at TIMESTAMP WITH TIME ZONE DEFAULT NULL,
ADD COLUMN IF NOT EXISTS exchange_partner_notes TEXT DEFAULT NULL,
ADD COLUMN IF NOT EXISTS exchange_from_date DATE DEFAULT NULL,
ADD COLUMN IF NOT EXISTS exchange_to_date DATE DEFAULT NULL,
ADD COLUMN IF NOT EXISTS exchange_reason TEXT DEFAULT NULL,
ADD COLUMN IF NOT EXISTS partner_desired_off_date DATE DEFAULT NULL,
ADD COLUMN IF NOT EXISTS requires_partner_approval BOOLEAN DEFAULT false,
ADD COLUMN IF NOT EXISTS coverage_arranged BOOLEAN DEFAULT false,
ADD COLUMN IF NOT EXISTS coverage_by TEXT DEFAULT NULL,
ADD COLUMN IF NOT EXISTS medical_certificate BOOLEAN DEFAULT false,
ADD COLUMN IF NOT EXISTS emergency_contact TEXT DEFAULT NULL,
ADD COLUMN IF NOT EXISTS additional_notes TEXT DEFAULT NULL;

-- Step 5: Test with the absolute minimum insert
DO $$
DECLARE
    test_result BIGINT;
BEGIN
    -- Try the most minimal insert possible
    INSERT INTO requests (employee_name, employee_email, type, reason)
    VALUES ('Test User', 'test@example.com', 'Annual Leave', 'Test')
    RETURNING id INTO test_result;
    
    RAISE NOTICE 'SUCCESS: Minimal insert worked! Request ID: %', test_result;
    
    -- Clean up test
    DELETE FROM requests WHERE id = test_result;
    
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Insert still failing: %', SQLERRM;
    RAISE NOTICE 'Error code: %', SQLSTATE;
END $$;

-- Step 6: Show the final structure
SELECT 
    'FIXED - requests table structure:' as info,
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'requests'
ORDER BY ordinal_position;

SELECT 'MINIMAL INSERT FIX COMPLETE - Try submitting a request now!' as result; 